import 'dart:async';

import 'package:sutra/core/logging/log.dart';
import 'package:llamadart/llamadart.dart';

/// Wraps [LlamaEngine] from the `llamadart` package.
///
/// Handles model loading, token streaming, and disposal.
/// llamadart manages isolates and threading internally — no manual
/// NativeCallable or cancel-flag plumbing needed.
class LlamaCppEngine {
  LlamaEngine? _engine;
  bool _modelLoaded = false;

  /// Whether a model is loaded and ready for generation.
  bool get isReady => _modelLoaded;

  /// Load a GGUF model from [path].
  ///
  /// Returns `true` on success, `false` on failure.
  Future<bool> loadModel(String path) async {
    Log.d('[LlamaCppEngine] Loading model: $path');
    final sw = Stopwatch()..start();
    try {
      final engine = LlamaEngine(LlamaBackend());
      await engine.loadModel(path);
      _engine = engine;
      _modelLoaded = true;
      sw.stop();
      Log.d('[LlamaCppEngine] Model loaded in ${sw.elapsedMilliseconds}ms');
      return true;
    } catch (e, st) {
      sw.stop();
      Log.d('[LlamaCppEngine] Model load FAILED in ${sw.elapsedMilliseconds}ms: $e\n$st');
      _modelLoaded = false;
      return false;
    }
  }

  /// Stream tokens from [prompt] via llamadart's streaming generation.
  ///
  /// Each yielded value is a token text chunk. The stream completes
  /// when generation finishes or [maxTokens] is reached.
  Stream<String> generateStream(String prompt, {int maxTokens = 1024}) async* {
    if (_engine == null || !_modelLoaded) {
      Log.d('[LlamaCppEngine] generateStream called but model not loaded');
      return;
    }

    Log.d('[LlamaCppEngine] Streaming generation (${prompt.length} chars prompt, maxTokens=$maxTokens)...');
    final sw = Stopwatch()..start();

    try {
      await for (final token in _engine!.generate(
        prompt,
        params: GenerationParams(maxTokens: maxTokens),
      )) {
        yield token;
      }
    } catch (e, st) {
      Log.e('[LlamaCppEngine] Stream generation FAILED: $e\n$st');
      yield '[Generation error: $e]';
    }

    sw.stop();
    Log.d('[LlamaCppEngine] Stream generation done in ${sw.elapsedMilliseconds}ms');
  }

  /// Free the loaded model and engine resources.
  Future<void> dispose() async {
    Log.d('[LlamaCppEngine] Disposing engine');
    if (_engine != null) {
      try {
        await _engine!.dispose();
      } catch (e) {
        Log.w('[LlamaCppEngine] Dispose error: $e');
      }
      _engine = null;
    }
    _modelLoaded = false;
  }
}
