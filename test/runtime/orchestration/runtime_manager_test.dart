import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/llm/llm_runtime.dart';
import 'package:sutra/runtime/orchestration/runtime_manager.dart';

class _MockRuntime implements LlmRuntime {
  bool ready = false;
  @override
  bool get isReady => ready;
  @override
  Stream<String> generateStream(String prompt) async* {
    yield 'mock';
  }
}

void main() {
  group('RuntimeManager', () {
    test('delegates isReady to runtime', () {
      final mock = _MockRuntime();
      final mgr = RuntimeManager(mock);
      expect(mgr.isReady, false);
      mock.ready = true;
      expect(mgr.isReady, true);
    });

    test('delegates generateStream to runtime', () async {
      final mgr = RuntimeManager(_MockRuntime());
      final chunks = await mgr.generateStream('prompt').toList();
      expect(chunks, ['mock']);
    });
  });
}
