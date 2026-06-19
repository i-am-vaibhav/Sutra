import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sutra/runtime/memory/memory_item.dart';
import 'package:sutra/runtime/memory/memory_extractor.dart';
import 'package:sutra/runtime/memory/memory_repository.dart';

void main() {
  // Initialize sqflite for FFI (desktop/testing).
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

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

  group('MemoryRepository (SQLite)', () {
    late MemoryRepository repo;
    late Database sharedDb;

    setUp(() async {
      // Create a fresh in-memory database for each test.
      sharedDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE memories (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                importance REAL NOT NULL DEFAULT 0.5,
                createdAt INTEGER NOT NULL
              )
            ''');
          },
        ),
      );
      repo = MemoryRepository(dbFactory: () => Future.value(sharedDb));
    });

    tearDown(() async {
      await sharedDb.close();
    });

    test('add stores item', () async {
      final item = MemoryItem(id: '1', content: 'test', createdAt: DateTime.now());
      await repo.add(item);
      final all = await repo.getAll();
      expect(all.length, 1);
    });

    test('getAll returns all items', () async {
      await repo.add(MemoryItem(id: '1', content: 'a', createdAt: DateTime.now()));
      await repo.add(MemoryItem(id: '2', content: 'b', createdAt: DateTime.now()));
      final all = await repo.getAll();
      expect(all.length, 2);
    });

    test('top returns items sorted by importance', () async {
      await repo.add(MemoryItem(id: '1', content: 'low', createdAt: DateTime.now(), importance: 0.3));
      await repo.add(MemoryItem(id: '2', content: 'high', createdAt: DateTime.now(), importance: 0.9));
      await repo.add(MemoryItem(id: '3', content: 'mid', createdAt: DateTime.now(), importance: 0.6));
      final top = await repo.top(limit: 2);
      expect(top.length, 2);
      expect(top[0].content, 'high');
      expect(top[1].content, 'mid');
    });

    test('top respects limit', () async {
      for (var i = 0; i < 5; i++) {
        await repo.add(MemoryItem(id: i.toString(), content: 'm$i', createdAt: DateTime.now(), importance: i * 0.2));
      }
      final top = await repo.top(limit: 3);
      expect(top.length, 3);
    });

    test('delete removes a memory', () async {
      await repo.add(MemoryItem(id: '1', content: 'keep', createdAt: DateTime.now()));
      await repo.add(MemoryItem(id: '2', content: 'remove', createdAt: DateTime.now()));
      await repo.delete('2');
      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.content, 'keep');
    });

    test('clear removes all memories', () async {
      await repo.add(MemoryItem(id: '1', content: 'a', createdAt: DateTime.now()));
      await repo.add(MemoryItem(id: '2', content: 'b', createdAt: DateTime.now()));
      await repo.clear();
      final all = await repo.getAll();
      expect(all, isEmpty);
    });
  });
}
