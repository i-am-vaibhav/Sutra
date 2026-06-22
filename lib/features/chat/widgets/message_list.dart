import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sutra/app/theme/app_theme.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/features/chat/chat_state.dart';
import 'package:sutra/features/chat/widgets/citation_card.dart';
import 'package:sutra/features/chat/widgets/message_bubble.dart';
import 'package:sutra/features/chat/widgets/thinking_indicator.dart';
import 'package:sutra/runtime/settings/haptic_provider.dart';
import 'package:sutra/runtime/search/web_search_provider.dart';
import 'package:sutra/runtime/tts/tts_provider.dart';

/// Displays the scrollable list of chat messages with streaming indicators,
/// swipe-to-reply, message actions, and web search badges.
class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ChatState chatState;
  final WebSearchState searchState;
  final ScrollController scrollController;
  final ColorScheme colorScheme;
  final TtsState ttsState;
  final bool showScrollDown;
  final VoidCallback onScrollToBottom;
  final ValueChanged<ChatMessage> onReply;
  final void Function(ChatMessage) onLongPress;
  final void Function(String messageId, String text) onReadAloud;
  final VoidCallback onStopSpeaking;
  final VoidCallback onStop;
  final HapticIntensity hapticIntensity;

  const MessageList({
    super.key,
    required this.messages,
    required this.chatState,
    required this.searchState,
    required this.scrollController,
    required this.colorScheme,
    required this.ttsState,
    required this.showScrollDown,
    required this.onScrollToBottom,
    required this.onReply,
    required this.onLongPress,
    required this.onReadAloud,
    required this.onStopSpeaking,
    required this.onStop,
    this.hapticIntensity = HapticIntensity.light,
  });

  @override
  Widget build(BuildContext context) {
    // Precompute the index of the last assistant message once,
    // so only that message shows streaming indicators.
    final lastAssistantIndex =
        messages.lastIndexWhere((m) => m.role == ChatRole.assistant);

    return Stack(
      children: [
        ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: messages.length + (chatState.isLoadingOlder ? 1 : 0),
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            if (chatState.isLoadingOlder && index == 0) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            final msgIndex =
                chatState.isLoadingOlder ? index - 1 : index;
            final msg = messages[msgIndex];
            final isUser = msg.role == ChatRole.user;

            // Only the LAST assistant message should show streaming indicators.
            final isLastAssistant = !isUser && msgIndex == lastAssistantIndex;
            final isStreaming =
                chatState.isGenerating && isLastAssistant && msg.text.isEmpty;
            final usePlainText =
                chatState.isGenerating && isLastAssistant && msg.text.isNotEmpty;
            final showActions =
                !isUser && msg.text.isNotEmpty && !chatState.isGenerating;

            return KeyedSubtree(
              key: ValueKey(msg.id),
              child: SwipeToReplyWrapper(
                msg: msg,
                colorScheme: colorScheme,
                onReply: () => onReply(msg),
                hapticIntensity: hapticIntensity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: () => onLongPress(msg),
                      child: MessageBubble(
                        msg: msg,
                        colorScheme: colorScheme,
                        isStreaming: isStreaming,
                        usePlainText: usePlainText,
                      ),
                    ),
                    if (!isUser &&
                        msg.citations != null &&
                        msg.citations!.isNotEmpty)
                      CitationBar(citations: msg.citations!),
                    if (!isUser &&
                        isLastAssistant &&
                        (chatState.isGenerating || searchState.isBusy))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: GestureDetector(
                          onTap: onStop,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.stop, size: 14, color: colorScheme.onErrorContainer),
                                const SizedBox(width: 4),
                                Text(
                                  'Stop',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onErrorContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (showActions)
                      MessageActions(
                        message: msg,
                        colorScheme: colorScheme,
                        onCopy: () {
                          Clipboard.setData(ClipboardData(text: msg.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        onReadAloud: () => onReadAloud(msg.id, msg.text),
                        onStopReading: onStopSpeaking,
                        isSpeaking: ttsState.isSpeaking &&
                            ttsState.speakingMessageId == msg.id,
                      ),
                    if (msg.isWebSearch && !msg.isSearchStatus)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language,
                                size: 11, color: colorScheme.tertiary),
                            const SizedBox(width: 3),
                            Text(
                              'Web search',
                              style: AppTextStyles.labelSmall(context).copyWith(
                                fontSize: 10,
                                color: colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (showScrollDown)
          Positioned(
            bottom: 8,
            right: 8,
            child: FloatingActionButton.small(
              onPressed: onScrollToBottom,
              child: const Icon(Icons.arrow_downward),
            ),
          ),
      ],
    );
  }
}
