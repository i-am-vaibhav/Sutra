import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:background_downloader/background_downloader.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models_provision/model_paths.dart';

class ModelDownloader {
  /// Maximum number of total attempts (1 initial + retries).
  static const int maxAttempts = 3;

  /// Base delay for exponential backoff (doubled each retry).
  static const Duration baseRetryDelay = Duration(seconds: 2);

  /// Download a model file using background_downloader.
  ///
  /// Retries up to [maxRetries] times with exponential backoff on
  /// transient failures (network errors, HTTP 429/5xx, etc.).
  Future<void> download({
    required ModelDefinition model,
    required void Function(double progress) onProgress,
    void Function(int attempt)? onRetry,
  }) async {
    int attempt = 0;

    while (true) {
      try {
        await _attemptDownload(
          model: model,
          onProgress: onProgress,
        );
        return; // success
      } catch (e) {
        if (!_isRetryable(e) || attempt >= maxAttempts - 1) {
          rethrow;
        }

        attempt++;
        onRetry?.call(attempt);

        // Exponential backoff: 2s, 4s, 8s …
        final delay = baseRetryDelay * pow(2, attempt - 1);
        await Future<void>.delayed(delay);
      }
    }
  }

  /// Single download attempt.
  Future<void> _attemptDownload({
    required ModelDefinition model,
    required void Function(double progress) onProgress,
  }) async {
    final file = await ModelPaths.fileFor(model.localPath);

    final task = DownloadTask(
      url: model.downloadUrl,
      filename: file.path.split('/').last,
      directory: 'models',
      updates: Updates.statusAndProgress,
      requiresWiFi: false,
      allowPause: true,
      metaData: model.id,
    );

    // Listen for progress updates while the download runs.
    final completer = Completer<void>();

    final subscription =
        FileDownloader().updates.listen((update) {
      if (update.task.taskId == task.taskId) {
        if (update is TaskStatusUpdate) {
          if (update.status == TaskStatus.complete) {
            if (!completer.isCompleted) completer.complete();
          } else if (update.status == TaskStatus.failed ||
              update.status == TaskStatus.canceled) {
            if (!completer.isCompleted) {
              completer.completeError(
                Exception('Download failed: ${update.status}'),
              );
            }
          }
        } else if (update is TaskProgressUpdate) {
          onProgress(update.progress);
        }
      }
    });

    await FileDownloader().enqueue(task);

    try {
      await completer.future;
    } finally {
      await subscription.cancel();
    }
  }

  /// Whether the error is transient and worth retrying.
  bool _isRetryable(Object error) {
    // Type-based checks first (reliable).
    if (error is SocketException || error is TimeoutException) {
      return true;
    }
    // Fall back to message matching for library-wrapped errors.
    final msg = error.toString().toLowerCase();
    return msg.contains('http 429') ||
        msg.contains('http 5');
  }
}