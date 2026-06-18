import 'package:sutra/runtime/device/device_tier.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';

class ModelPolicy {
  /// Returns the models that should be provisioned for a given [tier].
  ///
  /// Models are ordered smallest-first so the most important ones
  /// are downloaded first.  Tier boundaries account for real device
  /// RAM minus OS overhead:
  ///
  /// | Tier  | Typical RAM | Models                               |
  /// |-------|-------------|--------------------------------------|
  /// | low   | 2-4 GB      | micro + tiny (~1.1 GB)               |
  /// | mid   | 4-8 GB      | tiny + small + gemma2b + llama32_1b  |
  /// | high  | 8 GB+       | all eight (~10.3 GB)                 |
  static List<ModelDefinition> required(DeviceTier tier) {
    switch (tier) {
      case DeviceTier.low:
        return [
          ModelRegistry.micro,
          ModelRegistry.tiny,
        ];

      case DeviceTier.mid:
        return [
          ModelRegistry.tiny,
          ModelRegistry.small,
          ModelRegistry.gemma2b,
          ModelRegistry.llama32_1b,
        ];

      case DeviceTier.high:
        return [
          ModelRegistry.micro,
          ModelRegistry.tiny,
          ModelRegistry.small,
          ModelRegistry.gemma2b,
          ModelRegistry.llama32_1b,
          ModelRegistry.medium,
          ModelRegistry.llama32_3b,
          ModelRegistry.phi3Mini,
        ];
    }
  }
}
