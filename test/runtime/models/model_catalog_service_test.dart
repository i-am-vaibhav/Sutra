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
      final entry = cat.allEntries.firstWhere((e) => e.id == 'qwen2.5-0.5b');
      final def = svc.toModelDefinition(entry);
      expect(def.size, ModelSize.tiny);
    });

    test('returns small for 1-2B params', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.id == 'tinyllama-1.1b');
      final def = svc.toModelDefinition(entry);
      expect(def.size, ModelSize.small);
    });

    test('returns medium for 2-4B params', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.id == 'qwen2.5-3b');
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

    test('detects tinyllama template', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.chatTemplateHint.contains('tiny'));
      final def = svc.toModelDefinition(entry);
      expect(def.chatTemplate, isA<TinyLlamaChatTemplate>());
    });

    test('detects llama3 template', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.chatTemplateHint.contains('llama3') || e.chatTemplateHint.contains('llama-3'));
      final def = svc.toModelDefinition(entry);
      expect(def.chatTemplate, isA<Llama3ChatTemplate>());
    });

    test('detects phi3 template', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.chatTemplateHint.contains('phi'));
      final def = svc.toModelDefinition(entry);
      expect(def.chatTemplate, isA<Phi3ChatTemplate>());
    });

    test('detects gemma template', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => e.chatTemplateHint.contains('gemma'));
      final def = svc.toModelDefinition(entry);
      expect(def.chatTemplate, isA<GemmaChatTemplate>());
    });

    test('falls back to GenericChatTemplate for unknown hint', () {
      final svc = ModelCatalogService();
      final cat = ModelCatalog.fallback;
      final entry = cat.allEntries.firstWhere((e) => !e.chatTemplateHint.toLowerCase().contains(RegExp(r'qwen|tiny|llama|phi|gemma')));
      final def = svc.toModelDefinition(entry);
      expect(def.chatTemplate, isA<GenericChatTemplate>());
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
