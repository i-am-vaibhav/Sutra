import 'dart:async';

import 'package:sutra/core/logging/log.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/runtime/pipeline/runtime_manager.dart';

/// Summarizes old conversation messages into a concise summary
/// when the chat history exceeds the context window budget.
///
/// Uses the on-device LLM for semantic compression, falling back
/// to simple truncation if the runtime is not available.
class ConversationSummarizer {
  const ConversationSummarizer();

  /// Summarize old messages to fit within the context budget.
  ///
  /// [messages] — full chat history including the new user message.
  /// [maxMessages] — maximum messages to keep in the final history.
  /// [maxChars] — maximum character budget for the history portion.
  /// [runtime] — optional LLM runtime for semantic summarization.
  ///
  /// Returns a condensed list of messages where old messages are
  /// replaced by a single summary message.
  Future<List<ChatMessage>> summarizeIfNeeded({
    required List<ChatMessage> messages,
    required int maxMessages,
    required int maxChars,
    RuntimeManager? runtime,
  }) async {
    // Check if summarization is needed.
    if (messages.length <= maxMessages && !_exceedsCharBudget(messages, maxChars)) {
      return messages;
    }

    // Split into: messages to summarize (old) + messages to keep (recent).
    final keepCount = (maxMessages * 0.6).ceil().clamp(4, maxMessages);
    final oldMessages = messages.sublist(0, messages.length - keepCount);
    final recentMessages = messages.sublist(messages.length - keepCount);

    // Build a transcript of old messages for the LLM.
    final transcript = oldMessages
        .where((m) => m.text.isNotEmpty)
        .map((m) => '${m.role == ChatRole.user ? 'User' : 'Assistant'}: ${m.text}')
        .join('\n');

    String summaryText;

    // Try LLM-based summarization first.
    if (runtime != null && runtime.isReady) {
      try {
        summaryText = await _summarizeWithLlm(transcript, runtime);
      } catch (e) {
        Log.w('[ConversationSummarizer] LLM summarization failed, using truncation: $e');
        summaryText = _truncateTranscript(transcript);
      }
    } else {
      // Fallback: simple truncation.
      summaryText = _truncateTranscript(transcript);
    }

    // Create a summary message to replace the old messages.
    final summaryMessage = ChatMessage(
      id: 'conv_summary_${DateTime.now().microsecondsSinceEpoch}',
      sessionId: recentMessages.first.sessionId,
      text: '[Conversation summary]\n$summaryText',
      role: ChatRole.assistant,
      createdAt: recentMessages.first.createdAt,
    );

    Log.d('[ConversationSummarizer] Summarized ${oldMessages.length} messages → '
        '${summaryText.length} chars summary, kept ${recentMessages.length} recent');

    return [summaryMessage, ...recentMessages];
  }

  /// Check if the message list exceeds the character budget.
  bool _exceedsCharBudget(List<ChatMessage> messages, int maxChars) {
    int totalChars = 0;
    for (final msg in messages) {
      totalChars += msg.text.length;
      if (totalChars > maxChars) return true;
    }
    return false;
  }

  /// Use the LLM to produce a concise summary of the conversation.
  Future<String> _summarizeWithLlm(String transcript, RuntimeManager runtime) async {
    final prompt = 'Summarize this conversation in 3-5 concise bullet points. '
        'Focus on key facts, decisions, and topics discussed. '
        'Output ONLY the summary lines, one per line, starting with "- ". '
        'No explanation or commentary.\n\n'
        'Conversation:\n$transcript';

    final buffer = StringBuffer();
    await for (final token in runtime.generateStream(prompt)) {
      buffer.write(token);
      if (buffer.length > 1000) break; // Safety cap.
    }

    final lines = buffer.toString()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.startsWith('- '))
        .toList();

    if (lines.isEmpty) return _truncateTranscript(transcript);
    return lines.join('\n');
  }

  /// Fallback: truncate the transcript to fit within a reasonable size.
  String _truncateTranscript(String transcript) {
    const maxLen = 800;
    if (transcript.length <= maxLen) return transcript;
    return '${transcript.substring(0, maxLen)}\n... [earlier messages truncated]';
  }
}
