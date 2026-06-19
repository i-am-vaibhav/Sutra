import 'package:sutra/core/logging/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/llm/llama_cpp_runtime.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_paths.dart';
import 'package:sutra/runtime/pipeline/runtime_manager.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';

/// Provides the active RuntimeManager.
///
/// Depends on [selectedModelIdProvider] — when the user picks a different
/// model (or a model finishes downloading), the runtime is re-created
/// with the new GGUF file.  Falls back to the first installed model if
/// no model is explicitly selected, or to a stub if none are installed.
final runtimeProvider = FutureProvider<RuntimeManager>((ref) async {
  final selectedId = ref.watch(selectedModelIdProvider);
  Log.d('[runtimeProvider] selectedId=$selectedId');

  // If no model is explicitly selected, try the first installed one.
  String? modelId = selectedId;
  if (modelId == null) {
    final db = ModelDatabase();
    final installed = await db.getInstalledIds();
    Log.d('[runtimeProvider] No selection, installed=$installed');
    if (installed.isNotEmpty) {
      modelId = installed.first;
    }
  }

  if (modelId == null) {
    Log.d('[runtimeProvider] No model available, returning stub runtime');
    return RuntimeManager(LlamaCppRuntime());
  }

  final model = ModelRegistry.all.firstWhere(
    (m) => m.id == modelId,
    orElse: () => ModelRegistry.all.first,
  );
  Log.d('[runtimeProvider] Resolved model: ${model.name} (${model.localPath})');

  // Create the runtime and register disposal BEFORE any async work
  // so that ref.onDispose is always called while ref is still valid.
  final runtime = LlamaCppRuntime();
  ref.onDispose(() {
    Log.d('[runtimeProvider] Disposing runtime for model: ${model.name}');
    runtime.dispose();
  });

  try {
    final file = await ModelPaths.fileFor(model.localPath);
    Log.d('[runtimeProvider] Model path: ${file.path}');

    if (!await file.exists()) {
      Log.d('[runtimeProvider] Model file NOT FOUND at ${file.path}');
      return RuntimeManager(LlamaCppRuntime());
    }
    Log.d('[runtimeProvider] Model file exists (${await file.length()} bytes)');

    // Check if the provider was disposed while we were loading files.
    if (!ref.mounted) return RuntimeManager(runtime);

    await runtime.initialize(file.path);
    Log.d('[runtimeProvider] Runtime ready: ${runtime.isReady}');

    return RuntimeManager(runtime);
  } catch (e, st) {
    Log.e('[runtimeProvider] FAILED to load model "$modelId": $e');
    Log.d('[runtimeProvider] Stack trace: $st');
    return RuntimeManager(runtime);
  }
});
