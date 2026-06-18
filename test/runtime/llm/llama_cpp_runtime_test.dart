import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/llm/impl/llama_cpp/llama_cpp_engine.dart';
import 'package:sutra/runtime/llm/impl/llama_cpp_runtime.dart';

/// A lightweight mock engine for testing runtime logic without FFI.
class _MockLlamaCppEngine extends LlamaCppEngine {
  bool loadModelResult = true;
  bool loadModelCalled = false;
  String lastLoadedPath = '';
  bool resetContextCalled = false;

  /// Tokens to yield from generateStream.
  List<String> streamTokens = ['Hello', ' ', 'world'];

  @override
  Future<bool> loadModel(String path) async {
    loadModelCalled = true;
    lastLoadedPath = path;
    return loadModelResult;
  }

  @override
  Stream<String> generateStream(String prompt, {int maxTokens = 1024}) async* {
    for (final token in streamTokens) {
      yield token;
    }
  }

  @override
  bool get isReady => loadModelResult && loadModelCalled;
}

void main() {
  late _MockLlamaCppEngine mockEngine;
  late LlamaCppRuntime runtime;

  setUp(() {
    mockEngine = _MockLlamaCppEngine();
    runtime = LlamaCppRuntime(engine: mockEngine);
  });

  // ── isReady state ──────────────────────────────────────────────

  group('LlamaCppRuntime.isReady', () {
    test('is false before initialization', () {
      expect(runtime.isReady, false);
    });

    test('is true after successful model load', () async {
      mockEngine.loadModelResult = true;
      await runtime.initialize('/path/to/model.gguf');

      expect(runtime.isReady, true);
    });

    test('is false after failed model load', () async {
      mockEngine.loadModelResult = false;
      await runtime.initialize('/bad/path.gguf');

      expect(runtime.isReady, false);
    });
  });

  // ── generateStream ─────────────────────────────────────────────

  group('LlamaCppRuntime.generateStream', () {
    test('yields error message when no model loaded', () async {
      final chunks = await runtime.generateStream('Hello').toList();

      expect(chunks, hasLength(1));
      expect(chunks.first, contains('No model loaded'));
    });

    test('yields tokens one at a time via engine streaming', () async {
      mockEngine.streamTokens = ['A', 'B', 'C', 'D'];
      await runtime.initialize('/models/test.gguf');

      final chunks = await runtime.generateStream('prompt').toList();

      expect(chunks, ['A', 'B', 'C', 'D']);
    });

    test('stream completes normally', () async {
      mockEngine.streamTokens = ['Hello World'];
      await runtime.initialize('/models/test.gguf');

      final stopwatch = Stopwatch()..start();
      await runtime.generateStream('prompt').toList();
      stopwatch.stop();

      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(10000),
        reason: 'Stream generation should not hang.',
      );
    });
  });

  // ── Full lifecycle ─────────────────────────────────────────────

  group('LlamaCppRuntime lifecycle', () {
    test('full initialize -> generate cycle', () async {
      mockEngine.loadModelResult = true;
      mockEngine.streamTokens = ['response'];

      // Initialize
      await runtime.initialize('/models/test.gguf');
      expect(runtime.isReady, true);

      // Generate
      final chunks = await runtime.generateStream('Hello').toList();
      expect(chunks.join(), 'response');
    });

    test('can generate multiple times after initialization', () async {
      mockEngine.loadModelResult = true;
      await runtime.initialize('/models/test.gguf');

      // First generation
      mockEngine.streamTokens = ['first'];
      final chunks1 = await runtime.generateStream('a').toList();
      expect(chunks1.join(), 'first');

      // Second generation
      mockEngine.streamTokens = ['second'];
      final chunks2 = await runtime.generateStream('b').toList();
      expect(chunks2.join(), 'second');
    });

    test('stream tokens arrive incrementally (not all at once)', () async {
      mockEngine.streamTokens = ['one', ' ', 'two', ' ', 'three'];
      await runtime.initialize('/models/test.gguf');

      final received = <String>[];
      await for (final token in runtime.generateStream('prompt')) {
        received.add(token);
      }

      expect(received, ['one', ' ', 'two', ' ', 'three']);
    });

    test('empty response produces no chunks', () async {
      mockEngine.streamTokens = [];
      await runtime.initialize('/models/test.gguf');

      final chunks = await runtime.generateStream('prompt').toList();

      expect(chunks, isEmpty);
    });
  });

  // ── Constructor defaults ───────────────────────────────────────

  group('LlamaCppRuntime constructor', () {
    test('creates runtime with provided engine', () {
      final engine = _MockLlamaCppEngine();
      final r = LlamaCppRuntime(engine: engine);
      expect(r, isA<LlamaCppRuntime>());
    });

    test('creates runtime with default engine', () {
      final r = LlamaCppRuntime();
      expect(r, isA<LlamaCppRuntime>());
    });
  });
}
