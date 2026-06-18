import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/orchestration/context_builder.dart';
import 'package:sutra/runtime/orchestration/chat_template.dart';
import 'package:sutra/features/chat/models/chat_message.dart';

void main() {
  group('ContextBuilder.buildFullPrompt with all params', () {
    test('all params provided', () {
      final builder = ContextBuilder(chatTemplate: const QwenChatTemplate());
      final result = builder.buildFullPrompt(
        systemPrompt: 'You are Sutra',
        chatHistory: [
          ChatMessage(id: '1', sessionId: 's1', text: 'Old msg', role: ChatRole.user, createdAt: DateTime(2024)),
          ChatMessage(id: '2', sessionId: 's1', text: 'Old reply', role: ChatRole.assistant, createdAt: DateTime(2024)),
        ],
        userMessage: 'New question',
        memoryText: 'User likes cats',
        userProfileText: 'Name: John',
        documentContext: 'Doc: rules',
      );
      expect(result, contains('You are Sutra'));
      expect(result, contains('Name: John'));
      expect(result, contains('Doc: rules'));
      expect(result, contains('User likes cats'));
      expect(result, contains('New question'));
      expect(result, contains('Old msg'));
    });

    test('null optional params', () {
      final builder = ContextBuilder(chatTemplate: const GenericChatTemplate());
      final result = builder.buildFullPrompt(
        systemPrompt: 'sys',
        chatHistory: [],
        userMessage: 'Hi',
        memoryText: null,
        userProfileText: null,
        documentContext: null,
      );
      expect(result, contains('sys'));
      expect(result, contains('Hi'));
    });

    test('empty optional params', () {
      final builder = ContextBuilder(chatTemplate: const GenericChatTemplate());
      final result = builder.buildFullPrompt(
        systemPrompt: 'sys',
        chatHistory: [],
        userMessage: 'Hi',
        memoryText: '',
        userProfileText: '',
        documentContext: '',
      );
      expect(result, contains('sys'));
    });

    test('drops matching last user message from history', () {
      final builder = ContextBuilder(chatTemplate: const GenericChatTemplate());
      final history = [
        ChatMessage(id: '1', sessionId: 's1', text: 'prev', role: ChatRole.user, createdAt: DateTime(2024)),
        ChatMessage(id: '2', sessionId: 's1', text: 'exact', role: ChatRole.user, createdAt: DateTime(2024)),
      ];
      final result = builder.buildFullPrompt(
        systemPrompt: 'sys',
        chatHistory: history,
        userMessage: 'exact',
      );
      // The last message 'exact' should be dropped from history
      // but 'exact' still appears in [USER]: exact line (the current user message)
      // We check that the history only has 'prev' by looking for the format
      expect(result, contains('prev'));
      // The formatted output should have exactly one [USER]: exact (from the current message)
      final matches = '[USER]: exact'.allMatches(result).length;
      expect(matches, 1);
    });

    test('keeps non-matching last user message', () {
      final builder = ContextBuilder(chatTemplate: const GenericChatTemplate());
      final history = [
        ChatMessage(id: '1', sessionId: 's1', text: 'prev', role: ChatRole.user, createdAt: DateTime(2024)),
        ChatMessage(id: '2', sessionId: 's1', text: 'other', role: ChatRole.user, createdAt: DateTime(2024)),
      ];
      final result = builder.buildFullPrompt(
        systemPrompt: 'sys',
        chatHistory: history,
        userMessage: 'different',
      );
      expect(result, contains('[USER]: prev'));
      expect(result, contains('[USER]: other'));
    });

    test('with empty history and empty message', () {
      final builder = ContextBuilder(chatTemplate: const GenericChatTemplate());
      final result = builder.buildFullPrompt(
        systemPrompt: 'sys',
        chatHistory: [],
        userMessage: '',
      );
      expect(result, contains('sys'));
    });
  });

  group('ContextBuilder.build', () {
    test('handles single message', () {
      final builder = ContextBuilder();
      final msgs = [ChatMessage(id: '1', sessionId: 's1', text: 'Hello', role: ChatRole.user, createdAt: DateTime(2024))];
      expect(builder.build(msgs), contains('Hello'));
    });

    test('maxMessages=1 shows only last message', () {
      final builder = ContextBuilder(maxMessages: 1);
      final msgs = [
        ChatMessage(id: '1', sessionId: 's1', text: 'first', role: ChatRole.user, createdAt: DateTime(2024)),
        ChatMessage(id: '2', sessionId: 's1', text: 'last', role: ChatRole.user, createdAt: DateTime(2024)),
      ];
      final result = builder.build(msgs);
      expect(result, isNot(contains('first')));
      expect(result, contains('last'));
    });

    test('maxChars truncates long messages', () {
      final builder = ContextBuilder(maxChars: 20);
      final msgs = [
        ChatMessage(id: '1', sessionId: 's1', text: 'a' * 100, role: ChatRole.user, createdAt: DateTime(2024)),
        ChatMessage(id: '2', sessionId: 's1', text: 'b' * 100, role: ChatRole.user, createdAt: DateTime(2024)),
      ];
      final result = builder.build(msgs);
      expect(result.length, lessThan(200));
    });
  });
}
