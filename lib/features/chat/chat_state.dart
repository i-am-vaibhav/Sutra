import 'package:sutra/features/chat/chat_message.dart';

/// Exposes [ChatState] which bundles messages + UI flags.
class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isModelLoading;
  final String? error;
  final String? activeSessionId;
  final int queuedCount;
  final String? pendingQuote;
  final String? pendingQuoteMessageId;
  final bool hasMoreMessages;
  final bool isLoadingOlder;
  final int totalMessageCount;

  const ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.isModelLoading = false,
    this.error,
    this.activeSessionId,
    this.queuedCount = 0,
    this.pendingQuote,
    this.pendingQuoteMessageId,
    this.hasMoreMessages = false,
    this.isLoadingOlder = false,
    this.totalMessageCount = 0,
  });

  bool get isBusy => isGenerating || isModelLoading;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    bool? isModelLoading,
    String? error,
    String? activeSessionId,
    bool clearError = false,
    bool clearSession = false,
    bool clearQuote = false,
    int? queuedCount,
    String? pendingQuote,
    String? pendingQuoteMessageId,
    bool? hasMoreMessages,
    bool? isLoadingOlder,
    int? totalMessageCount,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      isModelLoading: isModelLoading ?? this.isModelLoading,
      error: clearError ? null : (error ?? this.error),
      activeSessionId:
          clearSession ? null : (activeSessionId ?? this.activeSessionId),
      queuedCount: queuedCount ?? this.queuedCount,
      pendingQuote: clearQuote ? null : (pendingQuote ?? this.pendingQuote),
      pendingQuoteMessageId: clearQuote ? null : (pendingQuoteMessageId ?? this.pendingQuoteMessageId),
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      totalMessageCount: totalMessageCount ?? this.totalMessageCount,
    );
  }
}
