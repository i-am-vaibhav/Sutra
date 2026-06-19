import 'dart:async';

import 'package:sutra/core/logging/log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_downloader.dart';
import 'package:sutra/runtime/provisioning/model_paths.dart';
import 'package:sutra/runtime/provisioning/model_queue.dart';

/// Snapshot of the model manager's current state for UI consumers.
class ModelManagerState {
  final Map<String, ModelState> modelStates;
  final Map<String, double> progress;
  final Map<String, int> retryAttempts;
  final String? activeDownloadId;
  final int totalDiskBytes;
  final Map<String, int> modelDiskBytes;
  final int freeDiskBytes;
  final String? storageWarning;
  final String? downloadCompleteMessage;

  const ModelManagerState({
    this.modelStates = const {},
    this.progress = const {},
    this.retryAttempts = const {},
    this.activeDownloadId,
    this.totalDiskBytes = 0,
    this.modelDiskBytes = const {},
    this.freeDiskBytes = 0,
    this.storageWarning,
    this.downloadCompleteMessage,
  });

  ModelManagerState copyWith({
    Map<String, ModelState>? modelStates,
    Map<String, double>? progress,
    Map<String, int>? retryAttempts,
    String? activeDownloadId,
    bool clearActiveDownload = false,
    int? totalDiskBytes,
    Map<String, int>? modelDiskBytes,
    int? freeDiskBytes,
    String? storageWarning,
    bool clearStorageWarning = false,
    String? downloadCompleteMessage,
    bool clearDownloadComplete = false,
  }) {
    return ModelManagerState(
      modelStates: modelStates ?? this.modelStates,
      progress: progress ?? this.progress,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      activeDownloadId:
          clearActiveDownload ? null : (activeDownloadId ?? this.activeDownloadId),
      totalDiskBytes: totalDiskBytes ?? this.totalDiskBytes,
      modelDiskBytes: modelDiskBytes ?? this.modelDiskBytes,
      freeDiskBytes: freeDiskBytes ?? this.freeDiskBytes,
      storageWarning:
          clearStorageWarning ? null : (storageWarning ?? this.storageWarning),
      downloadCompleteMessage:
          clearDownloadComplete ? null : (downloadCompleteMessage ?? this.downloadCompleteMessage),
    );
  }

  Set<String> get installedIds =>
      modelStates.entries.where((e) => e.value == ModelState.downloaded).map((e) => e.key).toSet();

  Set<String> get downloadingIds =>
      modelStates.entries.where((e) => e.value == ModelState.downloading).map((e) => e.key).toSet();

  Set<String> get failedIds =>
      modelStates.entries.where((e) => e.value == ModelState.failed).map((e) => e.key).toSet();
}

/// Central model manager responsible for the full lifecycle:
/// download, verify, install, cancel, delete, re-download.
///
/// Persists state to SQLite so it survives app restarts, reboots, and updates.
class ModelManager {
  final ModelDatabase _db;
  final ModelDownloader _downloader;
  final ModelQueue _queue = ModelQueue();
  final Map<String, ModelDefinition> _definitions = {};
  bool _activeDownload = false;

  // Cache free disk space to avoid repeated I/O on every state sync.
  int _cachedFreeDiskBytes = 0;
  DateTime _lastFreeDiskCheck = DateTime(0);

  ModelManagerState _state = const ModelManagerState();
  final _controller = StreamController<ModelManagerState>.broadcast();

  Stream<ModelManagerState> get stream => _controller.stream;
  ModelManagerState get state => _state;

  ModelManager({
    ModelDatabase? database,
    ModelDownloader? downloader,
  })  : _db = database ?? ModelDatabase(),
        _downloader = downloader ?? ModelDownloader();

  // ── Initialization ──────────────────────────────────────

  Future<void> init(List<ModelDefinition> allModels) async {
    for (final model in allModels) {
      _definitions[model.id] = model;
    }

    for (final model in allModels) {
      final existing = await _db.get(model.id);
      if (existing == null) {
        await _db.upsert(ModelRecord(
          id: model.id,
          name: model.name,
          version: model.version,
          state: ModelState.notDownloaded,
          localPath: model.localPath,
          downloadUrl: model.downloadUrl,
          expectedChecksum: model.expectedChecksum,
          fileSizeBytes: model.fileSizeBytes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      } else if (existing.state == ModelState.downloading) {
        await _db.upsert(existing.copyWith(
          state: ModelState.paused,
          downloadTaskId: null,
        ));
      }
    }

    // Detect files on disk downloaded while app was closed.
    for (final model in allModels) {
      final record = await _db.get(model.id);
      if (record != null &&
          record.state != ModelState.downloaded &&
          record.state != ModelState.deleted) {
        final file = await ModelPaths.fileFor(model.localPath);
        if (await file.exists()) {
          final fileSize = await file.length();
          await _db.upsert(record.copyWith(
            state: ModelState.downloaded,
            downloadedBytes: fileSize,
            progress: 1.0,
          ));
        }
      }
    }

    await _recoverInterruptedDownloads();
    await _syncStateFromDb();
  }

  /// Re-queue paused downloads for re-download (background_downloader
  /// doesn't support per-task resume after app restart).
  Future<void> _recoverInterruptedDownloads() async {
    final paused = await _db.getByState(ModelState.paused);
    for (final record in paused) {
      _queue.add(record.id);
    }
    if (_queue.isNotEmpty) _processQueue();
  }

  // ── Public API: Download ───────────────────────────────

  Future<void> provision(List<ModelDefinition> models) async {
    for (final model in models) {
      final record = await _db.get(model.id);
      if (record != null &&
          (record.state == ModelState.downloaded || record.state == ModelState.downloading)) {
        continue;
      }
      if (_queue.contains(model.id)) continue;
      _definitions[model.id] = model;

      if (record == null) {
        await _db.upsert(ModelRecord(
          id: model.id,
          name: model.name,
          version: model.version,
          state: ModelState.notDownloaded,
          localPath: model.localPath,
          downloadUrl: model.downloadUrl,
          expectedChecksum: model.expectedChecksum,
          fileSizeBytes: model.fileSizeBytes,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
      _queue.add(model.id);
    }
    await _syncStateFromDb();
    _processQueue();
  }

  Future<void> downloadModel(ModelDefinition model) async {
    _definitions[model.id] = model;
    var record = await _db.get(model.id);
    if (record == null) {
      record = ModelRecord(
        id: model.id,
        name: model.name,
        version: model.version,
        state: ModelState.notDownloaded,
        localPath: model.localPath,
        downloadUrl: model.downloadUrl,
        expectedChecksum: model.expectedChecksum,
        fileSizeBytes: model.fileSizeBytes,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await _db.upsert(record);
    }
    // Immediately mark as downloading so the UI shows queued/progress state.
    await _db.upsert(record.copyWith(
      state: ModelState.downloading,
      progress: 0.0,
    ));
    _queue.addFirst(model.id);
    await _syncStateFromDb();
    _processQueue();
  }

  /// Cancel an active download and reset state.
  Future<void> cancelDownload(String modelId) async {
    final record = await _db.get(modelId);
    if (record == null) return;
    if (record.downloadTaskId != null) {
      final def = _definitions[modelId];
      if (def != null) {
        await _downloader.cancelDownload(record.downloadTaskId!, def);
      }
    }
    _queue.remove(modelId);
    await _db.upsert(record.copyWith(
      state: ModelState.notDownloaded,
      downloadedBytes: 0,
      progress: 0.0,
      retryAttempts: 0,
      downloadTaskId: null,
    ));
    await _syncStateFromDb();
  }

  Future<void> retryDownload(String modelId) async {
    final record = await _db.get(modelId);
    if (record == null || record.state != ModelState.failed) return;
    await _db.upsert(record.copyWith(
      state: ModelState.notDownloaded,
      retryAttempts: 0,
      errorMessage: null,
    ));
    _queue.addFirst(modelId);
    await _syncStateFromDb();
    _processQueue();
  }

  // ── Public API: Delete ────────────────────────────────

  Future<void> deleteModel(String modelId) async {
    final record = await _db.get(modelId);
    if (record == null) return;
    if (record.state == ModelState.downloading && record.downloadTaskId != null) {
      final def = _definitions[modelId];
      if (def != null) {
        await _downloader.cancelDownload(record.downloadTaskId!, def);
      }
    }
    final def = _definitions[modelId];
    if (def != null) {
      await _downloader.deleteModel(def);
    }
    _queue.remove(modelId);
    await _db.upsert(record.copyWith(
      state: ModelState.deleted,
      downloadedBytes: 0,
      progress: 0.0,
      downloadTaskId: null,
    ));
    await _syncStateFromDb();
  }

  Future<void> redownloadModel(String modelId) async {
    final record = await _db.get(modelId);
    if (record == null || record.state != ModelState.deleted) return;
    await _db.upsert(record.copyWith(state: ModelState.notDownloaded));
    _queue.addFirst(modelId);
    await _syncStateFromDb();
    _processQueue();
  }

  // ── Public API: Queries ───────────────────────────────

  Future<int> getModelSize(String modelId) async {
    final def = _definitions[modelId];
    if (def == null) return 0;
    return _downloader.getFileSize(def);
  }

  Future<int> totalDiskUsage() async => _db.totalDownloadedSize();

  Future<bool> hasEnoughSpace(ModelDefinition model) async {
    try {
      final freeBytes = await ModelPaths.freeDiskSpace();
      if (freeBytes <= 0) return true;
      return freeBytes >= model.requiredDiskBytes;
    } catch (_) {
      Log.d('[ModelManager] Disk space check failed, allowing download');
      return true;
    }
  }

  Future<ModelRecord?> getModelRecord(String modelId) => _db.get(modelId);

  Future<bool> isWifiOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('wifi_only_downloads') ?? true;
  }

  Future<void> setWifiOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('wifi_only_downloads', value);
  }

  // ── Queue Processing ──────────────────────────────────

  void _processQueue() {
    if (_activeDownload) return;
    if (_queue.isEmpty) return;
    final nextId = _queue.next;
    if (nextId == null) return;
    final def = _definitions[nextId];
    if (def == null) {
      _queue.remove(nextId);
      _processQueue();
      return;
    }
    _activeDownload = true;
    _download(def).catchError((_) {}).whenComplete(() {
      _activeDownload = false;
      _processQueue();
    });
  }

  /// Clear the storage warning after it has been shown to the user.
  void clearStorageWarning() {
    _state = _state.copyWith(clearStorageWarning: true);
    if (!_controller.isClosed) _controller.add(_state);
  }

  /// Clear the download complete message after it has been shown to the user.
  void clearDownloadComplete() {
    _state = _state.copyWith(clearDownloadComplete: true);
    if (!_controller.isClosed) _controller.add(_state);
  }

  Future<void> _download(ModelDefinition model) async {
    final modelId = model.id;

    // ── Low-storage gate ────────────────────────────────
    if (!await hasEnoughSpace(model)) {
      final requiredMB = model.requiredDiskBytes ~/ (1024 * 1024);
      final warning = 'Not enough storage to download "${model.name}". '
          'Free at least $requiredMB MB and try again.';
      Log.d('[ModelManager] $warning');
      _queue.remove(modelId);
      final r = await _db.get(modelId);
      if (r != null) {
        await _db.upsert(r.copyWith(
          state: ModelState.failed,
          errorMessage: warning,
          downloadTaskId: null,
        ));
      }
      _state = _state.copyWith(
        storageWarning: warning,
      );
      if (!_controller.isClosed) _controller.add(_state);
      return;
    }

    final record = await _db.get(modelId);
    if (record != null) {
      await _db.upsert(record.copyWith(state: ModelState.downloading, progress: 0.0));
    }
    await _syncStateFromDb();

    final requireWifi = await isWifiOnly();

    try {
      await _downloader.download(
        model: model,
        requireWifi: requireWifi,
        onEvent: (event) async {
          if (event.completed) {
            _queue.remove(modelId);
            final name = model.name;
            await _syncStateFromDb();
            _state = _state.copyWith(downloadCompleteMessage: '$name is ready to use');
            if (!_controller.isClosed) _controller.add(_state);
            return;
          }
          if (event.error != null) {
            final r = await _db.get(modelId);
            if (r != null) {
              await _db.upsert(r.copyWith(retryAttempts: r.retryAttempts + 1));
            }
          } else {
            final r = await _db.get(modelId);
            if (r != null) {
              await _db.upsert(r.copyWith(
                progress: event.progress,
                downloadedBytes: event.downloadedBytes,
              ));
            }
          }
          await _syncStateFromDb();
        },
        database: _db,
      );
    } catch (e) {
      Log.e('[ModelManager] Download failed for $modelId: $e');
      _queue.remove(modelId);
      final r = await _db.get(modelId);
      if (r != null) {
        await _db.upsert(r.copyWith(
          state: ModelState.failed,
          errorMessage: e.toString(),
          downloadTaskId: null,
        ));
      }
      await _syncStateFromDb();
    }
  }

  // ── State Sync ────────────────────────────────────────

  Future<void> _syncStateFromDb() async {
    final records = await _db.getAll();
    final modelStates = <String, ModelState>{};
    final progress = <String, double>{};
    final retryAttempts = <String, int>{};
    final modelDiskBytes = <String, int>{};
    int totalDiskBytes = 0;

    for (final r in records) {
      modelStates[r.id] = r.state;
      if (r.state == ModelState.downloading || r.state == ModelState.paused) {
        progress[r.id] = r.progress;
      }
      if (r.retryAttempts > 0) retryAttempts[r.id] = r.retryAttempts;
      if (r.state == ModelState.downloaded && r.downloadedBytes > 0) {
        modelDiskBytes[r.id] = r.downloadedBytes;
        totalDiskBytes += r.downloadedBytes;
      }
    }

    int freeDisk = _cachedFreeDiskBytes;
    if (DateTime.now().difference(_lastFreeDiskCheck).inSeconds >= 30) {
      try {
        freeDisk = await ModelPaths.freeDiskSpace();
        _cachedFreeDiskBytes = freeDisk;
        _lastFreeDiskCheck = DateTime.now();
      } catch (_) {
        Log.d('[ModelManager] Free disk check failed during sync');
      }
    }

    _state = ModelManagerState(
      modelStates: modelStates,
      progress: progress,
      retryAttempts: retryAttempts,
      activeDownloadId: _activeDownload ? _queue.next : null,
      totalDiskBytes: totalDiskBytes,
      modelDiskBytes: modelDiskBytes,
      freeDiskBytes: freeDisk,
      storageWarning: _state.storageWarning,
    );
    if (!_controller.isClosed) _controller.add(_state);
  }

  void dispose() {
    _downloader.dispose();
    _controller.close();
  }
}
