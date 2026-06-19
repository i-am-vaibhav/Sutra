import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:crypto/crypto.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_paths.dart';

/// Events emitted by the downloader during a download.
class DownloadEvent {
  final double progress;
  final int downloadedBytes;
  final String? error;
  final bool completed;

  const DownloadEvent({
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.error,
    this.completed = false,
  });
}

/// Model downloader with WiFi-only preference, SHA-256 checksum verification,
/// and temp file management.
///
/// Uses a single, long-lived subscription to [FileDownloader].updates
/// so that concurrent and sequential downloads all work reliably.
/// The stream is broadcast-routed by taskId to per-download handlers.
class ModelDownloader {
  static const int maxAttempts = 3;

  // ── Global updates subscription ──────────────────────────
  // FileDownloader().updates is backed by a single-subscription
  // StreamController.  Listening to it multiple times (e.g. once
  // per download) fails.  We keep ONE subscription alive for the
  // lifetime of this object and route updates by taskId.
  StreamSubscription? _globalUpdatesSub;

  /// TaskId → broadcast controller that delivers matching updates.
  final Map<String, StreamController<dynamic>> _taskControllers = {};

  /// TaskId → completer so the onDone handler can fail in-flight downloads.
  final Map<String, Completer<void>> _taskCompleters = {};

  /// Fail all active downloads and clean up task controllers/completers.
  void _failActiveDownloads(String reason) {
    for (final entry in _taskCompleters.entries.toList()) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(Exception(reason));
      }
    }
    for (final c in _taskControllers.values) {
      if (!c.isClosed) c.close();
    }
    _taskControllers.clear();
    _taskCompleters.clear();
  }

  /// Lazily (re-)attach the global subscription to [FileDownloader].updates.
  /// If the previous subscription died (e.g. stream controller was reset),
  /// we recreate it automatically.
  void _ensureGlobalSubscription() {
    if (_globalUpdatesSub != null) return;
    _globalUpdatesSub = FileDownloader().updates.listen(
      (update) {
        final controller = _taskControllers[update.task.taskId];
        if (controller != null && !controller.isClosed) {
          controller.add(update);
        }
      },
      onDone: () {
        Log.d('[ModelDownloader] updates stream done – failing active downloads');
        _globalUpdatesSub = null;
        _failActiveDownloads('Updates stream closed by background_downloader');
      },
      onError: (Object error) {
        Log.e('[ModelDownloader] updates stream error: $error');
        _globalUpdatesSub = null;
        _failActiveDownloads('Updates stream error: $error');
      },
    );
  }

  /// Detach the global subscription (e.g. on dispose).
  Future<void> dispose() async {
    await _globalUpdatesSub?.cancel();
    _globalUpdatesSub = null;
    for (final c in _taskControllers.values) {
      await c.close();
    }
    _taskControllers.clear();
  }

  /// Download a model file using background_downloader.
  Future<void> download({
    required ModelDefinition model,
    required bool requireWifi,
    required void Function(DownloadEvent event) onEvent,
    required ModelDatabase database,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        await _attemptDownload(
          model: model,
          requireWifi: requireWifi,
          onEvent: onEvent,
          database: database,
        );
        return;
      } catch (e) {
        Log.w('[ModelDownloader] Attempt  $e');
        if (attempt >= maxAttempts - 1) rethrow;
        attempt++;
        onEvent(DownloadEvent(progress: 0, error: 'Retry $attempt/$maxAttempts'));
        await Future<void>.delayed(Duration(seconds: 2 * attempt));
      }
    }
  }

  Future<void> _attemptDownload({
    required ModelDefinition model,
    required bool requireWifi,
    required void Function(DownloadEvent event) onEvent,
    required ModelDatabase database,
  }) async {
    final finalFile = await ModelPaths.fileFor(model.localPath);
    final tempFile = File('${finalFile.path}.tmp');

    if (!await finalFile.parent.exists()) {
      await finalFile.parent.create(recursive: true);
    }

    // Compute the directory relative to BaseDirectory.applicationDocuments
    // so background_downloader saves the file exactly where tempFile expects it.
    final appDocsDir = await getApplicationDocumentsDirectory();
    final relativeDir = p.relative(tempFile.parent.path, from: appDocsDir.path);

    final task = DownloadTask(
      url: model.downloadUrl,
      filename: tempFile.path.split('/').last,
      directory: relativeDir,
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      requiresWiFi: requireWifi,
      allowPause: true,
      metaData: model.id,
    );

    await database.updateDownloadTask(model.id, task.taskId);

    // Register a per-task broadcast controller so the global subscription
    // can route matching updates to us.
    _ensureGlobalSubscription();
    final controller = StreamController<dynamic>.broadcast();
    _taskControllers[task.taskId] = controller;
    final completer = Completer<void>();
    _taskCompleters[task.taskId] = completer;

    final taskSub = controller.stream.listen((update) {
      if (update is TaskStatusUpdate) {
        if (update.status == TaskStatus.complete) {
          if (!completer.isCompleted) completer.complete();
        } else if (update.status == TaskStatus.failed) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('Download failed: ${update.status}'));
          }
        } else if (update.status == TaskStatus.canceled) {
          if (!completer.isCompleted) {
            completer.completeError(Exception('Download canceled'));
          }
        }
      } else if (update is TaskProgressUpdate) {
        onEvent(DownloadEvent(
          progress: update.progress,
          downloadedBytes: update.expectedFileSize > 0
              ? (update.progress * update.expectedFileSize).toInt()
              : 0,
        ));
      }
    });

    await FileDownloader().enqueue(task);

    try {
      // Timeout prevents a hung download from blocking the queue forever.
      await completer.future.timeout(const Duration(minutes: 10));
    } on TimeoutException {
      completer.completeError(Exception('Download timed out after 10 minutes'));
    } finally {
      await taskSub.cancel();
      _taskControllers.remove(task.taskId);
      _taskCompleters.remove(task.taskId);
      await controller.close();
    }

    // ── Checksum verification ────────────────────────────
    if (model.expectedChecksum != null && model.expectedChecksum!.isNotEmpty) {
      onEvent(DownloadEvent(progress: 1.0));
      final verified = await _verifyChecksum(tempFile, model.expectedChecksum!);
      if (!verified) {
        await tempFile.delete(recursive: true);
        throw Exception('Checksum verification failed for ${model.name}');
      }
    }

    // ── Move temp → final ───────────────────────────────
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    await tempFile.rename(finalFile.path);

    // ── Update database ──────────────────────────────────
    final fileSize = await finalFile.length();
    final record = await database.get(model.id);
    if (record != null) {
      await database.upsert(record.copyWith(
        state: ModelState.downloaded,
        progress: 1.0,
        downloadedBytes: fileSize,
        downloadTaskId: null,
      ));
    }

    onEvent(DownloadEvent(progress: 1.0, completed: true, downloadedBytes: fileSize));
  }

  /// Cancel an active download and clean up temp files.
  Future<void> cancelDownload(String taskId, ModelDefinition model) async {
    await FileDownloader().cancelTaskWithId(taskId);
    final file = await ModelPaths.fileFor(model.localPath);
    final tempFile = File('${file.path}.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete(recursive: true);
    }
  }

  /// Delete a downloaded model file and clean up.
  Future<void> deleteModel(ModelDefinition model) async {
    final file = await ModelPaths.fileFor(model.localPath);
    if (await file.exists()) {
      await file.delete(recursive: true);
    }
    final tempFile = File('${file.path}.tmp');
    if (await tempFile.exists()) {
      await tempFile.delete(recursive: true);
    }
  }

  /// Get file size for a downloaded model.
  Future<int> getFileSize(ModelDefinition model) async {
    final file = await ModelPaths.fileFor(model.localPath);
    if (await file.exists()) {
      return file.length();
    }
    return 0;
  }

  /// Verify SHA-256 checksum of a file using streaming to avoid OOM on large models.
  Future<bool> _verifyChecksum(File file, String expected) async {
    try {
      final stream = file.openRead();
      final digest = await sha256.bind(stream).first;
      return digest.toString().toLowerCase() == expected.toLowerCase();
    } catch (e) {
      Log.e('[ModelDownloader] Checksum verification error: $e');
      return false;
    }
  }
}
