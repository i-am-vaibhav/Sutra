import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_test;
import 'package:sutra/runtime/models/model_catalog_service.dart';
import 'package:sutra/runtime/models/model_catalog.dart';

String _mockCatalogJson() {
  return jsonEncode({
    'categories': [
      {
        'name': 'Test',
        'icon': 'test',
        'description': 'Test models',
        'entries': [
          {
            'id': 'test-model',
            'name': 'Test Model 1B',
            'description': 'A test model',
            'category': 'test',
            'downloadUrl': 'https://example.com/model.gguf',
            'localPath': 'test.gguf',
            'contextLength': 2048,
            'chatTemplate': 'qwen',
          }
        ]
      }
    ]
  });
}

void main() {
  group('ModelCatalogService getCatalog HTTP paths', () {
    test('parses remote JSON catalog on HTTP 200', () async {
      final mockClient = http_test.MockClient((request) async {
        return http.Response(_mockCatalogJson(), 200);
      });

      final svc = ModelCatalogService(client: mockClient);
      final result = await svc.getCatalog();
      expect(result.allEntries.length, 1);
      expect(result.allEntries.first.id, 'test-model');
      expect(result.allEntries.first.name, 'Test Model 1B');
    });

    test('uses fallback when HTTP returns non-200', () async {
      final mockClient = http_test.MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final svc = ModelCatalogService(client: mockClient);
      final catalog = await svc.getCatalog();
      expect(catalog.allEntries, isNotEmpty);
      expect(catalog.allEntries.length, 13);
    });

    test('uses fallback when network throws', () async {
      final mockClient = http_test.MockClient((request) async {
        throw Exception('network error');
      });

      final svc = ModelCatalogService(client: mockClient);
      final catalog = await svc.getCatalog();
      expect(catalog.allEntries, isNotEmpty);
    });

    test('caches and returns same catalog on second call', () async {
      int callCount = 0;
      final mockClient = http_test.MockClient((request) async {
        callCount++;
        return http.Response(_mockCatalogJson(), 200);
      });

      final svc = ModelCatalogService(client: mockClient);
      final c1 = await svc.getCatalog();
      final c2 = await svc.getCatalog();
      expect(identical(c1, c2), true);
      expect(callCount, 1);
    });

    test('catalog getter returns fallback before getCatalog is called', () {
      final svc = ModelCatalogService();
      expect(svc.catalog.allEntries, isNotEmpty);
    });
  });
}
