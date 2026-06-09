import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/models_provision/model_provisioning_service.dart';
import '../runtime/device/device_provider.dart';
import '../runtime/models/model_policy.dart';

Future<void> bootstrapModels(WidgetRef ref) async {
  final tier = await ref.read(deviceTierProvider.future);

  final service = ref.read(modelProvisioningServiceProvider);

  final models = ModelPolicy.required(tier);

  await service.provision(models);

}