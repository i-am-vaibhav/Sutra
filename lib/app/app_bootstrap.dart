import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../runtime/device/device_provider.dart';
import '../runtime/models/model_policy.dart';
import '../runtime/models/model_provisioning_service.dart';

Future<void> bootstrapModels(WidgetRef ref) async {
  final tier = await ref.read(deviceTierProvider.future);

  final service = ref.read(modelProvisioningServiceProvider);

  final requiredModels = ModelPolicy.required(tier)
      .map((m) => m.id)
      .toList();

  await service.provision(requiredModels);
}