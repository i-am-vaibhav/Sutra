import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/context/context_settings.dart';

void main() {
  group('ContextSettings', () {
    test('defaults are correct', () {
      const s = ContextSettings();
      expect(s.userProfileEnabled, false);
      expect(s.conversationMemoryEnabled, true);
      expect(s.userName, isEmpty);
    });

    test('copyWith preserves fields', () {
      const s = ContextSettings(userName: 'John');
      final s2 = s.copyWith(userProfileEnabled: true);
      expect(s2.userName, 'John');
      expect(s2.userProfileEnabled, true);
    });

    test('buildUserProfilePrompt returns empty when disabled', () {
      const s = ContextSettings(userName: 'John');
      expect(s.buildUserProfilePrompt(), isEmpty);
    });

    test('buildUserProfilePrompt builds prompt when enabled', () {
      const s = ContextSettings(
        userProfileEnabled: true,
        userName: 'John',
        userProfession: 'Developer',
        userInterests: 'AI',
      );
      final prompt = s.buildUserProfilePrompt();
      expect(prompt, contains('Name: John'));
      expect(prompt, contains('Profession: Developer'));
      expect(prompt, contains('Interests: AI'));
    });

    test('buildUserProfilePrompt returns empty when enabled but no fields', () {
      const s = ContextSettings(userProfileEnabled: true);
      expect(s.buildUserProfilePrompt(), isEmpty);
    });

    test('includes userExtraInfo in profile', () {
      const s = ContextSettings(
        userProfileEnabled: true,
        userExtraInfo: 'Extra info here',
      );
      expect(s.buildUserProfilePrompt(), contains('Extra info here'));
    });
  });
}
