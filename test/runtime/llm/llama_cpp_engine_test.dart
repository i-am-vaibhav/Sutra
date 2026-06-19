import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/llm/llama_cpp_engine.dart';

void main() {
  group('LlamaCppEngine', () {
    test('isReady is false before model load', () {
      final engine = LlamaCppEngine();
      expect(engine.isReady, false);
    });

    test('loadModel returns false when path is invalid', () async {
      final engine = LlamaCppEngine();
      // Without a real native library, loadModel will fail gracefully.
      final result = await engine.loadModel('/nonexistent/model.gguf');
      expect(result, false);
      expect(engine.isReady, false);
    });

    test('generateStream yields error when no model loaded', () async {
      final engine = LlamaCppEngine();
      final tokens = await engine.generateStream('prompt').toList();
      // Should yield nothing since model is not loaded.
      expect(tokens, isEmpty);
    });

    test('dispose is safe to call multiple times', () async {
      final engine = LlamaCppEngine();
      await engine.dispose();
      await engine.dispose(); // should not throw
      expect(engine.isReady, false);
    });

    test('dispose is safe to call without loading a model', () async {
      final engine = LlamaCppEngine();
      await engine.dispose();
      expect(engine.isReady, false);
    });
  });
}
