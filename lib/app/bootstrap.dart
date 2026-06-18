import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/device/device_provider.dart';
import 'package:sutra/runtime/models/model_policy.dart';
import 'package:sutra/runtime/models_provision/model_paths.dart';
import 'package:sutra/runtime/models_provision/model_provisioning_service.dart';
import 'package:sutra/runtime/models_provision/model_store_provider.dart';
import 'package:sutra/runtime/orchestration/selected_model_provider.dart';

Future<void> bootstrapModels(WidgetRef ref) async {
  final tier = await ref.read(deviceTierProvider.future);

  final store = ref.read(modelStoreProvider);
  final service = ref.read(modelProvisioningServiceProvider);

  // Restore previously-installed models so we don't re-download them.
  final installed = await store.loadInstalled();

  // Detect models downloaded while the app was closed.
  // background_downloader persists via native DownloadManager,
  // so files may exist on disk but not be in ModelStore yet.
  final required = ModelPolicy.required(tier);
  for (final model in required) {
    if (!installed.contains(model.id)) {
      final file = await ModelPaths.fileFor(model.localPath);
      if (await file.exists()) {
        installed.add(model.id);
      }
    }
  }
  await store.saveInstalled(installed);

  // Auto-select the first installed model if none is selected yet.
  final selectedId = ref.read(selectedModelIdProvider);
  if (selectedId == null && installed.isNotEmpty) {
    final firstInstalled = required.firstWhere(
      (m) => installed.contains(m.id),
      orElse: () => required.first,
    );
    ref.read(selectedModelIdProvider.notifier).select(firstInstalled.id);
  }

  await service.init(installed);

  // Request notification permission on Android 13+ so
  // download progress notifications are visible.
  await FileDownloader().permissions.request(PermissionType.notifications);

  await service.provision(required);
}
