import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:sutra/core/storage/chat_db.dart';

const _uuid = Uuid();

/// A lightweight conversation session.
class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool archived;
  final int messageCount;

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.archived = false,
    this.messageCount = 0,
  });

  ChatSession copyWith({String? title, bool? archived}) {
    return ChatSession(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      archived: archived ?? this.archived,
      messageCount: messageCount,
    );
  }
}

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatRepository {
  // ── Sessions ──────────────────────────────────────────────

  Future<ChatSession> createSession({String? title}) async {
    final db = await ChatDB.instance();
    final now = DateTime.now();
    final id = _uuid.v4();

    await db.insert('sessions', {
      'id': id,
      'title': title ?? 'New conversation',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    });

    return ChatSession(
      id: id,
      title: title ?? 'New conversation',
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<List<ChatSession>> getSessions({bool includeArchived = false}) async {
    final db = await ChatDB.instance();
    final where = includeArchived ? 'archived = 1' : 'archived = 0';
    final rows = await db.rawQuery(
      "SELECT s.*, (SELECT COUNT(*) FROM messages m WHERE m.sessionId = s.id) AS messageCount "
      "FROM sessions s WHERE $where ORDER BY updatedAt DESC",
    );

    return rows
        .map((r) => ChatSession(
              id: r['id'] as String,
              title: r['title'] as String,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['createdAt'] as int),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  r['updatedAt'] as int),
              archived: (r['archived'] as int) == 1,
              messageCount: r['messageCount'] as int,
            ))
        .toList();
  }

  Future<void> archiveSession(String sessionId) async {
    final db = await ChatDB.instance();
    await db.update(
      'sessions',
      {
        'archived': 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> unarchiveSession(String sessionId) async {
    final db = await ChatDB.instance();
    await db.update(
      'sessions',
      {
        'archived': 0,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> updateSessionTitle(String sessionId, String title) async {
    final db = await ChatDB.instance();
    await db.update(
      'sessions',
      {
        'title': title,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await ChatDB.instance();
    await db.delete('messages', where: 'sessionId = ?', whereArgs: [sessionId]);
    await db.delete('sessions', where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Restore a previously deleted session and its messages.
  Future<void> restoreSession(
    ChatSession session,
    List<Map<String, dynamic>> messages,
  ) async {
    final db = await ChatDB.instance();
    await db.insert('sessions', {
      'id': session.id,
      'title': session.title,
      'createdAt': session.createdAt.millisecondsSinceEpoch,
      'updatedAt': session.updatedAt.millisecondsSinceEpoch,
      'archived': session.archived ? 1 : 0,
    });
    for (final msg in messages) {
      await db.insert('messages', msg,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<void> touchSession(String sessionId) async {
    final db = await ChatDB.instance();
    await db.update(
      'sessions',
      {'updatedAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  // ── Messages ──────────────────────────────────────────────

  Future<void> saveMessage(Map<String, dynamic> msg) async {
    final db = await ChatDB.instance();
    await db.insert(
      'messages',
      msg,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Touch the parent session's updatedAt.
    final sessionId = msg['sessionId'] as String?;
    if (sessionId != null) {
      await touchSession(sessionId);
    }
  }

  /// Fetch all messages for a session (ordered oldest → newest).
  Future<List<Map<String, dynamic>>> getMessages(String sessionId) async {
    final db = await ChatDB.instance();
    return await db.query(
      'messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'createdAt ASC',
    );
  }

  /// Fetch the newest [limit] messages for a session.
  /// Returns them ordered oldest → newest (like [getMessages]).
  Future<List<Map<String, dynamic>>> getMessagesPaginated(
    String sessionId, {
    int limit = 50,
  }) async {
    final db = await ChatDB.instance();
    final rows = await db.query(
      'messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.reversed.toList();
  }

  /// Count total messages in a session.
  Future<int> countMessages(String sessionId) async {
    final db = await ChatDB.instance();
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM messages WHERE sessionId = ?',
      [sessionId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Fetch messages older than [beforeTimestamp] for a session.
  /// Returns them ordered oldest → newest, up to [limit] messages.
  Future<List<Map<String, dynamic>>> getMessagesBefore(
    String sessionId, {
    required int beforeTimestamp,
    int limit = 50,
  }) async {
    final db = await ChatDB.instance();
    final rows = await db.query(
      'messages',
      where: 'sessionId = ? AND createdAt < ?',
      whereArgs: [sessionId, beforeTimestamp],
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.reversed.toList();
  }

  Future<void> deleteMessage(String messageId) async {
    final db = await ChatDB.instance();
    await db.delete('messages', where: 'id = ?', whereArgs: [messageId]);
  }

  Future<void> clearSession(String sessionId) async {
    final db = await ChatDB.instance();
    await db.delete('messages', where: 'sessionId = ?', whereArgs: [sessionId]);
  }
}
