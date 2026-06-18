import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/device/device_provider.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_policy.dart';

class RuntimeRouter {
  final Ref ref;

  RuntimeRouter(this.ref);

  Future<ModelDefinition> resolveChatModel() async {
    final tier = await ref.read(deviceTierProvider.future);

    final models = ModelPolicy.required(tier);

    if (models.isEmpty) {
      throw Exception('No models available for device tier: $tier');
    }

    return models.last;
  }

  Future<List<ModelDefinition>> resolveAvailableModels() async {
    final tier = await ref.read(deviceTierProvider.future);
    return ModelPolicy.required(tier);
  }
}