import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/models/model_catalog.dart';
import 'package:sutra/runtime/models/model_catalog_entry.dart';

void main() {
  group('ModelCatalogEntry', () {
    test('constructor sets all fields', () {
      const entry = ModelCatalogEntry(
        id: 'test-id',
        name: 'Test Model',
        description: 'A test model',
        category: 'chat',
        downloadUrl: 'https://example.com/model.gguf',
        localPath: 'model.gguf',
        contextLength: 4096,
        sizeBytes: '1GB',
        chatTemplateHint: 'qwen',
      );
      expect(entry.id, 'test-id');
      expect(entry.name, 'Test Model');
      expect(entry.description, 'A test model');
      expect(entry.category, 'chat');
      expect(entry.downloadUrl, 'https://example.com/model.gguf');
      expect(entry.localPath, 'model.gguf');
      expect(entry.contextLength, 4096);
      expect(entry.sizeBytes, '1GB');
      expect(entry.chatTemplateHint, 'qwen');
    });

    test('defaults are applied', () {
      const entry = ModelCatalogEntry(
        id: 'test',
        name: 'Test',
        description: 'desc',
        category: 'chat',
        downloadUrl: 'https://example.com',
        localPath: 'test.gguf',
      );
      expect(entry.contextLength, 4096);
      expect(entry.sizeBytes, isNull);
      expect(entry.chatTemplateHint, 'generic');
    });

    group('fromJson', () {
      test('parses full JSON', () {
        final json = {
          'id': 'test-id',
          'name': 'Test Model',
          'description': 'A test model',
          'category': 'coding',
          'downloadUrl': 'https://example.com/model.gguf',
          'localPath': 'model.gguf',
          'contextLength': 8192,
          'sizeBytes': '2GB',
          'chatTemplate': 'llama3',
        };
        final entry = ModelCatalogEntry.fromJson(json);
        expect(entry.id, 'test-id');
        expect(entry.name, 'Test Model');
        expect(entry.description, 'A test model');
        expect(entry.category, 'coding');
        expect(entry.contextLength, 8192);
        expect(entry.sizeBytes, '2GB');
        expect(entry.chatTemplateHint, 'llama3');
      });

      test('handles missing optional fields', () {
        final json = {
          'id': 'test-id',
          'name': 'Test Model',
          'downloadUrl': 'https://example.com/model.gguf',
          'localPath': 'model.gguf',
        };
        final entry = ModelCatalogEntry.fromJson(json);
        expect(entry.description, '');
        expect(entry.category, 'general');
        expect(entry.contextLength, 4096);
        expect(entry.sizeBytes, isNull);
        expect(entry.chatTemplateHint, 'generic');
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        const entry = ModelCatalogEntry(
          id: 'test-id',
          name: 'Test Model',
          description: 'A test model',
          category: 'chat',
          downloadUrl: 'https://example.com/model.gguf',
          localPath: 'model.gguf',
          contextLength: 4096,
          sizeBytes: '1GB',
          chatTemplateHint: 'qwen',
        );
        final json = entry.toJson();
        expect(json['id'], 'test-id');
        expect(json['name'], 'Test Model');
        expect(json['description'], 'A test model');
        expect(json['category'], 'chat');
        expect(json['downloadUrl'], 'https://example.com/model.gguf');
        expect(json['localPath'], 'model.gguf');
        expect(json['contextLength'], 4096);
        expect(json['sizeBytes'], '1GB');
        expect(json['chatTemplate'], 'qwen');
      });
    });

    test('fromJson then toJson is identity', () {
      final original = {
        'id': 'round-trip',
        'name': 'Round Trip Model',
        'description': 'Tests round trip',
        'category': 'research',
        'downloadUrl': 'https://example.com/model.gguf',
        'localPath': 'model.gguf',
        'contextLength': 2048,
        'sizeBytes': '500MB',
        'chatTemplate': 'phi3',
      };
      final entry = ModelCatalogEntry.fromJson(original);
      final json = entry.toJson();
      expect(json['id'], original['id']);
      expect(json['name'], original['name']);
      expect(json['contextLength'], original['contextLength']);
    });
  });

  group('ModelCatalogCategory', () {
    test('constructor sets all fields', () {
      const category = ModelCatalogCategory(
        name: 'Chat',
        icon: 'chat',
        description: 'Chat models',
        entries: [],
      );
      expect(category.name, 'Chat');
      expect(category.icon, 'chat');
      expect(category.description, 'Chat models');
      expect(category.entries, isEmpty);
    });

    test('fromJson parses correctly', () {
      final json = {
        'name': 'Coding',
        'icon': 'code',
        'description': 'Code models',
        'entries': [
          {
            'id': 'code-model',
            'name': 'Code Model',
            'downloadUrl': 'https://example.com',
            'localPath': 'code.gguf',
          }
        ],
      };
      final category = ModelCatalogCategory.fromJson(json);
      expect(category.name, 'Coding');
      expect(category.entries.length, 1);
      expect(category.entries.first.id, 'code-model');
    });

    test('fromJson defaults icon and description', () {
      final json = {
        'name': 'Test',
        'entries': <dynamic>[],
      };
      final category = ModelCatalogCategory.fromJson(json);
      expect(category.icon, 'smart_toy');
      expect(category.description, '');
    });
  });

  group('ModelCatalog', () {
    test('fromJson parses categories', () {
      final json = {
        'categories': [
          {
            'name': 'Chat',
            'entries': [
              {
                'id': 'model-1',
                'name': 'Model 1',
                'downloadUrl': 'https://example.com',
                'localPath': 'm1.gguf',
              }
            ],
          },
        ],
      };
      final catalog = ModelCatalog.fromJson(json);
      expect(catalog.categories.length, 1);
      expect(catalog.categories.first.name, 'Chat');
    });

    test('allEntries flattens categories', () {
      final json = {
        'categories': [
          {
            'name': 'Cat1',
            'entries': [
              {'id': 'm1', 'name': 'M1', 'downloadUrl': 'https://a', 'localPath': 'a.gguf'},
              {'id': 'm2', 'name': 'M2', 'downloadUrl': 'https://b', 'localPath': 'b.gguf'},
            ],
          },
          {
            'name': 'Cat2',
            'entries': [
              {'id': 'm3', 'name': 'M3', 'downloadUrl': 'https://c', 'localPath': 'c.gguf'},
            ],
          },
        ],
      };
      final catalog = ModelCatalog.fromJson(json);
      expect(catalog.allEntries.length, 3);
      expect(catalog.allEntries.map((e) => e.id), containsAll(['m1', 'm2', 'm3']));
    });

    test('fallback catalog has categories', () {
      expect(ModelCatalog.fallback.categories, isNotEmpty);
    });

    test('fallback catalog has at least 3 categories', () {
      expect(ModelCatalog.fallback.categories.length, greaterThanOrEqualTo(3));
    });

    test('fallback catalog has entries in each category', () {
      for (final category in ModelCatalog.fallback.categories) {
        expect(category.entries, isNotEmpty, reason: '${category.name} should have entries');
      }
    });

    test('fallback catalog allEntries returns all entries', () {
      final all = ModelCatalog.fallback.allEntries;
      expect(all.length, greaterThanOrEqualTo(10));
    });

    test('each fallback entry has required fields', () {
      for (final entry in ModelCatalog.fallback.allEntries) {
        expect(entry.id, isNotEmpty);
        expect(entry.name, isNotEmpty);
        expect(entry.downloadUrl, isNotEmpty);
        expect(entry.localPath, isNotEmpty);
      }
    });
  });
}
