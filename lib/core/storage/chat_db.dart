import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ChatDB {
  static Database? _db;

  static Future<Database> instance() async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), 'sutra.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            sessionId TEXT,
            text TEXT,
            role TEXT,
            createdAt INTEGER
          )
        ''');
      },
    );

    return _db!;
  }
}