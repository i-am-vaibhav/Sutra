import 'package:sutra/core/logging/log.dart';
import 'package:sutra/core/storage/prefs_helper.dart';
import 'package:sutra/runtime/models/model_catalog_service.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_manager.dart';

/// Result of a model update check.
class ModelUpdateResult {
  /// Models that have a newer version available in the remote catalog.
  final List<ModelUpdate> availableUpdates;

  /// New models discovered in the remote catalog not present locally.
  final List<String> newModelIds;

  /// Whether the check succeeded (vs falling back to cached data).
  final bool fromRemote;

  /// When this check was performed.
  final DateTime checkedAt;

  const ModelUpdateResult({
    this.availableUpdates = const [],
    this.newModelIds = const [],
    this.fromRemote = false,
    required this.checkedAt,
  });

  bool get hasUpdates => availableUpdates.isNotEmpty || newModelIds.isNotEmpty;
}

/// Describes a single model update.
class ModelUpdate {
  final String modelId;
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;

  const ModelUpdate({
    required this.modelId,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
  });
}

/// Background service that periodically checks for model updates.
///
/// On each check, it fetches the remote catalog from GitHub and compares
/// model versions against what's installed in the local database. If a
/// newer version is found for an installed model, it queues an auto-download
/// via [ModelManager].
///
/// Checks run at most once every 24 hours. The timestamp of the last
/// successful check is persisted in SharedPreferences.
class ModelUpdateService {
  static const _lastCheckKey = 'model_update_last_check';
  static const _checkInterval = Duration(hours: 24);

  final ModelCatalogService _catalogService;
  final ModelManager _manager;
  final ModelDatabase _db;

  ModelUpdateService({
    required ModelCatalogService catalogService,
    required ModelManager manager,
    ModelDatabase? database,
  })  : _catalogService = catalogService,
        _manager = manager,
        _db = database ?? ModelDatabase();

  /// Whether enough time has elapsed since the last check.
  Future<bool> get shouldCheck async {
    final prefs = await prefsCache();
    final lastCheckMs = prefs.getInt(_lastCheckKey);
    if (lastCheckMs == null) return true;
    final lastCheck = DateTime.fromMillisecondsSinceEpoch(lastCheckMs);
    return DateTime.now().difference(lastCheck) >= _checkInterval;
  }

  /// Run a background update check.
  ///
  /// Returns a [ModelUpdateResult] describing what was found. If the remote
  /// catalog fetch fails, the result will have `fromRemote: false` and no
  /// updates reported.
  ///
  /// Discovered updates for *installed* models are automatically queued for
  /// download. New models (not yet in the database) are left for the user
  /// to discover in the catalog UI.
  Future<ModelUpdateResult> checkForUpdates() async {
    Log.d('[ModelUpdateService] Starting update check');

    try {
      final catalog = await _catalogService.getCatalog();
      final allRecords = await _db.getAll();

      // Build a map of local records by ID for fast lookup.
      final localById = <String, ModelRecord>{};
      for (final r in allRecords) {
        localById[r.id] = r;
      }

      final updates = <ModelUpdate>[];
      final newModels = <String>[];

      for (final entry in catalog.allEntries) {
        final local = localById[entry.id];

        if (local == null) {
          // Model exists in remote catalog but not in local DB.
          // Only count it if the URL differs from any existing model
          // (avoids counting catalog aliases like "qwen3.5-4b-search"
          // that share the same file as "qwen3.5-4b").
          final isAlias = allRecords.any((r) => r.downloadUrl == entry.downloadUrl);
          if (!isAlias) {
            newModels.add(entry.id);
          }
          continue;
        }

        // Compare download URLs — a changed URL signals a new version.
        if (entry.downloadUrl != local.downloadUrl) {
          updates.add(ModelUpdate(
            modelId: entry.id,
            currentVersion: local.version,
            latestVersion: 'latest',
            downloadUrl: entry.downloadUrl,
          ));
        }
      }

      final result = ModelUpdateResult(
        availableUpdates: updates,
        newModelIds: newModels,
        fromRemote: true,
        checkedAt: DateTime.now(),
      );

      // Persist the check timestamp.
      final prefs = await prefsCache();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);

      // Auto-queue downloads for models that have URL-based updates and are
      // currently installed (user already has the old version).
      for (final update in updates) {
        final local = localById[update.modelId];
        if (local != null && local.state == ModelState.downloaded) {
          Log.d('[ModelUpdateService] Queuing update for ${update.modelId}: '
              '${local.downloadUrl} → ${update.downloadUrl}');
          // Look up the correct model definition from the registry,
          // falling back to reasonable defaults if not found.
          ModelDefinition? registryDef;
          for (final d in ModelRegistry.all) {
            if (d.id == update.modelId) {
              registryDef = d;
              break;
            }
          }
          final def = ModelDefinition(
            id: update.modelId,
            name: local.name,
            size: registryDef?.size ?? ModelSize.medium,
            contextLength: registryDef?.contextLength ?? 8192,
            downloadUrl: update.downloadUrl,
            localPath: local.localPath,
            chatTemplate: registryDef?.chatTemplate ?? const GenericChatTemplate(),
            capabilities: registryDef?.capabilities ?? const {},
            fileSizeBytes: registryDef?.fileSizeBytes,
          );
          await _manager.downloadModel(def);
        }
      }

      if (result.hasUpdates) {
        Log.d('[ModelUpdateService] Found ${updates.length} updates, '
            '${newModels.length} new models');
      } else {
        Log.d('[ModelUpdateService] All models up to date');
      }

      return result;
    } catch (e) {
      Log.w('[ModelUpdateService] Update check failed: $e');
      return ModelUpdateResult(
        fromRemote: false,
        checkedAt: DateTime.now(),
      );
    }
  }

  /// Reset the check timer (useful for testing or forcing an immediate re-check).
  Future<void> resetTimer() async {
    final prefs = await prefsCache();
    await prefs.remove(_lastCheckKey);
  }
}
