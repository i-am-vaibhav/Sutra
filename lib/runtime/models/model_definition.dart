import 'package:sutra/runtime/orchestration/chat_template.dart';

enum ModelSize {
  tiny,
  small,
  medium,
  large,
}

/// Human-readable label for a [ModelSize].
String sizeLabel(ModelSize size) {
  switch (size) {
    case ModelSize.tiny:
      return 'Tiny';
    case ModelSize.small:
      return 'Small';
    case ModelSize.medium:
      return 'Medium';
    case ModelSize.large:
      return 'Large';
  }
}

class ModelDefinition {
  final String id;
  final String name;
  final ModelSize size;
  final int contextLength;
  final String downloadUrl;
  final String localPath;
  final ChatTemplate chatTemplate;

  const ModelDefinition({
    required this.id,
    required this.name,
    required this.size,
    required this.contextLength,
    required this.downloadUrl,
    required this.localPath,
    this.chatTemplate = const GenericChatTemplate(),
  });
}
