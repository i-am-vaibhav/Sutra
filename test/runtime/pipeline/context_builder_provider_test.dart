import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/runtime/pipeline/context_builder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
