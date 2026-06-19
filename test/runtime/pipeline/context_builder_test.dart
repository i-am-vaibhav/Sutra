import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/pipeline/context_builder.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';
import 'package:sutra/features/chat/chat_message.dart';

void main() {
  group('ContextBuilder.build', () {
    test('returns empty string for empty messages', () {
      final builder = ContextBuilder();
      expect(builder.build([]), isEmpty);
    });

    test('formats messages with roles', () {
      final builder = ContextBuilder();
      final messages = [
        ChatMessage(id: '1', sessionId: 's1', text: 'Hi', role: ChatRole.user, createdAt: DateTime(2024)),
        ChatMessage(id: '2', sessionId: 's1', text: 'Hello', role: ChatRole.assistant, createdAt: DateTime(2024)),
      ];
      final result = builder.build(messages);
      expect(result, contains('[USER]: Hi'));
      expect(result, contains('[ASSISTANT]: Hello'));
    });

    test('truncates to maxMessages', () {
      final builder = ContextBuilder(maxMessages: 2);
      final messages = List.generate(5, (i) =>
        ChatMessage(id: i.toString(), sessionId: 's1', text: 'msg$i', role: ChatRole.user, createdAt: DateTime(2024)));
      final result = builder.build(messages);
      expect(result, isNot(contains('msg0')));
      expect(result, contains('msg4'));
    });
  });

  group('ContextBuilder.buildFullPrompt', () {
    test('builds prompt with system and user message', () {
      final builder = ContextBuilder(chatTemplate: const GenericChatTemplate());
      final result = builder.buildFullPrompt(
        systemPrompt: 'You are helpful',
        chatHistory: [],
        userMessage: 'Hi',
      );
      expect(result, contains('You are helpful'));
      expect(result, contains('Hi'));
    });

    test('includes memory text', () {
      final builder = ContextBuilder(chatTemplate: const GenericChatTemplate());
      final result = builder.buildFullPrompt(
        systemPrompt: 'sys',
        chatHistory: [],
        userMessage: 'Hi',
        memoryText: 'memory',
      );
      expect(result, contains('memory'));
    });

    test('includes user profile text', () {
      final builder = ContextBuilder(chatTemplate: const GenericChatTemplate());
      final result = builder.buildFullPrompt(
        systemPrompt: 'sys',
        chatHistory: [],
        userMessage: 'Hi',
        userProfileText: 'Name: John',
      );
      expect(result, contains('Name: John'));
    });


  });
}
