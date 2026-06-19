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

/// Phi-3: uses system, user, assistant, and end tokens.
class Phi3ChatTemplate implements ChatTemplate {
  const Phi3ChatTemplate();
  @override
  String formatPrompt({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
    String? memoryText,
  }) {
    final b = StringBuffer();
    b.write('<|system|>\n$systemPrompt<|end|>\n');
    for (final msg in history) {
      final tag = msg.role.name == 'user' ? '<|user|>' : '<|assistant|>';
      b.write('$tag\n${msg.text}<|end|>\n');
    }
    b.write('<|user|>\n$userMessage<|end|>\n');
    b.write('<|assistant|>\n');
    return b.toString();
  }
}

/// Gemma 2: uses start_of_turn / end_of_turn tokens.
class GemmaChatTemplate implements ChatTemplate {
  const GemmaChatTemplate();
  @override
  String formatPrompt({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
    String? memoryText,
  }) {
    final b = StringBuffer();
    b.write('<start_of_turn>user\n');
    b.write(systemPrompt);
    if (memoryText != null && memoryText.isNotEmpty) {
      b.write('\nRelevant memory:\n$memoryText');
    }
    b.write('<end_of_turn>\n');
    for (final msg in history) {
      final tag = msg.role.name == 'user' ? 'user' : 'model';
      b.write('<start_of_turn>$tag\n${msg.text}<end_of_turn>\n');
    }
    b.write('<start_of_turn>user\n$userMessage<end_of_turn>\n');
    b.write('<start_of_turn>model\n');
    return b.toString();
  }
}

/// Llama 3.2: uses begin_of_text, start_header_id, eot_id tokens.
class Llama3ChatTemplate implements ChatTemplate {
  const Llama3ChatTemplate();
  @override
  String formatPrompt({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
    String? memoryText,
  }) {
    final b = StringBuffer();
    b.write('<|begin_of_text|>');
    b.write('<|start_header_id|>system<|end_header_id|>\n\n');
    b.write(systemPrompt);
    if (memoryText != null && memoryText.isNotEmpty) {
      b.write('\nRelevant memory:\n$memoryText');
    }
    b.write('<|eot_id|>');
    for (final msg in history) {
      final header = msg.role.name == 'user' ? 'user' : 'assistant';
      b.write('<|start_header_id|>$header<|end_header_id|>\n\n');
      b.write('${msg.text}<|eot_id|>');
    }
    b.write('<|start_header_id|>user<|end_header_id|>\n\n');
    b.write('$userMessage<|eot_id|>');
    b.write('<|start_header_id|>assistant<|end_header_id|>\n\n');
    return b.toString();
  }
}

/// Mistral / Ministral: uses <s>[INST] ... [/INST] format.
class MistralChatTemplate implements ChatTemplate {
  const MistralChatTemplate();
  @override
  String formatPrompt({
    required String systemPrompt,
    required List<ChatMessage> history,
    required String userMessage,
    String? memoryText,
  }) {
    final b = StringBuffer();
    b.write('<s>[INST] ');
    b.write(systemPrompt);
    if (memoryText != null && memoryText.isNotEmpty) {
      b.write('\nRelevant memory:\n$memoryText');
    }
    b.write('\n\n');
    for (int i = 0; i < history.length; i++) {
      final msg = history[i];
      if (msg.role.name == 'user') {
        b.write('${msg.text} [/INST] ');
      } else {
        b.write('${msg.text} </s><s>[INST] ');
      }
    }
    b.write('$userMessage [/INST] ');
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
