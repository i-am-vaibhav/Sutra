import '../device/device_tier.dart';
import 'model_registry.dart';
import 'model_definition.dart';

class ModelSelector {
  static ModelDefinition select(DeviceTier tier) {
    switch (tier) {
      case DeviceTier.low:
        return ModelRegistry.smallModel;

      case DeviceTier.mid:
        return ModelRegistry.mediumModel;

      case DeviceTier.high:
        return ModelRegistry.largeModel;
    }
  }
}