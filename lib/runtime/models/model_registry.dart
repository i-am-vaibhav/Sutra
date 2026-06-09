import 'model_definition.dart';

class ModelRegistry {
  static const smallModel = ModelDefinition(
    id: "sutra-small",
    name: "Sutra Mini",
    size: ModelSize.small,
    contextLength: 2048,
  );

  static const mediumModel = ModelDefinition(
    id: "sutra-medium",
    name: "Sutra Base",
    size: ModelSize.medium,
    contextLength: 4096,
  );

  static const largeModel = ModelDefinition(
    id: "sutra-large",
    name: "Sutra Pro",
    size: ModelSize.large,
    contextLength: 8192,
  );
}