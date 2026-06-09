import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'chat_db.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

class ChatRepository {
  Future<void> saveMessage(Map<String, dynamic> msg) async {
    final db = await ChatDB.instance();

    await db.insert(
      'messages',
      msg,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getMessages() async {
    final db = await ChatDB.instance();

    return await db.query(
      'messages',
      orderBy: 'createdAt ASC',
    );
  }

  Future<void> clear() async {
    final db = await ChatDB.instance();
    await db.delete('messages');
  }
}