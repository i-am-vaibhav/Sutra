import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sutra/core/feature_flags.dart';
import 'package:sutra/core/storage/prefs_helper.dart';
import 'package:sutra/runtime/llm/llm_runtime.dart';
import 'package:sutra/runtime/memory/memory_extractor.dart';
import 'package:sutra/runtime/pipeline/runtime_manager.dart';

/// Fake LlmRuntime for testing the feature flag gate.
class _FakeLlmRuntime extends LlmRuntime {
  final bool _isReady;
  final String _llmResponse;

  _FakeLlmRuntime({bool isReady = true, String llmResponse = ''})
      : _isReady = isReady,
        _llmResponse = llmResponse;

  @override
  bool get isReady => _isReady;

  @override
  Stream<String> generateStream(String prompt) async* {
    if (_llmResponse.isNotEmpty) {
      yield _llmResponse;
    }
  }
}

/// A runtime that throws during generation to test error handling.
class _ThrowingLlmRuntime extends LlmRuntime {
  @override
  bool get isReady => true;

  @override
  Stream<String> generateStream(String prompt) async* {
    throw Exception('LLM crashed');
  }
}

/// Helper to set feature flags in the mock prefs.
Future<void> _setFlag(FeatureFlag flag, bool value) async {
  final prefs = await prefsCache();
  await prefs.setBool('feature_flag_${flag.name}', value);
}

void main() {
  late MemoryExtractor extractor;

  setUp(() async {
    // Use the built-in in-memory async mock for SharedPreferencesWithCache.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // Reset so the next prefsCache() call creates a fresh instance.
    resetPrefsCache();
    extractor = MemoryExtractor();
  });

  tearDown(() {
    resetPrefsCache();
  });

  group('extractWithLLM — FeatureFlag.llmMemory gate', () {
    test('null runtime → falls back to regex extraction', () async {
      final items = await extractor.extractWithLLM(
        'I like cats very much',
        null,
      );

      // 'I like cats very much' is >20 chars AND contains 'like'
      // so regex extracts both a 'User said' and a 'Preference' item.
      expect(items.length, 2);
      expect(items.last.content, contains('Preference'));
      expect(items.last.importance, 0.9);
    });

    test('runtime not ready → falls back to regex extraction', () async {
      final runtime = RuntimeManager(
        _FakeLlmRuntime(isReady: false),
      );

      final items = await extractor.extractWithLLM(
        'This is a long message that should be extracted',
        runtime,
      );

      // Should use regex fallback (long message match).
      expect(items.length, 1);
      expect(items.first.content, contains('User said'));
    });

    test('flag OFF + ready runtime → still uses regex (v1 default)',
        () async {
      await _setFlag(FeatureFlag.llmMemory, false);

      final runtime = RuntimeManager(
        _FakeLlmRuntime(isReady: true),
      );

      final items = await extractor.extractWithLLM(
        'I prefer dark mode',
        runtime,
      );

      // Should use regex fallback, NOT LLM.
      expect(items.length, 1);
      expect(items.first.content, contains('Preference'));
      expect(items.first.importance, 0.9);
    });

    test('flag ON + ready runtime + valid JSON → uses LLM extraction',
        () async {
      await _setFlag(FeatureFlag.llmMemory, true);

      final llmJson =
          '[{"content": "User likes cats", "importance": 0.8}]';
      final runtime = RuntimeManager(
        _FakeLlmRuntime(isReady: true, llmResponse: llmJson),
      );

      final items = await extractor.extractWithLLM(
        'I like cats',
        runtime,
      );

      // Should use LLM extraction, not regex.
      expect(items.length, 1);
      expect(items.first.content, 'User likes cats');
      expect(items.first.importance, 0.8);
      expect(items.first.id, contains('_llm_'));
    });

    test('flag ON + ready runtime + invalid JSON → falls back to regex',
        () async {
      await _setFlag(FeatureFlag.llmMemory, true);

      final runtime = RuntimeManager(
        _FakeLlmRuntime(isReady: true, llmResponse: 'not valid json'),
      );

      final items = await extractor.extractWithLLM(
        'I like cats',
        runtime,
      );

      // Should fall back to regex since LLM returned garbage.
      expect(items.length, 1);
      expect(items.first.content, contains('Preference'));
    });

    test('flag ON + ready runtime + LLM throws → falls back to regex',
        () async {
      await _setFlag(FeatureFlag.llmMemory, true);

      final runtime = RuntimeManager(
        _ThrowingLlmRuntime(),
      );

      final items = await extractor.extractWithLLM(
        'I want coffee',
        runtime,
      );

      // Should fall back to regex.
      expect(items.length, 1);
      expect(items.first.content, contains('Preference'));
    });
  });
}
