import 'model_definition.dart';
import 'model_registry.dart';

class ModelCatalog {
  static final List<ModelDefinition> all = [
    ModelRegistry.tiny,
    ModelRegistry.small,
    ModelRegistry.medium,
  ];
}