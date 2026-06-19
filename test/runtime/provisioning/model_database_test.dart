import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';

void main() {
  // Initialize sqflite_ffi for desktop testing.
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late ModelDatabase db;

  setUp(() async {
    // Create a fresh in-memory database for each test.
    db = ModelDatabase.test(() => openDatabase(
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
  });

  tearDown(() async {
    await db.close();
  });

  ModelRecord makeRecord({
    String id = 'test-model',
    String name = 'Test Model',
    ModelState state = ModelState.notDownloaded,
    String downloadUrl = 'https://example.com/model.gguf',
  }) {
    return ModelRecord(
      id: id,
      name: name,
      version: '1.0.0',
      state: state,
      localPath: '$id.gguf',
      downloadUrl: downloadUrl,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('ModelDatabase', () {
    test('get returns null for unknown id', () async {
      final result = await db.get('nonexistent');
      expect(result, isNull);
    });

    test('upsert and get round-trips', () async {
      final record = makeRecord(id: 'm1', name: 'Model One');
      await db.upsert(record);
      final fetched = await db.get('m1');
      expect(fetched, isNotNull);
      expect(fetched!.id, 'm1');
      expect(fetched.name, 'Model One');
      expect(fetched.state, ModelState.notDownloaded);
    });

    test('upsert replaces existing record', () async {
      final r1 = makeRecord(id: 'm1', state: ModelState.downloaded);
      await db.upsert(r1);
      final r2 = makeRecord(id: 'm1', state: ModelState.failed);
      await db.upsert(r2);
      final fetched = await db.get('m1');
      expect(fetched!.state, ModelState.failed);
    });

    test('updateState changes state', () async {
      await db.upsert(makeRecord(id: 'm1'));
      await db.updateState('m1', ModelState.downloading);
      final fetched = await db.get('m1');
      expect(fetched!.state, ModelState.downloading);
    });

    test('updateProgress updates progress and bytes', () async {
      await db.upsert(makeRecord(id: 'm1'));
      await db.updateProgress('m1', 0.75, 7500);
      final fetched = await db.get('m1');
      expect(fetched!.progress, 0.75);
      expect(fetched.downloadedBytes, 7500);
    });

    test('markFailed sets state and error message', () async {
      await db.upsert(makeRecord(id: 'm1'));
      await db.markFailed('m1', 'Network error');
      final fetched = await db.get('m1');
      expect(fetched!.state, ModelState.failed);
      expect(fetched.errorMessage, 'Network error');
      expect(fetched.downloadTaskId, isNull);
    });

    test('getAll returns records ordered by updated_at', () async {
      await db.upsert(makeRecord(id: 'm1'));
      await db.upsert(makeRecord(id: 'm2'));
      final all = await db.getAll();
      expect(all.length, 2);
    });

    test('getByState filters correctly', () async {
      await db.upsert(makeRecord(id: 'm1', state: ModelState.downloaded));
      await db.upsert(makeRecord(id: 'm2', state: ModelState.downloading));
      await db.upsert(makeRecord(id: 'm3', state: ModelState.downloaded));
      final downloaded = await db.getByState(ModelState.downloaded);
      expect(downloaded.length, 2);
      expect(downloaded.every((r) => r.state == ModelState.downloaded), isTrue);
    });

    test('getInstalledIds returns only downloaded', () async {
      await db.upsert(makeRecord(id: 'm1', state: ModelState.downloaded));
      await db.upsert(makeRecord(id: 'm2', state: ModelState.downloading));
      await db.upsert(makeRecord(id: 'm3', state: ModelState.downloaded));
      final ids = await db.getInstalledIds();
      expect(ids, containsAll(['m1', 'm3']));
      expect(ids, isNot(contains('m2')));
    });

    test('totalDownloadedSize sums file sizes', () async {
      await db.upsert(makeRecord(id: 'm1', state: ModelState.downloaded));
      await db.upsert(makeRecord(id: 'm1').copyWith(
        state: ModelState.downloaded,
        fileSizeBytes: 1000,
      ));
      await db.upsert(makeRecord(id: 'm2', state: ModelState.downloaded));
      await db.upsert(makeRecord(id: 'm2').copyWith(
        state: ModelState.downloaded,
        fileSizeBytes: 2000,
      ));
      final total = await db.totalDownloadedSize();
      expect(total, 3000);
    });

    test('delete removes record', () async {
      await db.upsert(makeRecord(id: 'm1'));
      await db.delete('m1');
      final result = await db.get('m1');
      expect(result, isNull);
    });

    test('countByState returns correct counts', () async {
      await db.upsert(makeRecord(id: 'm1', state: ModelState.downloaded));
      await db.upsert(makeRecord(id: 'm2', state: ModelState.downloading));
      await db.upsert(makeRecord(id: 'm3', state: ModelState.downloaded));
      final counts = await db.countByState();
      expect(counts[ModelState.downloaded], 2);
      expect(counts[ModelState.downloading], 1);
    });

    test('ModelRecord serialization round-trip', () {
      final record = makeRecord(id: 'm1');
      final map = record.toMap();
      final restored = ModelRecord.fromMap(map);
      expect(restored.id, record.id);
      expect(restored.name, record.name);
      expect(restored.state, record.state);
      expect(restored.version, record.version);
      expect(restored.downloadUrl, record.downloadUrl);
    });

    test('ModelRecord copyWith creates new instance', () {
      final r = makeRecord(id: 'm1', state: ModelState.notDownloaded);
      final r2 = r.copyWith(
        state: ModelState.downloading,
        progress: 0.5,
        downloadedBytes: 500,
      );
      expect(r.state, ModelState.notDownloaded);
      expect(r2.state, ModelState.downloading);
      expect(r2.progress, 0.5);
      expect(r2.downloadedBytes, 500);
    });
  });
}
