import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:sutra/core/storage/prefs_helper.dart';
import 'package:sutra/runtime/pipeline/context_builder.dart';

void main() {
  setUp(() {
    resetPrefsCache();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    resetPrefsCache();
  });

  group('SystemPromptNotifier', () {
    test('loads default prompt when no saved value', () async {
      final notifier = SystemPromptNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, 'You are Sutra, a helpful on-device AI assistant.');
    });

    test('loads saved prompt from SharedPreferences', () async {
      final store = InMemorySharedPreferencesAsync.withData({
        'system_prompt': 'Custom prompt',
      });
      SharedPreferencesAsyncPlatform.instance = store;
      final notifier = SystemPromptNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, 'Custom prompt');
    });

    test('update saves to SharedPreferences', () async {
      final notifier = SystemPromptNotifier();
      await Future.delayed(Duration.zero);
      await notifier.update('New prompt');
      expect(notifier.state, 'New prompt');
      final prefs = await prefsCache();
      expect(prefs.getString('system_prompt'), 'New prompt');
    });
  });
}
