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

  final String downloadUrl;
  final String localPath;

  const ModelDefinition({
    required this.id,
    required this.name,
    required this.size,
    required this.contextLength,
    required this.downloadUrl,
    required this.localPath,
  });
}