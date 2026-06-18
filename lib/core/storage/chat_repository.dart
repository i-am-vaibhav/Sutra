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

  const ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });
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

  Future<List<ChatSession>> getSessions() async {
    final db = await ChatDB.instance();
    final rows = await db.query('sessions', orderBy: 'updatedAt DESC');

    return rows
        .map((r) => ChatSession(
              id: r['id'] as String,
              title: r['title'] as String,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                  r['createdAt'] as int),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(
                  r['updatedAt'] as int),
            ))
        .toList();
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

  Future<List<Map<String, dynamic>>> getMessages(String sessionId) async {
    final db = await ChatDB.instance();
    return await db.query(
      'messages',
      where: 'sessionId = ?',
      whereArgs: [sessionId],
      orderBy: 'createdAt ASC',
    );
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
