import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sutra/runtime/models/model_catalog.dart';
import 'package:sutra/runtime/models/model_catalog_entry.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/orchestration/chat_template.dart';

/// Fetches and caches the remote model catalog.
///
/// Falls back to [ModelCatalog.fallback] if the network request fails.
class ModelCatalogService {
  static const _catalogUrl =
      'https://raw.githubusercontent.com/i-am-vaibhav/Sutra/main/models/catalog.json';

  final http.Client _client;

  ModelCatalogService({http.Client? client}) : _client = client ?? http.Client();

  ModelCatalog? _catalog;

  /// Synchronous access to the cached catalog (falls back to embedded catalog
  /// if the remote fetch hasn't completed yet).
  ModelCatalog get catalog => _catalog ?? ModelCatalog.fallback;

  /// Get the catalog (fetches from remote on first call, then cached).
  Future<ModelCatalog> getCatalog() async {
    if (_catalog != null) return _catalog!;

    try {
      final response = await _client
          .get(Uri.parse(_catalogUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        _catalog = ModelCatalog.fromJson(json);
        debugPrint('[ModelCatalogService] Loaded remote catalog: '
            '${_catalog!.categories.length} categories, '
            '${_catalog!.allEntries.length} models');
        return _catalog!;
      }
    } catch (e) {
      debugPrint('[ModelCatalogService] Failed to fetch remote catalog: $e');
    }

    // Fall back to embedded catalog.
    _catalog = ModelCatalog.fallback;
    debugPrint('[ModelCatalogService] Using fallback catalog: '
        '${_catalog!.allEntries.length} models');
    return _catalog!;
  }

  /// Convert a catalog entry into a [ModelDefinition] using auto-detected
  /// chat template.
  ModelDefinition toModelDefinition(ModelCatalogEntry entry) {
    final template = _detectTemplate(entry.chatTemplateHint);
    return ModelDefinition(
      id: entry.id,
      name: entry.name,
      size: _inferSize(entry),
      contextLength: entry.contextLength,
      downloadUrl: entry.downloadUrl,
      localPath: entry.localPath,
      chatTemplate: template,
    );
  }

  /// Auto-detect chat template from the hint string.
  ChatTemplate _detectTemplate(String hint) {
    final h = hint.toLowerCase();
    if (h.contains('qwen')) return const QwenChatTemplate();
    if (h.contains('tinyllama') || h.contains('tiny')) {
      return const TinyLlamaChatTemplate();
    }
    if (h.contains('llama3') || h.contains('llama-3')) {
      return const Llama3ChatTemplate();
    }
    if (h.contains('phi')) return const Phi3ChatTemplate();
    if (h.contains('gemma')) return const GemmaChatTemplate();
    return const GenericChatTemplate();
  }

  /// Infer model size category from the entry.
  ModelSize _inferSize(ModelCatalogEntry entry) {
    final name = entry.name.toLowerCase();
    // Look for parameter count in the name.
    final regex = RegExp(r'(\d+\.?\d*)[bB]');
    final match = regex.firstMatch(name);
    if (match != null) {
      final params = double.tryParse(match.group(1)!) ?? 0;
      if (params <= 1) return ModelSize.tiny;
      if (params <= 2) return ModelSize.small;
      if (params <= 4) return ModelSize.medium;
      return ModelSize.large;
    }
    return ModelSize.medium;
  }
}
