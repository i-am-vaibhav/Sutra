import 'package:sutra/runtime/device/device_tier.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';

class ModelPolicy {
  /// Returns the models that should be auto-provisioned on first launch,
  /// selected based on the device's RAM and capabilities.
  ///
  /// - **Low** tier (< 3 GB RAM): 0.8B only — fits comfortably.
  /// - **Mid** tier (3–6 GB RAM): 0.8B + 2B — good balance.
  /// - **High** tier (≥ 6 GB RAM): 0.8B + 4B — best quality without
  ///   risk of OOM. The 9B model is never auto-provisioned; users can
  ///   install it manually from the catalog.
  static List<ModelDefinition> required(DeviceTier tier) {
    switch (tier) {
      case DeviceTier.low:
        return [
          ModelRegistry.qwen35_0_8b,
        ];
      case DeviceTier.mid:
        return [
          ModelRegistry.qwen35_0_8b,
          ModelRegistry.qwen35_2b,
        ];
      case DeviceTier.high:
        return [
          ModelRegistry.qwen35_0_8b,
          ModelRegistry.qwen35_4b,
        ];
    }
  }
}
