import '../device/device_tier.dart';
import 'model_definition.dart';
import 'model_registry.dart';

class ModelPolicy {
  static List<ModelDefinition> required(DeviceTier tier) {
    switch (tier) {
      case DeviceTier.low:
        return [
          ModelRegistry.tiny,
        ];

      case DeviceTier.mid:
        return [
          ModelRegistry.tiny,
          ModelRegistry.small,
        ];

      case DeviceTier.high:
        return [
          ModelRegistry.tiny,
          ModelRegistry.small,
          ModelRegistry.medium,
        ];
    }
  }
}