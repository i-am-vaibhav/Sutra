import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models_provision/model_downloader.dart';
import 'package:sutra/runtime/models_provision/model_downloader_provider.dart';
import 'package:sutra/runtime/models_provision/model_provisioning_state.dart';
import 'package:sutra/runtime/models_provision/model_queue.dart';
import 'package:sutra/runtime/models_provision/model_store.dart';
import 'package:sutra/runtime/models_provision/model_store_provider.dart';

final modelProvisioningServiceProvider =
    Provider<ModelProvisioningService>((ref) {
  final downloader = ref.read(modelDownloaderProvider);
  final store = ref.read(modelStoreProvider);

  return ModelProvisioningService(
    downloader,
    store,
  );
});

class ModelProvisioningService {
  final ModelDownloader downloader;
  final ModelStore store;

  final ModelQueue queue = ModelQueue();

  /// Maps model IDs to their definitions for queued downloads.
  final Map<String, ModelDefinition> _pendingModels = {};

  /// Whether a download is currently in progress.
  bool _activeDownload = false;

  ModelProvisioningState _state =
      ModelProvisioningState.empty();

  final _controller =
      StreamController<ModelProvisioningState>.broadcast();

  Stream<ModelProvisioningState> get stream =>
      _controller.stream;

  ModelProvisioningService(
      this.downloader,
      this.store,
      );

  Future<void> init(
      Set<String> initialInstalled,
      ) async {
    _state = _state.copyWith(
      installed: initialInstalled,
    );

    _emit();
  }

  /// Enqueue models for sequential download.
  Future<void> provision(
      List<ModelDefinition> requiredModels,
      ) async {
    for (final model in requiredModels) {
      final modelId = model.id;

      if (_state.installed.contains(modelId)) {
        continue;
      }

      if (queue.contains(modelId)) {
        continue;
      }

      queue.add(modelId);
      _pendingModels[modelId] = model;
    }

    _processQueue();
  }

  /// Retry a previously-failed download.
  ///
  /// Clears the failure state, re-queues the model at the front
  /// of the download queue, and kicks off the next download.
  Future<void> retry(ModelDefinition model) async {
    final modelId = model.id;

    // Clear the failure state.
    final failed = {..._state.failed};
    failed.remove(modelId);
    final retryAttempts = {..._state.retryAttempts};
    retryAttempts.remove(modelId);

    _state = _state.copyWith(
      failed: failed,
      retryAttempts: retryAttempts,
    );

    _emit();

    // Remove stale entry (if any) then insert at the front.
    queue.remove(modelId);
    queue.addFirst(modelId);
    _pendingModels[modelId] = model;
    _processQueue();
  }

  // ── Sequential queue processor ──────────────────────────

  void _processQueue() {
    if (_activeDownload) return;
    if (queue.isEmpty) return;

    final nextId = queue.next;
    if (nextId == null) return;

    // Skip models that were installed while queued.
    if (_state.installed.contains(nextId)) {
      queue.remove(nextId);
      _pendingModels.remove(nextId);
      _processQueue();
      return;
    }

    final model = _pendingModels[nextId];
    if (model == null) {
      queue.remove(nextId);
      _processQueue();
      return;
    }

    _activeDownload = true;
    _download(model).catchError((_) {}).whenComplete(() {
      _activeDownload = false;
      _pendingModels.remove(nextId);
      _processQueue();
    });
  }

  // ── Single-model download ───────────────────────────────

  Future<void> _download(
      ModelDefinition model,
      ) async {
    final modelId = model.id;

    _state = _state.copyWith(
      downloading: {
        ..._state.downloading,
        modelId,
      },
    );

    _emit();

    try {
      await downloader.download(
        model: model,
        onProgress: (progress) {
          final updatedProgress = {
            ..._state.progress,
            modelId: progress,
          };

          _state = _state.copyWith(
            progress: updatedProgress,
          );

          _emit();
        },
        onRetry: (attempt) {
          final retryAttempts = {
            ..._state.retryAttempts,
            modelId: attempt,
          };

          _state = _state.copyWith(
            retryAttempts: retryAttempts,
          );

          _emit();
        },
      );

      // Success — mark installed.
      queue.remove(modelId);

      final installed = {
        ..._state.installed,
        modelId,
      };

      final downloading = {..._state.downloading};
      downloading.remove(modelId);

      final retryAttempts = {..._state.retryAttempts};
      retryAttempts.remove(modelId);

      _state = _state.copyWith(
        installed: installed,
        downloading: downloading,
        retryAttempts: retryAttempts,
      );

      await store.saveInstalled(installed);
      _emit();
    } catch (_) {
      // All retries exhausted — mark as failed.
      queue.remove(modelId);

      final downloading = {..._state.downloading};
      downloading.remove(modelId);

      final failed = {..._state.failed, modelId};
      final retryAttempts = {..._state.retryAttempts};
      retryAttempts.remove(modelId);

      _state = _state.copyWith(
        downloading: downloading,
        failed: failed,
        retryAttempts: retryAttempts,
      );

      _emit();
    }
  }

  void _emit() {
    _controller.add(_state);
  }
}
