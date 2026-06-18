import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/orchestration/chat_template.dart';
import 'package:sutra/features/chat/models/chat_message.dart';

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

  group('TinyLlamaChatTemplate', () {
    test('formats with system/user/assistant tags', () {
      const t = TinyLlamaChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi');
      expect(result, contains('<|system|>'));
      expect(result, contains('</s>'));
      expect(result, contains('<|user|>'));
      expect(result, contains('<|assistant|>'));
    });
  });

  group('Phi3ChatTemplate', () {
    test('formats with end tokens', () {
      const t = Phi3ChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi');
      expect(result, contains('<|system|>'));
      expect(result, contains('<|end|>'));
      expect(result, contains('<|user|>'));
      expect(result, contains('<|assistant|>'));
    });
  });

  group('GemmaChatTemplate', () {
    test('formats with start_of_turn tokens', () {
      const t = GemmaChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi');
      expect(result, contains('<start_of_turn>user'));
      expect(result, contains('<end_of_turn>'));
      expect(result, contains('<start_of_turn>model'));
    });

    test('includes memory in system turn', () {
      const t = GemmaChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi', memoryText: 'memory');
      expect(result, contains('Relevant memory:'));
    });
  });

  group('Llama3ChatTemplate', () {
    test('formats with begin_of_text and header tokens', () {
      const t = Llama3ChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi');
      expect(result, contains('<|begin_of_text|>'));
      expect(result, contains('<|start_header_id|>system'));
      expect(result, contains('<|eot_id|>'));
    });

    test('includes memory in system prompt', () {
      const t = Llama3ChatTemplate();
      final result = t.formatPrompt(systemPrompt: 'sys', history: [], userMessage: 'Hi', memoryText: 'info');
      expect(result, contains('Relevant memory:'));
      expect(result, contains('info'));
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
