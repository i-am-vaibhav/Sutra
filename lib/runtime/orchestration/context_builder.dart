import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/features/chat/models/chat_message.dart';
import 'package:sutra/runtime/orchestration/chat_template.dart';

const _systemPromptKey = 'system_prompt';

final systemPromptProvider =
    StateNotifierProvider<SystemPromptNotifier, String>((ref) {
  return SystemPromptNotifier();
});

class SystemPromptNotifier extends StateNotifier<String> {
  SystemPromptNotifier() : super('You are Sutra, a helpful on-device AI assistant.') {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_systemPromptKey) ?? state;
  }

  Future<void> update(String value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_systemPromptKey, value);
  }
}

class ContextBuilder {
  final int maxMessages;
  final int maxChars;
  final ChatTemplate chatTemplate;

  ContextBuilder({
    this.maxMessages = 12,
    this.maxChars = 3000,
    this.chatTemplate = const GenericChatTemplate(),
  });

  String build(List<ChatMessage> messages) {
    final recent = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;
    final buffer = StringBuffer();
    int charCount = 0;
    for (final msg in recent) {
      final role = msg.role.name.toUpperCase();
      final line = '[$role]: ${msg.text}\n';
      if (charCount + line.length > maxChars) break;
      buffer.write(line);
      charCount += line.length;
    }
    return buffer.toString();
  }

  String buildFullPrompt({
    required String systemPrompt,
    required List<ChatMessage> chatHistory,
    required String userMessage,
    String? memoryText,
    String? userProfileText,
    String? documentContext,
  }) {
    // Drop the last message if it is the current user message
    // (it will be formatted by the template).
    final history = chatHistory.isNotEmpty &&
            chatHistory.last.role == ChatRole.user &&
            chatHistory.last.text == userMessage
        ? chatHistory.sublist(0, chatHistory.length - 1)
        : chatHistory;

    // Build an enriched system prompt with context features.
    final enrichedPrompt = StringBuffer(systemPrompt);
    if (userProfileText != null && userProfileText.isNotEmpty) {
      enrichedPrompt.write('\n\n$userProfileText');
    }
    if (documentContext != null && documentContext.isNotEmpty) {
      enrichedPrompt.write('\n\n$documentContext');
    }

    return chatTemplate.formatPrompt(
      systemPrompt: enrichedPrompt.toString(),
      history: history,
      userMessage: userMessage,
      memoryText: memoryText,
    );
  }
}
