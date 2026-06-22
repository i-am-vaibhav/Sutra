/// A curated model entry fetched from the remote catalog.
///
/// Unlike [ModelDefinition] which is hardcoded in the app, catalog entries
/// can be updated without an app release by changing the remote JSON.
class ModelCatalogEntry {
  final String id;
  final String name;
  final String description;
  final String category;
  final String downloadUrl;
  final String localPath;
  final int contextLength;
  final String? sizeBytes;
  final String chatTemplateHint;
  final List<String> capabilities;

  const ModelCatalogEntry({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.downloadUrl,
    required this.localPath,
    this.contextLength = 4096,
    this.sizeBytes,
    this.chatTemplateHint = 'generic',
    this.capabilities = const [],
  });

  factory ModelCatalogEntry.fromJson(Map<String, dynamic> json) {
    return ModelCatalogEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      downloadUrl: json['downloadUrl'] as String,
      localPath: json['localPath'] as String,
      contextLength: json['contextLength'] as int? ?? 4096,
      sizeBytes: json['sizeBytes'] as String?,
      chatTemplateHint: json['chatTemplate'] as String? ?? 'generic',
      capabilities: (json['capabilities'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'category': category,
    'downloadUrl': downloadUrl,
    'localPath': localPath,
    'contextLength': contextLength,
    'sizeBytes': sizeBytes,
    'chatTemplate': chatTemplateHint,
    'capabilities': capabilities,
  };
}

/// A category of models in the catalog (e.g. Chat, Coding, Research).
class ModelCatalogCategory {
  final String name;
  final String icon;
  final String description;
  final List<ModelCatalogEntry> entries;

  const ModelCatalogCategory({
    required this.name,
    required this.icon,
    required this.description,
    required this.entries,
  });

  factory ModelCatalogCategory.fromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as List)
        .map((e) => ModelCatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
    return ModelCatalogCategory(
      name: json['name'] as String,
      icon: json['icon'] as String? ?? 'smart_toy',
      description: json['description'] as String? ?? '',
      entries: entries,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'icon': icon,
        'description': description,
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}
