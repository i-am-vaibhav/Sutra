import 'package:sutra/runtime/device/device_tier.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';

class ModelPolicy {
  /// Returns the models that should be auto-provisioned on first launch.
  ///
  /// Only two models are downloaded by default:
  /// - One tiny model for basic chat (smallest available)
  /// - One web search capable model (smallest with ≥8K context)
  ///
  /// Other models are available for the user to install manually.
  static List<ModelDefinition> required(DeviceTier tier) {
    return [
      ModelRegistry.qwen3_0_6b,     // Tiny chat model (~0.6B)
      ModelRegistry.gemma3_1b,      // Web search model (~1B, 8K context)
    ];
  }
}
