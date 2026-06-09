enum ModelSize {
  small,
  medium,
  large,
}

class ModelDefinition {
  final String id;
  final String name;
  final ModelSize size;
  final int contextLength;

  const ModelDefinition({
    required this.id,
    required this.name,
    required this.size,
    required this.contextLength,
  });
}