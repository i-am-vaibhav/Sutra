import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_downloader.dart';
import 'package:sutra/runtime/provisioning/model_manager.dart';
import 'package:sutra/runtime/provisioning/model_queue.dart';

// ── Fake ModelDownloader ─────────────────────────────────────
// Simulates download behavior without network calls.
// Tracks all downloads to verify sequential execution.

class FakeModelDownloader extends ModelDownloader {
  int downloadCount = 0;
  final List<String> downloadOrder = [];
  final Duration downloadDuration;

  /// If non-null, the next download with this model ID will throw.
  String? failModelId;
  String? failReason;

  FakeModelDownloader({
    this.downloadDuration = const Duration(milliseconds: 50),
  });

  @override
  Future<void> download({
    required ModelDefinition model,
    required bool requireWifi,
    required void Function(DownloadEvent event) onEvent,
    required ModelDatabase database,
  }) async {
    downloadCount++;
    downloadOrder.add(model.id);

    // Simulate configured failure.
    if (failModelId == model.id) {
      throw Exception(failReason ?? 'Simulated download failure');
    }

    // Simulate progressive download.
    for (int i = 0; i <= 10; i++) {
      await Future.delayed(downloadDuration ~/ 10);
      onEvent(DownloadEvent(
        progress: i / 10,
        downloadedBytes: (i / 10 * 1000).toInt(),
      ));
    }

    // Update database to reflect downloaded state BEFORE marking completed,
    // so ModelManager._download()'s onEvent sees 'downloaded' when it calls
    // _syncStateFromDb() after receiving the completed event.
    final record = await database.get(model.id);
    if (record != null) {
      await database.upsert(record.copyWith(
        state: ModelState.downloaded,
        progress: 1.0,
        downloadedBytes: 1000,
      ));
    }

    // Mark as completed.
    onEvent(DownloadEvent(
      progress: 1.0,
      completed: true,
      downloadedBytes: 1000,
    ));
  }
}

// ── Helpers ──────────────────────────────────────────────────

ModelDefinition _makeModel(String id) => ModelDefinition(
      id: id,
      name: 'Model $id',
      size: ModelSize.tiny,
      contextLength: 2048,
      downloadUrl: 'https://example.com/$id.gguf',
      localPath: '$id.gguf',
      fileSizeBytes: 1000,
    );

Future<ModelDatabase> _openTestDb() async {
  return ModelDatabase.test(() => openDatabase(
        ':memory:',
        version: 1,
        onCreate: (database, version) async {
          await database.execute('''
            CREATE TABLE models (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              version TEXT NOT NULL DEFAULT '1.0.0',
              state TEXT NOT NULL DEFAULT 'not_downloaded',
              local_path TEXT NOT NULL,
              download_url TEXT NOT NULL,
              expected_checksum TEXT,
              file_size_bytes INTEGER,
              downloaded_bytes INTEGER DEFAULT 0,
              progress REAL DEFAULT 0.0,
              retry_attempts INTEGER DEFAULT 0,
              error_message TEXT,
              download_task_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      ));
}

/// Wait for the manager stream to emit a state where [predicate] returns true,
/// or timeout after [timeout].
Future<ModelManagerState> waitForState(
  ModelManager manager,
  bool Function(ModelManagerState) predicate, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  // Check current state first.
  if (predicate(manager.state)) return manager.state;

  final completer = Completer<ModelManagerState>();
  final sub = manager.stream.listen((state) {
    if (!completer.isCompleted && predicate(state)) {
      completer.complete(state);
    }
  });

  final result = await completer.future.timeout(timeout, onTimeout: () {
    throw TimeoutException(
      'Timed out waiting for state predicate. '
      'Current state: ${manager.state.modelStates}',
    );
  });
  await sub.cancel();
  return result;
}

// ── Tests ────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    // Mock SharedPreferences so ModelManager.isWifiOnly() works.
    SharedPreferences.setMockInitialValues({});

    // Mock path_provider channel so ModelPaths works in tests.
    final pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getApplicationDocumentsDirectory') {
        return Directory.systemTemp.path;
      }
      if (methodCall.method == 'getTemporaryDirectory') {
        return Directory.systemTemp.path;
      }
      return null;
    });

    // Mock sutra/device channel so DeviceDetector.getFreeDiskSpace works.
    final deviceChannel = MethodChannel('ai.sutra.app/device');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'getFreeDiskSpace') {
        return 10 * 1024 * 1024 * 1024; // 10 GB
      }
      if (methodCall.method == 'getDeviceProfile') {
        return {
          'ramMB': 8192,
          'cpuCores': 8,
          'hasGpu': true,
          'gpuName': 'test',
          'gpuFamily': 'mid',
          'platform': 'macos',
        };
      }
      return null;
    });
  });

  tearDownAll(() {
    final pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    final deviceChannel = MethodChannel('ai.sutra.app/device');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(deviceChannel, null);
  });

  group('Sequential Download Flow', () {
    late ModelDatabase db;
    late FakeModelDownloader downloader;
    late ModelManager manager;

    setUp(() async {
      db = await _openTestDb();
      downloader = FakeModelDownloader();
      manager = ModelManager(database: db, downloader: downloader);
    });

    tearDown(() async {
      manager.dispose();
      await db.close();
    });

    // ── Core bug fix verification ────────────────────────────

    test('downloadModel works for two models sequentially', () async {
      final model1 = _makeModel('m1');
      final model2 = _makeModel('m2');

      await manager.init([model1, model2]);

      // Download first model.
      await manager.downloadModel(model1);

      // Wait until m1 is downloaded.
      await waitForState(manager, (s) => s.installedIds.contains('m1'));
      expect(manager.state.installedIds, contains('m1'));
      expect(downloader.downloadCount, 1);

      // Download second model — this is the critical test.
      // Before the fix, this would hang because the global subscription
      // to FileDownloader().updates was exhausted after the first download.
      await manager.downloadModel(model2);

      // Wait until m2 is also downloaded.
      await waitForState(manager, (s) => s.installedIds.contains('m2'));
      expect(manager.state.installedIds, contains('m2'));
      expect(downloader.downloadCount, 2);
      // Both m1 and m2 should have been downloaded.
      expect(downloader.downloadOrder, containsAll(['m1', 'm2']));
    });

    test('three models download sequentially via provision', () async {
      final model1 = _makeModel('m1');
      final model2 = _makeModel('m2');
      final model3 = _makeModel('m3');

      await manager.init([model1, model2, model3]);

      // Provision all three (adds to queue and starts processing).
      await manager.provision([model1, model2, model3]);

      // Wait until all three are downloaded.
      await waitForState(manager, (s) => s.installedIds.length >= 3);

      expect(manager.state.installedIds, containsAll(['m1', 'm2', 'm3']));
      expect(downloader.downloadCount, 3);
      expect(downloader.downloadOrder, ['m1', 'm2', 'm3']);
    });

    // ── Queue processing ─────────────────────────────────────

    test('queue processes models one at a time', () async {
      final model1 = _makeModel('m1');
      final model2 = _makeModel('m2');

      await manager.init([model1, model2]);

      // Both downloadModel calls should not block each other.
      final f1 = manager.downloadModel(model1);
      final f2 = manager.downloadModel(model2);

      await Future.wait([f1, f2]);

      await waitForState(manager, (s) => s.installedIds.length >= 2);

      expect(manager.state.installedIds, containsAll(['m1', 'm2']));
      expect(downloader.downloadCount, 2);
    });

    test('failed download does not block subsequent downloads', () async {
      final model1 = _makeModel('m1');
      final model2 = _makeModel('m2');

      await manager.init([model1, model2]);

      // Make m1 fail.
      downloader.failModelId = 'm1';
      downloader.failReason = 'Network error';

      await manager.downloadModel(model1);

      // Wait for m1 to be marked as failed.
      await waitForState(manager, (s) => s.failedIds.contains('m1'));
      expect(manager.state.failedIds, contains('m1'));

      // Clear the failure.
      downloader.failModelId = null;

      // m2 should still download successfully.
      await manager.downloadModel(model2);

      await waitForState(manager, (s) => s.installedIds.contains('m2'));
      expect(manager.state.installedIds, contains('m2'));
      expect(downloader.downloadCount, 2);
    });

    test('retry after failure works for sequential downloads', () async {
      final model1 = _makeModel('m1');
      final model2 = _makeModel('m2');

      await manager.init([model1, model2]);

      // Provision both — m1 will fail.
      downloader.failModelId = 'm1';
      await manager.provision([model1, model2]);

      // Wait for m1 to fail and m2 to complete.
      await waitForState(manager, (s) =>
          s.failedIds.contains('m1') && s.installedIds.contains('m2'));

      expect(manager.state.failedIds, contains('m1'));
      expect(manager.state.installedIds, contains('m2'));

      // Fix the downloader and retry m1.
      downloader.failModelId = null;
      await manager.retryDownload('m1');

      await waitForState(manager, (s) => s.installedIds.contains('m1'));
      expect(manager.state.installedIds, containsAll(['m1', 'm2']));
    });

    // ── State transitions ────────────────────────────────────

    test('downloadModel transitions through downloading → downloaded',
        () async {
      final model = _makeModel('m1');
      await manager.init([model]);

      // Start download — downloadModel() returns after queueing, not after completion.
      await manager.downloadModel(model);

      // Wait for the download to actually complete.
      await waitForState(manager, (s) => s.installedIds.contains('m1'));

      // Final state should be downloaded.
      final record = await db.get('m1');
      expect(record!.state, ModelState.downloaded);
      expect(record.downloadedBytes, 1000);
      expect(record.progress, 1.0);
    });

    test('delete and re-download works sequentially', () async {
      final model1 = _makeModel('m1');
      final model2 = _makeModel('m2');

      await manager.init([model1, model2]);

      // Download both.
      await manager.downloadModel(model1);
      await waitForState(manager, (s) => s.installedIds.contains('m1'));

      await manager.downloadModel(model2);
      await waitForState(manager, (s) => s.installedIds.contains('m2'));

      // Delete m1.
      await manager.deleteModel('m1');
      await waitForState(manager, (s) => !s.installedIds.contains('m1'));

      // Re-download m1.
      await manager.redownloadModel('m1');
      await waitForState(manager, (s) => s.installedIds.contains('m1'));

      expect(manager.state.installedIds, containsAll(['m1', 'm2']));
    });

    // ── Queue internals ──────────────────────────────────────

    test('ModelQueue processes items in FIFO order', () {
      final q = ModelQueue();
      q.add('m1');
      q.add('m2');
      q.add('m3');

      expect(q.next, 'm1');
      q.remove('m1');
      expect(q.next, 'm2');
      q.remove('m2');
      expect(q.next, 'm3');
      q.remove('m3');
      expect(q.next, isNull);
    });

    test('addFirst prioritizes retry over queued downloads', () {
      final q = ModelQueue();
      q.add('m1');
      q.add('m2');

      // Retry m2 — should jump to front.
      q.addFirst('m2');
      expect(q.items, ['m2', 'm1']);

      expect(q.next, 'm2');
    });
  });
}
