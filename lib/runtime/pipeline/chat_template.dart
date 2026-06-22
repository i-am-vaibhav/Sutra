import 'package:sutra/features/chat/chat_message.dart';

/// Strategy interface for model-specific chat prompt formatting.
abstract class ChatTemplate {
  String formatPrompt({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
    String? memoryText,
  });
}

/// Qwen 2.5: ChatML format with im_start/im_end tokens.
class QwenChatTemplate implements ChatTemplate {
  const QwenChatTemplate();
  @override
  String formatPrompt({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
    String? memoryText,
  }) {
    final b = StringBuffer();
    b.write('<|im_start|>system\n');
    b.write(systemPrompt);
    if (memoryText != null && memoryText.isNotEmpty) {
      b.write('\nRelevant memory:\n$memoryText');
    }
    b.write('<|im_end|>\n');
    for (final msg in history) {
      final role = msg.role.name == 'user' ? 'user' : 'assistant';
      b.write('<|im_start|>$role\n${msg.text}<|im_end|>\n');
    }
    b.write('<|im_start|>user\n$userMessage<|im_end|>\n');
    b.write('<|im_start|>assistant\n');
    return b.toString();
  }
}

/// Generic fallback: plain text format for unknown models.
class GenericChatTemplate implements ChatTemplate {
  const GenericChatTemplate();
  @override
  String formatPrompt({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
    String? memoryText,
  }) {
    final b = StringBuffer();
    if (systemPrompt.isNotEmpty) {
      b.writeln('SYSTEM: $systemPrompt');
      b.writeln();
    }
    if (memoryText != null && memoryText.isNotEmpty) {
      b.writeln('MEMORY: $memoryText');
      b.writeln();
    }
    for (final msg in history) {
      final role = msg.role.name.toUpperCase();
      b.writeln('[$role]: ${msg.text}');
    }
    b.write('[USER]: $userMessage\n');
    b.write('[ASSISTANT]: ');
    return b.toString();
  }
}
