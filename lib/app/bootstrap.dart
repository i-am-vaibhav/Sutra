import 'package:background_downloader/background_downloader.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/device/device_provider.dart';
import 'package:sutra/runtime/models/model_policy.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_manager_provider.dart';
import 'package:sutra/runtime/provisioning/model_paths.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';

Future<void> bootstrapModels(WidgetRef ref) async {
  final tier = await ref.read(deviceTierProvider.future);
  final manager = ref.read(modelManagerProvider);
  final required = ModelPolicy.required(tier);

  // files on disk, and recovers interrupted downloads.
  await manager.init(required);

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
