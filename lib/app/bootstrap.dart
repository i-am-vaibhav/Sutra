import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/device/device_provider.dart';
import 'package:sutra/runtime/models/model_policy.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_manager.dart';
import 'package:sutra/runtime/provisioning/model_manager_provider.dart';
import 'package:sutra/runtime/provisioning/model_paths.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';

Future<void> bootstrapModels(WidgetRef ref) async {
  final tier = await ref.read(deviceTierProvider.future);
  final manager = ref.read(modelManagerProvider);
  final required = ModelPolicy.required(tier);

  // Initialize the ModelManager — restores persisted state, detects
  // files on disk, and recovers interrupted downloads.
  await manager.init(required);

  // Recover downloads that completed while the app was closed
  // (via Android DownloadManager or iOS URLSession background sessions).
  // This must run BEFORE auto-select so recovered models are visible.
  await _recoverBackgroundDownloads(manager);

  final notifier = ref.read(selectedModelIdProvider.notifier);
  if (!notifier.userChoseAuto) {
    final selectedId = ref.read(selectedModelIdProvider);
    if (selectedId == null) {
      final installed = manager.state.modelStates.entries
          .where((e) => e.value == ModelState.downloaded)
          .map((e) => e.key)
          .toList();
      if (installed.isNotEmpty) {
        final first = required.firstWhere(
          (m) => installed.contains(m.id),
          orElse: () => required.first,
        );
        Log.d('[bootstrap] Auto-selecting model: ${first.id}');
        notifier.select(first.id);
      }
    }
  }

  await ModelPaths.cleanupTempFiles();

  await FileDownloader().permissions.request(PermissionType.notifications);

  await manager.provision(required);

  manager.stream.listen((state) {
    final notifier = ref.read(selectedModelIdProvider.notifier);
    if (notifier.userChoseAuto) return;
    final selectedNow = ref.read(selectedModelIdProvider);
    if (selectedNow != null) return;
    final installed = state.installedIds;
    if (installed.isEmpty) return;
    final first = required.firstWhere(
      (m) => installed.contains(m.id),
      orElse: () => required.first,
    );
      Log.d('[bootstrap] Auto-selecting model after download: ${first.id}');
      notifier.select(first.id);
    });
}

/// Check for model files that were downloaded while the app was closed
/// (via Android DownloadManager or iOS URLSession background sessions).
///
/// background_downloader persists completed downloads through the
/// platform's background download system (DownloadManager on Android,
/// URLSession on iOS), so the file may exist on disk but the app's
/// database still shows the model as "downloading" or "paused". This
/// function reconciles the database with reality by scanning for .tmp
/// files that were finalized by the OS, then renaming them to their
/// final paths.
Future<void> _recoverBackgroundDownloads(ModelManager manager) async {
  try {
    final db = ModelDatabase();
    final records = await db.getAll();
    int recovered = 0;

    for (final record in records) {
      // Only check models that were mid-download when app was killed.
      if (record.state != ModelState.downloading &&
          record.state != ModelState.paused) {
        continue;
      }

      // Check if the final file already exists (download completed in background).
      final file = await ModelPaths.fileFor(record.localPath);
      if (await file.exists()) {
        final fileSize = await file.length();
        await db.upsert(record.copyWith(
          state: ModelState.downloaded,
          progress: 1.0,
          downloadedBytes: fileSize,
          downloadTaskId: null,
        ));
        recovered++;
        Log.d('[bootstrap] Recovered background download: ${record.name} ($fileSize bytes)');
        continue;
      }

      // Check for a .tmp file that may have been completed but not renamed.
      final tmpFile = File('${file.path}.tmp');
      if (await tmpFile.exists()) {
        if (!await file.parent.exists()) {
          await file.parent.create(recursive: true);
        }
        await tmpFile.rename(file.path);
        final fileSize = await file.length();
        await db.upsert(record.copyWith(
          state: ModelState.downloaded,
          progress: 1.0,
          downloadedBytes: fileSize,
          downloadTaskId: null,
        ));
        recovered++;
        Log.d('[bootstrap] Recovered temp file: ${record.name} ($fileSize bytes)');
      }
    }

    if (recovered > 0) {
      Log.d('[bootstrap] Recovered $recovered background downloads');
    }
  } catch (e) {
    Log.w('[bootstrap] Background download recovery failed: $e');
  }
}
