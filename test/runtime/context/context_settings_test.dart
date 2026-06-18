import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/context/context_settings.dart';

void main() {
  group('ContextSettings', () {
    test('defaults are correct', () {
      const s = ContextSettings();
      expect(s.userProfileEnabled, false);
      expect(s.conversationMemoryEnabled, true);
      expect(s.documentIndexEnabled, false);
      expect(s.userName, isEmpty);
      expect(s.documents, isEmpty);
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

    test('buildDocumentContext returns empty when disabled', () {
      final s = ContextSettings(
        documents: [DocumentEntry(id: '1', title: 'Doc', content: 'content', createdAt: DateTime(2024))],
      );
      expect(s.buildDocumentContext(), isEmpty);
    });

    test('buildDocumentContext returns empty when no documents', () {
      const s = ContextSettings(documentIndexEnabled: true);
      expect(s.buildDocumentContext(), isEmpty);
    });

    test('buildDocumentContext builds context when enabled with docs', () {
      final s = ContextSettings(
        documentIndexEnabled: true,
        documents: [DocumentEntry(id: '1', title: 'Doc', content: 'content', createdAt: DateTime(2024))],
      );
      final ctx = s.buildDocumentContext();
      expect(ctx, contains('Doc'));
      expect(ctx, contains('content'));
    });

    test('includes userExtraInfo in profile', () {
      const s = ContextSettings(
        userProfileEnabled: true,
        userExtraInfo: 'Extra info here',
      );
      expect(s.buildUserProfilePrompt(), contains('Extra info here'));
    });
  });

  group('DocumentEntry', () {
    test('toJson and fromJson round trip', () {
      final doc = DocumentEntry(
        id: '1',
        title: 'Doc',
        content: 'Content',
        url: 'https://example.com',
        createdAt: DateTime(2024, 1, 1),
      );
      final json = doc.toJson();
      final doc2 = DocumentEntry.fromJson(json);
      expect(doc2.id, '1');
      expect(doc2.title, 'Doc');
      expect(doc2.content, 'Content');
      expect(doc2.url, 'https://example.com');
    });

    test('fromJson handles null url', () {
      final json = {
        'id': '1', 'title': 'Doc', 'content': 'Content',
        'url': null, 'createdAt': 0,
      };
      final doc = DocumentEntry.fromJson(json);
      expect(doc.url, isNull);
    });
  });
}
