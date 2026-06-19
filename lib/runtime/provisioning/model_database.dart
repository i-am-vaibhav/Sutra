import 'package:sqflite/sqflite.dart';

/// Lifecycle states for a model.
enum ModelState {
  notDownloaded,
  downloading,
  paused,
  downloaded,
  failed,
  deleted,
}

/// Persistent record for a model tracked in SQLite.
class ModelRecord {
  final String id;
  final String name;
  final String version;
  final ModelState state;
  final String localPath;
  final String downloadUrl;
  final String? expectedChecksum;
  final int? fileSizeBytes;
  final int downloadedBytes;
  final double progress;
  final int retryAttempts;
  final String? errorMessage;
  final String? downloadTaskId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ModelRecord({
    required this.id,
    required this.name,
    required this.version,
    required this.state,
    required this.localPath,
    required this.downloadUrl,
    this.expectedChecksum,
    this.fileSizeBytes,
    this.downloadedBytes = 0,
    this.progress = 0.0,
    this.retryAttempts = 0,
    this.errorMessage,
    this.downloadTaskId,
    required this.createdAt,
    required this.updatedAt,
  });

  ModelRecord copyWith({
    ModelState? state,
    int? downloadedBytes,
    double? progress,
    int? retryAttempts,
    String? errorMessage,
    String? downloadTaskId,
    int? fileSizeBytes,
  }) {
    return ModelRecord(
      id: id,
      name: name,
      version: version,
      state: state ?? this.state,
      localPath: localPath,
      downloadUrl: downloadUrl,
      expectedChecksum: expectedChecksum,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      progress: progress ?? this.progress,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      errorMessage: errorMessage,
      downloadTaskId: downloadTaskId ?? this.downloadTaskId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'version': version,
        'state': state.name,
        'local_path': localPath,
        'download_url': downloadUrl,
        'expected_checksum': expectedChecksum,
        'file_size_bytes': fileSizeBytes,
        'downloaded_bytes': downloadedBytes,
        'progress': progress,
        'retry_attempts': retryAttempts,
        'error_message': errorMessage,
        'download_task_id': downloadTaskId,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory ModelRecord.fromMap(Map<String, dynamic> m) => ModelRecord(
        id: m['id'] as String,
        name: m['name'] as String,
        version: m['version'] as String? ?? '1.0.0',
        state: ModelState.values.firstWhere(
          (e) => e.name == m['state'],
          orElse: () => ModelState.notDownloaded,
        ),
        localPath: m['local_path'] as String,
        downloadUrl: m['download_url'] as String,
        expectedChecksum: m['expected_checksum'] as String?,
        fileSizeBytes: m['file_size_bytes'] as int?,
        downloadedBytes: m['downloaded_bytes'] as int? ?? 0,
        progress: (m['progress'] as num?)?.toDouble() ?? 0.0,
        retryAttempts: m['retry_attempts'] as int? ?? 0,
        errorMessage: m['error_message'] as String?,
        downloadTaskId: m['download_task_id'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(m['updated_at'] as int),
      );
}

/// SQLite-backed model database for persistent lifecycle tracking.
///
/// Replaces the old SharedPreferences-based ModelStore.
/// Use `ModelDatabase()` for production (singleton) or
/// `ModelDatabase.test()` for testing (fresh in-memory DB).
class ModelDatabase {
  static ModelDatabase? _instance;
  Database? _db;
  final String? _dbName;
  final Future<Database> Function()? _dbFactory;

  ModelDatabase._(this._dbName, [this._dbFactory]);

  /// Singleton instance for production use.
  factory ModelDatabase() => _instance ??= ModelDatabase._('models.db');

  // Create a fresh instance with a custom database for testing.
  // Pass a Future<Database> that returns an in-memory database.
  factory ModelDatabase.test(Future<Database> Function() dbFactory) =>
      ModelDatabase._(null, dbFactory);

  Future<Database> _getDb() async {
    if (_db != null) return _db!;

    if (_dbFactory != null) {
      _db = await _dbFactory();
    } else {
      _db = await openDatabase(
        _dbName!,
        version: 1,
        onCreate: (db, version) async {
          await _createTables(db);
        },
      );
    }
    return _db!;
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE models (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        version TEXT NOT NULL DEFAULT '1.0.0',
        state TEXT NOT NULL DEFAULT 'not_downloaded',
        local_path TEXT NOT NULL,
        download_url TEXT NOT NULL,
        expected_checksum TEXT,
        file_size_bytes INTEGER,
        downloaded_bytes INTEGER DEFAULT 0,
        progress REAL DEFAULT 0.0,
        retry_attempts INTEGER DEFAULT 0,
        error_message TEXT,
        download_task_id TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  // ── Read ──────────────────────────────────────────────

  Future<ModelRecord?> get(String id) async {
    final db = await _getDb();
    final rows = await db.query('models', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return ModelRecord.fromMap(rows.first);
  }

  Future<List<ModelRecord>> getAll() async {
    final db = await _getDb();
    final rows = await db.query('models', orderBy: 'updated_at DESC');
    return rows.map(ModelRecord.fromMap).toList();
  }

  Future<List<ModelRecord>> getByState(ModelState state) async {
    final db = await _getDb();
    final rows = await db.query(
      'models',
      where: 'state = ?',
      whereArgs: [state.name],
      orderBy: 'updated_at DESC',
    );
    return rows.map(ModelRecord.fromMap).toList();
  }

  Future<Set<String>> getInstalledIds() async {
    final db = await _getDb();
    final rows = await db.query(
      'models',
      columns: ['id'],
      where: 'state = ?',
      whereArgs: [ModelState.downloaded.name],
    );
    return rows.map((r) => r['id'] as String).toSet();
  }

  // ── Write ─────────────────────────────────────────────

  Future<void> upsert(ModelRecord record) async {
    final db = await _getDb();
    await db.insert(
      'models',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateState(String id, ModelState state) async {
    final db = await _getDb();
    await db.update(
      'models',
      {
        'state': state.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateProgress(String id, double progress, int downloadedBytes) async {
    final db = await _getDb();
    await db.update(
      'models',
      {
        'progress': progress,
        'downloaded_bytes': downloadedBytes,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateDownloadTask(String id, String? taskId) async {
    final db = await _getDb();
    await db.update(
      'models',
      {
        'download_task_id': taskId,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markFailed(String id, String? errorMessage) async {
    final db = await _getDb();
    await db.update(
      'models',
      {
        'state': ModelState.failed.name,
        'error_message': errorMessage,
        'download_task_id': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _getDb();
    await db.delete('models', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all rows (for testing / cleanup).
  Future<void> deleteAll() async {
    final db = await _getDb();
    await db.delete('models');
  }

  /// Get total size of all downloaded models in bytes.
  Future<int> totalDownloadedSize() async {
    final db = await _getDb();
    final result = await db.rawQuery(
      "SELECT SUM(file_size_bytes) as total FROM models WHERE state = 'downloaded' AND file_size_bytes IS NOT NULL",
    );
    return (result.first['total'] as int?) ?? 0;
  }

  /// Get count of models by state.
  Future<Map<ModelState, int>> countByState() async {
    final db = await _getDb();
    final rows = await db.rawQuery(
      'SELECT state, COUNT(*) as count FROM models GROUP BY state',
    );
    final result = <ModelState, int>{};
    for (final row in rows) {
      final state = ModelState.values.firstWhere(
        (e) => e.name == row['state'],
        orElse: () => ModelState.notDownloaded,
      );
      result[state] = row['count'] as int;
    }
    return result;
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
