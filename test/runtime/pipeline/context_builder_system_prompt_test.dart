import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/runtime/pipeline/context_builder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SystemPromptNotifier', () {
    test('loads default prompt when no saved value', () async {
      final notifier = SystemPromptNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, 'You are Sutra, a helpful on-device AI assistant.');
    });

    test('loads saved prompt from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'system_prompt': 'Custom prompt',
      });
      final notifier = SystemPromptNotifier();
      await Future.delayed(Duration.zero);
      expect(notifier.state, 'Custom prompt');
    });

    test('update saves to SharedPreferences', () async {
      final notifier = SystemPromptNotifier();
      await Future.delayed(Duration.zero);
      await notifier.update('New prompt');
      expect(notifier.state, 'New prompt');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('system_prompt'), 'New prompt');
    });
  });
}
