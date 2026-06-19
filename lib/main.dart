import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/app/app_bootstrap.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/models/model_registry.dart';

const _firstInstallKey = 'first_model_download_enqueued';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure background_downloader for persistent downloads on both platforms.
  // Android: DownloadManager persists downloads across app kills.
  //          runInForeground allows tasks longer than the 9-minute background limit.
  // iOS:     URLSessionConfiguration.background handles background transfers.
  //          excludeFromCloudBackup prevents large model files from being
  //          backed up to iCloud (saves user's iCloud storage).
  await FileDownloader().configure(
    globalConfig: [
      (Config.requestTimeout, Duration(minutes: 30)),
      (Config.excludeFromCloudBackup, true),
    ],
    androidConfig: [
      (Config.runInForeground, true),
    ],
  );

  // On first install, immediately enqueue the smallest model for download
  // so it starts downloading before the UI loads.
  // Android: uses system DownloadManager which persists across app kills.
  // iOS: uses URLSession background session managed by the OS.
  _enqueueSmallestModel();

  runApp(const ProviderScope(child: AppBootstrap()));
}

/// Enqueue the smallest model for download immediately on first install.
///
/// This runs before the Flutter widget tree loads, so the download starts
/// as early as possible.
/// Android: FileDownloader uses the system DownloadManager which persists
///          downloads even after the app is killed.
/// iOS: FileDownloader uses URLSession background sessions which the OS
///      manages independently — downloads continue even if the app is
///      suspended or terminated by the system.
/// The bootstrap flow will detect the in-progress download and track it.
void _enqueueSmallestModel() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_firstInstallKey) == true) return;

    // Pick the smallest model from the registry.
    final model = ModelRegistry.all.first;

    // Check if the model file already exists on disk.
    final appDocs = await getApplicationDocumentsDirectory();
    final file = File(p.join(appDocs.path, 'models', model.localPath));
    if (await file.exists()) {
      await prefs.setBool(_firstInstallKey, true);
      return;
    }

    // Check if a download is already in progress for this model.
    final existingTasks =
        await FileDownloader().allTasks();
    final alreadyQueued = existingTasks.any(
      (t) => t.metaData == model.id ||
          t.filename == '${model.localPath}.tmp',
    );
    if (alreadyQueued) {
      await prefs.setBool(_firstInstallKey, true);
      return;
    }

    // Enqueue via platform background download system.
    // Android: DownloadManager — persists across app kills.
    // iOS: URLSession background session — OS-managed persistence.
    final tempFile = File('${file.path}.tmp');
    final appDocsDir = await getApplicationDocumentsDirectory();
    final relativeDir = p.relative(tempFile.parent.path, from: appDocsDir.path);

    final task = DownloadTask(
      url: model.downloadUrl,
      filename: tempFile.path.split('/').last,
      directory: relativeDir,
      baseDirectory: BaseDirectory.applicationDocuments,
      updates: Updates.statusAndProgress,
      requiresWiFi: true,
      allowPause: true,
      metaData: model.id,
    );

    await FileDownloader().enqueue(task);
    // Only mark as done after successful enqueue so retries work on next launch.
    await prefs.setBool(_firstInstallKey, true);
    Log.d('[main] Enqueued ${model.name} for download on first install');
  } catch (e) {
    // Non-fatal: bootstrap flow will handle downloads as fallback.
    // Flag is NOT set so we retry on next app launch.
    Log.d('[main] Early download enqueue failed: $e');
  }
}
