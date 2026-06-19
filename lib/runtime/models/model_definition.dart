import 'package:sutra/runtime/pipeline/chat_template.dart';

enum ModelSize {
  tiny,
  small,
  medium,
  large,
}

/// Capabilities a model can support.
enum ModelCapability {
  /// Can handle web search context (requires ≥8K context).
  webSearch,

  /// Can handle file attachments / RAG.
  fileAnalysis,
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

  /// Capabilities this model supports (e.g. webSearch, fileAnalysis).
  final Set<ModelCapability> capabilities;

  /// Version string for tracking updates (e.g. "1.0.0").
  final String version;

  /// Optional SHA-256 checksum for integrity verification.
  final String? expectedChecksum;

  /// Expected file size in bytes (used for disk space checks).
  final int? fileSizeBytes;

  const ModelDefinition({
    required this.id,
    required this.name,
    required this.size,
    required this.contextLength,
    required this.downloadUrl,
    required this.localPath,
    this.chatTemplate = const GenericChatTemplate(),
    this.capabilities = const <ModelCapability>{},
    this.version = '1.0.0',
    this.expectedChecksum,
    this.fileSizeBytes,
  });

  /// Minimum free disk space required (2× file size as safety margin).
  int get requiredDiskBytes => (fileSizeBytes ?? 0) * 2;

  /// Whether this model supports a given capability.
  bool supports(ModelCapability cap) => capabilities.contains(cap);
}
