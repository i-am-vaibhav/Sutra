import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/llm/impl/llama_cpp_runtime.dart';
import 'package:sutra/runtime/llm/impl/llama_cpp/llama_cpp_engine.dart';

class _FailingEngine extends LlamaCppEngine {
  @override
  Future<bool> loadModel(String path) async => true;

  @override
  bool get isReady => true;

  @override
  Stream<String> generateStream(String prompt, {int maxTokens = 1024}) async* {
    throw Exception('mock stream error');
  }

  @override
  Future<void> dispose() async {
    // no-op
  }
}

class _SuccessfulEngine extends LlamaCppEngine {
  bool disposed = false;

  @override
  Future<bool> loadModel(String path) async => true;

  @override
  bool get isReady => true;

  @override
  Stream<String> generateStream(String prompt, {int maxTokens = 1024}) async* {
    yield 'token1';
    yield 'token2';
  }

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

void main() {
  group('LlamaCppRuntime error handling', () {
    test('generateStream catches engine errors and yields error message', () async {
      final runtime = LlamaCppRuntime(engine: _FailingEngine());
      await runtime.initialize('/path/to/model');
      final chunks = await runtime.generateStream('test').toList();
      expect(chunks.length, 1);
      expect(chunks.first, contains('Generation error'));
    });

    test('dispose delegates to engine', () async {
      final engine = _SuccessfulEngine();
      final runtime = LlamaCppRuntime(engine: engine);
      await runtime.initialize('/path/to/model');
      await runtime.dispose();
      expect(engine.disposed, true);
    });

    test('generateStream returns tokens from engine', () async {
      final runtime = LlamaCppRuntime(engine: _SuccessfulEngine());
      await runtime.initialize('/path/to/model');
      final chunks = await runtime.generateStream('test').toList();
      expect(chunks, ['token1', 'token2']);
    });
  });
}
