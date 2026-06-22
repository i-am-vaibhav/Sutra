import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';
import 'package:sutra/features/chat/chat_message.dart';

void main() {
  final history = [
    ChatMessage(id: '1', sessionId: 's1', text: 'Hi', role: ChatRole.user, createdAt: DateTime(2024)),
    ChatMessage(id: '2', sessionId: 's1', text: 'Hello!', role: ChatRole.assistant, createdAt: DateTime(2024)),
  ];

  group('QwenChatTemplate', () {
    test('formats prompt with system and user message', () {
      const t = QwenChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'You are helpful', history: [], userMessage: 'Hi');
      expect(result, contains('<|im_start|>system'));
      expect(result, contains('You are helpful'));
      expect(result, contains('<|im_start|>user'));
      expect(result, contains('<|im_start|>assistant'));
    });

    test('includes conversation history', () {
      const t = QwenChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: history, userMessage: 'Test');
      expect(result, contains('Hi'));
      expect(result, contains('Hello!'));
    });

    test('includes memory text when provided', () {
      const t = QwenChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Test', memoryText: 'User likes cats');
      expect(result, contains('Relevant memory:'));
      expect(result, contains('User likes cats'));
    });

    test('skips empty memory text', () {
      const t = QwenChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Test', memoryText: '');
      expect(result, isNot(contains('Relevant memory:')));
    });
  });

  group('GenericChatTemplate', () {
    test('formats with plain text tags', () {
      const t = GenericChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi');
      expect(result, contains('SYSTEM: sys'));
      expect(result, contains('[USER]: Hi'));
      expect(result, contains('[ASSISTANT]:'));
    });

    test('skips empty system prompt', () {
      const t = GenericChatTemplate();
      final result = t.formatPrompt(systemPrompt: '', history: [], userMessage: 'Hi');
      expect(result, isNot(contains('SYSTEM:')));
    });

    test('includes memory', () {
      const t = GenericChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi', memoryText: 'memory');
      expect(result, contains('MEMORY: memory'));
    });
  });
}
