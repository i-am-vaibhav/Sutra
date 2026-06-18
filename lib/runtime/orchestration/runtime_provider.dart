import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/llm/impl/llama_cpp_runtime.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/models_provision/model_paths.dart';
import 'package:sutra/runtime/models_provision/model_store_provider.dart';
import 'package:sutra/runtime/orchestration/runtime_manager.dart';
import 'package:sutra/runtime/orchestration/selected_model_provider.dart';

/// Provides the active RuntimeManager.
///
/// Depends on [selectedModelIdProvider] — when the user picks a different
/// model (or a model finishes downloading), the runtime is re-created
/// with the new GGUF file.  Falls back to the first installed model if
/// no model is explicitly selected, or to a stub if none are installed.
final runtimeProvider = FutureProvider<RuntimeManager>((ref) async {
  final selectedId = ref.watch(selectedModelIdProvider);
  debugPrint('[runtimeProvider] selectedId=$selectedId');

  // If no model is explicitly selected, try the first installed one.
  String? modelId = selectedId;
  if (modelId == null) {
    final store = ref.read(modelStoreProvider);
    final installed = await store.loadInstalled();
    debugPrint('[runtimeProvider] No selection, installed=$installed');
    if (installed.isNotEmpty) {
      modelId = installed.first;
    }
  }

  if (modelId == null) {
    debugPrint('[runtimeProvider] No model available, returning stub runtime');
    return RuntimeManager(LlamaCppRuntime());
  }

  final model = ModelRegistry.all.firstWhere(
    (m) => m.id == modelId,
    orElse: () => ModelRegistry.all.first,
  );
  debugPrint('[runtimeProvider] Resolved model: ${model.name} (${model.localPath})');

  try {
    final file = await ModelPaths.fileFor(model.localPath);
    debugPrint('[runtimeProvider] Model path: ${file.path}');

    if (!await file.exists()) {
      debugPrint('[runtimeProvider] Model file NOT FOUND at ${file.path}');
      return RuntimeManager(LlamaCppRuntime());
    }
    debugPrint('[runtimeProvider] Model file exists (${await file.length()} bytes)');

    final runtime = LlamaCppRuntime();
    await runtime.initialize(file.path);
    debugPrint('[runtimeProvider] Runtime ready: ${runtime.isReady}');

    // Dispose the engine when this provider is invalidated
    // (e.g. when the user switches models).
    ref.onDispose(() async {
      debugPrint('[runtimeProvider] Disposing runtime for model: ${model.name}');
      await runtime.dispose();
    });

    return RuntimeManager(runtime);
  } catch (e, st) {
    debugPrint('[runtimeProvider] FAILED to load model "$modelId": $e');
    debugPrint('[runtimeProvider] Stack trace: $st');
    return RuntimeManager(LlamaCppRuntime());
  }
});
