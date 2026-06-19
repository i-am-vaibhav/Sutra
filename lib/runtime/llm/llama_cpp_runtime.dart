import 'dart:async';

import 'package:sutra/core/logging/log.dart';

import 'package:sutra/runtime/llm/llama_cpp_engine.dart';
import 'package:sutra/runtime/llm/llm_runtime.dart';

class LlamaCppRuntime implements LlmRuntime {
  final LlamaCppEngine _engine;

  bool _initialized = false;
  bool _modelLoaded = false;

  LlamaCppRuntime({LlamaCppEngine? engine})
      : _engine = engine ?? LlamaCppEngine();

  @override
  bool get isReady => _initialized && _modelLoaded;

  Future<void> initialize(String modelPath) async {
    Log.d('[LlamaCppRuntime] Initializing with: $modelPath');
    _initialized = true;
    _modelLoaded = await _engine.loadModel(modelPath);
    Log.d('[LlamaCppRuntime] Initialized: isReady=$isReady');
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    if (!_modelLoaded) {
      Log.d('[LlamaCppRuntime] generateStream called but model not loaded');
      yield '[No model loaded. Please select and download a model first.]';
      return;
    }

    Log.d('[LlamaCppRuntime] Starting streaming generation...');
    final sw = Stopwatch()..start();

    // llamadart handles context management internally — no
    // explicit resetContext() call needed between turns.

    try {
      await for (final token in _engine.generateStream(prompt, maxTokens: 1024)) {
        yield token;
      }
    } catch (e) {
      Log.e('[LlamaCppRuntime] Generation failed: $e');
      yield '[Generation error: $e]';
    }

    sw.stop();
    Log.d('[LlamaCppRuntime] Stream complete in ${sw.elapsedMilliseconds}ms');
  }

  /// Dispose the engine and free native resources.
  Future<void> dispose() async {
    await _engine.dispose();
  }
}
