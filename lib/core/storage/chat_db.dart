import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ChatDB {
  static Database? _db;

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
            updatedAt INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            sessionId TEXT NOT NULL,
            text TEXT NOT NULL,
            role TEXT NOT NULL,
            createdAt INTEGER NOT NULL,
            FOREIGN KEY (sessionId) REFERENCES sessions(id) ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_messages_session ON messages(sessionId, createdAt)',
        );
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Migrate: create sessions table and add sessionId to existing messages.
          await db.execute('''
            CREATE TABLE sessions (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              createdAt INTEGER NOT NULL,
              updatedAt INTEGER NOT NULL
            )
          ''');

          // Check if sessionId column already exists.
          final columns = await db.rawQuery('PRAGMA table_info(messages)');
          final hasSessionId =
              columns.any((c) => c['name'] == 'sessionId');

          if (!hasSessionId) {
            await db.execute(
              'ALTER TABLE messages ADD COLUMN sessionId TEXT NOT NULL DEFAULT \'default\'',
            );
          }

          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(sessionId, createdAt)',
          );
        }
      },
    );

    return _db!;
  }
}
