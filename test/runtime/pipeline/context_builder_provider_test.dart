import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  test('systemPromptProvider provides default prompt', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final prompt = container.read(systemPromptProvider);
    expect(prompt, isNotEmpty);
    expect(prompt, contains('Sutra'));
  });

  test('systemPromptProvider state can be updated via notifier', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(systemPromptProvider.notifier);
    await notifier.update('New system prompt');
    final prompt = container.read(systemPromptProvider);
    expect(prompt, 'New system prompt');
  });
}
