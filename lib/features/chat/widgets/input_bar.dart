import 'package:flutter/material.dart';
import 'package:sutra/features/chat/chat_state.dart';
import 'package:sutra/runtime/search/web_search_provider.dart';

/// Chat input bar with text field and send button.
///
/// The stop button for generation/search is shown below the streaming
/// message in the chat area (handled by [MessageList]), not here.
///
/// **Button states:**
/// - Model loading / Search busy: text field disabled
/// - Idle / Generating: text field active, send enabled
class InputBar extends StatelessWidget {
  final ChatState chatState;
  final WebSearchState searchState;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final TextEditingController controller;
  final VoidCallback onSend;

  const InputBar({
    super.key,
    required this.chatState,
    required this.searchState,
    required this.colorScheme,
    required this.theme,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDisabled =
        chatState.isModelLoading || searchState.isBusy;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !isDisabled,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: chatState.isModelLoading
                          ? 'Preparing model…'
                          : searchState.isBusy
                              ? 'Searching the web…'
                              : 'Type a message…',
                      hintStyle: TextStyle(color: colorScheme.outline),
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (controller.text.trim().isNotEmpty) onSend();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // ── Right button: always send ──
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: isDisabled ? null : onSend,
                    icon: Icon(Icons.arrow_upward,
                        color: colorScheme.onPrimary, size: 22),
                    tooltip: 'Send',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
