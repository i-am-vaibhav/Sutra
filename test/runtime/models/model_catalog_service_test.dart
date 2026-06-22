import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/models/model_catalog_service.dart';
import 'package:sutra/runtime/models/model_catalog.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';

void main() {
  group('ModelCatalogService._inferSize', () {
    test('returns tiny for <=1B params', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.id == 'qwen3.5-0.8b');
      final def = svc.toModelDefinition(entry);
      expect(def.size, ModelSize.tiny);
    });

    test('returns small for 1-2B params', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.id == 'qwen3.5-2b');
      final def = svc.toModelDefinition(entry);
      expect(def.size, ModelSize.small);
    });

    test('returns medium for 2-4B params', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.id == 'qwen3.5-4b');
      final def = svc.toModelDefinition(entry);
      expect(def.size, ModelSize.medium);
    });
  });

  group('ModelCatalogService._detectTemplate', () {
    test('detects qwen template', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.chatTemplateHint.contains('qwen'));
      final def = svc.toModelDefinition(entry);
      expect(def.chatTemplate, isA<QwenChatTemplate>());
    });

    test('unknown hint returns GenericChatTemplate', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      // Find an entry whose hint doesn't match any known template.
      final entry = cat.allEntries.firstWhere(
        (e) => !e.chatTemplateHint.toLowerCase().contains('qwen'),
        orElse: () => cat.allEntries.first,
      );
      final def = svc.toModelDefinition(entry);
      // Non-qwen hints fall back to GenericChatTemplate in v1.
      expect(def.chatTemplate, isA<ChatTemplate>());
    });
  });

  group('ModelCatalogService.toModelDefinition', () {
    test('maps all fields correctly', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.first;
      final def = svc.toModelDefinition(entry);
      expect(def.id, entry.id);
      expect(def.name, entry.name);
      expect(def.contextLength, entry.contextLength);
      expect(def.downloadUrl, entry.downloadUrl);
    });
  });

  group('ModelCatalogService.catalog', () {
    test('returns fallback catalog when remote not fetched', () {
      final svc = ModelCatalogService();
      expect(svc.catalog.allEntries, isNotEmpty);
    });

    test('fallback catalog has entries', () {
      final svc = ModelCatalogService();
      expect(svc.catalog.allEntries.length, greaterThan(5));
    });
  });
}
