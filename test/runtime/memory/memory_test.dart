import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/memory/memory_item.dart';
import 'package:sutra/runtime/memory/memory_extractor.dart';
import 'package:sutra/runtime/memory/memory_repository.dart';

void main() {
  group('MemoryItem', () {
    test('constructor sets all fields', () {
      final item = MemoryItem(
        id: '1',
        content: 'Test content',
        createdAt: DateTime(2024),
        importance: 0.8,
      );
      expect(item.id, '1');
      expect(item.content, 'Test content');
      expect(item.importance, 0.8);
    });

    test('importance defaults to 0.5', () {
      final item = MemoryItem(id: '1', content: 'test', createdAt: DateTime.now());
      expect(item.importance, 0.5);
    });
  });

  group('MemoryExtractor', () {
    test('extracts long user messages', () {
      final extractor = MemoryExtractor();
      final items = extractor.extract('This is a long user message that exceeds 20 chars', '');
      expect(items.length, 1);
      expect(items.first.importance, 0.7);
    });

    test('extracts preference keywords', () {
      final extractor = MemoryExtractor();
      final items = extractor.extract('I like cats', '');
      expect(items.length, 1);
      expect(items.first.content, contains('Preference'));
      expect(items.first.importance, 0.9);
    });

    test('extracts prefer keyword', () {
      final extractor = MemoryExtractor();
      final items = extractor.extract('I prefer dark mode', '');
      expect(items.length, 1);
    });

    test('extracts want keyword', () {
      final extractor = MemoryExtractor();
      final items = extractor.extract('I want coffee', '');
      expect(items.length, 1);
    });

    test('returns empty for short messages without keywords', () {
      final extractor = MemoryExtractor();
      final items = extractor.extract('Hi', '');
      expect(items, isEmpty);
    });

    test('extracts both long message and preference', () {
      final extractor = MemoryExtractor();
      final items = extractor.extract('I really like chocolate very much', '');
      expect(items.length, 2);
    });
  });

  group('MemoryRepository', () {
    test('add stores item', () async {
      final repo = MemoryRepository();
      final item = MemoryItem(id: '1', content: 'test', createdAt: DateTime.now());
      await repo.add(item);
      expect(repo.getAll().length, 1);
    });

    test('getAll returns all items', () async {
      final repo = MemoryRepository();
      await repo.add(MemoryItem(id: '1', content: 'a', createdAt: DateTime.now()));
      await repo.add(MemoryItem(id: '2', content: 'b', createdAt: DateTime.now()));
      expect(repo.getAll().length, 2);
    });

    test('top returns items sorted by importance', () async {
      final repo = MemoryRepository();
      await repo.add(MemoryItem(id: '1', content: 'low', createdAt: DateTime.now(), importance: 0.3));
      await repo.add(MemoryItem(id: '2', content: 'high', createdAt: DateTime.now(), importance: 0.9));
      await repo.add(MemoryItem(id: '3', content: 'mid', createdAt: DateTime.now(), importance: 0.6));
      final top = repo.top(limit: 2);
      expect(top.length, 2);
      expect(top[0].content, 'high');
      expect(top[1].content, 'mid');
    });

    test('top respects limit', () async {
      final repo = MemoryRepository();
      for (var i = 0; i < 5; i++) {
        await repo.add(MemoryItem(id: i.toString(), content: 'm$i', createdAt: DateTime.now(), importance: i * 0.2));
      }
      expect(repo.top(limit: 3).length, 3);
    });
  });
}
