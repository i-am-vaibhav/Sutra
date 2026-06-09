import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/models/model_definition.dart';

import 'model_downloader.dart';
import 'model_store.dart';
import 'model_queue.dart';
import 'model_provisioning_state.dart';
import 'model_downloader_provider.dart';
import 'model_store_provider.dart';

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

      unawaited(
        _download(model),
      );
    }
  }

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
    );

    queue.remove(modelId);

    final installed = {
      ..._state.installed,
      modelId,
    };

    final downloading = {
      ..._state.downloading,
    };

    downloading.remove(modelId);

    _state = _state.copyWith(
      installed: installed,
      downloading: downloading,
    );

    await store.saveInstalled(
      installed,
    );

    _emit();
  }

  void _emit() {
    _controller.add(_state);
  }
}