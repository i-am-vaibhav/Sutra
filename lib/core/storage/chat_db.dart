import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ChatDB {
  static Database? _db;

  /// Close the database connection. Useful for testing or hot-restart.
  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  static Future<Database> instance() async {
    if (_db != null) return _db!;

    final path = join(await getDatabasesPath(), 'sutra.db');

    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sessions (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            updatedAt INTEGER NOT NULL,
            archived INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            sessionId TEXT NOT NULL,
            text TEXT NOT NULL,
            role TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            quotedText TEXT,
            citations TEXT,
            isWebSearch INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (sessionId) REFERENCES sessions(id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_messages_session ON messages(sessionId, createdAt)',
        );

        await db.execute('''
          CREATE TABLE memories (
            id TEXT PRIMARY KEY,
            content TEXT NOT NULL,
            importance REAL NOT NULL DEFAULT 0.5,
            createdAt INTEGER NOT NULL,
            session_id TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("ALTER TABLE memories ADD COLUMN session_id TEXT");
        }
      },
    );

    return _db!;
  }
}
