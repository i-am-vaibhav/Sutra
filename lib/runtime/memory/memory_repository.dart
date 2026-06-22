import 'package:sqflite/sqflite.dart';
import 'package:sutra/core/storage/chat_db.dart';
import 'package:sutra/runtime/memory/memory_item.dart';

class MemoryRepository {
  final Future<Database> Function()? _dbFactory;

  /// Production: uses ChatDB.instance(). Test: pass a custom factory.
  MemoryRepository({this._dbFactory});

  Future<Database> _getDb() async {
    if (_dbFactory != null) return _dbFactory();
    return ChatDB.instance();
  }

  /// Add a memory item, persisting it to SQLite.
  Future<void> add(MemoryItem item) async {
    final db = await _getDb();
    await db.insert(
      'memories',
      {
        'id': item.id,
        'content': item.content,
        'importance': item.importance,
        'createdAt': item.createdAt.millisecondsSinceEpoch,
        'session_id': item.sessionId,
      },
    );
  }

  /// Get all memories from SQLite, sorted by importance descending.
  Future<List<MemoryItem>> getAll() async {
    final db = await _getDb();
    final rows = await db.query('memories', orderBy: 'importance DESC');
    return rows.map(_fromRow).toList();
  }

  /// Get the top-N most important memories, optionally scoped to a session.
  Future<List<MemoryItem>> top({int limit = 10, String? sessionId}) async {
    final db = await _getDb();
    if (sessionId != null) {
      final rows = await db.query(
        'memories',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'importance DESC',
        limit: limit,
      );
      return rows.map(_fromRow).toList();
    }
    final rows = await db.query(
      'memories',
      orderBy: 'importance DESC',
      limit: limit,
    );
    return rows.map(_fromRow).toList();
  }

  /// Delete a memory by id.
  Future<void> delete(String id) async {
    final db = await _getDb();
    await db.delete('memories', where: 'id = ?', whereArgs: [id]);
  }

  /// Clear all memories.
  Future<void> clear() async {
    final db = await _getDb();
    await db.delete('memories');
  }

  static MemoryItem _fromRow(Map<String, dynamic> row) {
    return MemoryItem(
      id: row['id'] as String,
      content: row['content'] as String,
      importance: (row['importance'] as num).toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['createdAt'] as int),
      sessionId: row['session_id'] as String?,
    );
  }
}
