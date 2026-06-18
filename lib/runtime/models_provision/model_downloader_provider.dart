import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/models_provision/model_downloader.dart';

final modelDownloaderProvider = Provider<ModelDownloader>((ref) {
  // Configure notifications for model downloads.
  FileDownloader().configureNotification(
    running: const TaskNotification('Downloading Model', 'Downloading…'),
    complete: const TaskNotification('Model Ready', 'Model downloaded successfully.'),
    error: const TaskNotification('Download Failed', 'Model download failed. Tap to retry.'),
    progressBar: true,
  );

  ref.onDispose(() {
    FileDownloader().destroy();
  });

  return ModelDownloader();
});