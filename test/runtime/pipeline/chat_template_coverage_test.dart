import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';
import 'package:sutra/features/chat/chat_message.dart';

void main() {
  final history = [
    ChatMessage(id: '1', sessionId: 's1', text: 'Hi', role: ChatRole.user, createdAt: DateTime(2024)),
    ChatMessage(id: '2', sessionId: 's1', text: 'Hello!', role: ChatRole.assistant, createdAt: DateTime(2024)),
  ];

  group('Templates with memoryText', () {
    test('Qwen with memoryText', () {
      const t = QwenChatTemplate();
      final r = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi', memoryText: 'mem');
      expect(r, contains('mem'));
      expect(r, contains('Relevant memory:'));
    });

    test('Generic with memoryText', () {
      const t = GenericChatTemplate();
      final r = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi', memoryText: 'mem');
      expect(r, contains('MEMORY: mem'));
    });

    test('Generic with empty memoryText', () {
      const t = GenericChatTemplate();
      final r = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi', memoryText: '');
      expect(r, isNot(contains('MEMORY:')));
    });

    test('Qwen with empty memoryText', () {
      const t = QwenChatTemplate();
      final r = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi', memoryText: '');
      expect(r, isNot(contains('Relevant memory:')));
    });
  });

  group('Templates with history', () {
    test('Generic with history', () {
      const t = GenericChatTemplate();
      final r = t.formatPrompt(systemPrompt: 'sys', history: history, userMessage: 'Test');
      expect(r, contains('[USER]: Hi'));
      expect(r, contains('[ASSISTANT]: Hello!'));
    });
  });

  group('Templates without memory', () {
    test('Generic without memoryText', () {
      const t = GenericChatTemplate();
      final r = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi');
      expect(r, contains('SYSTEM: sys'));
    });
  });
}
