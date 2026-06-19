import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/features/chat/widgets/search_status_card.dart';
import 'package:sutra/features/chat/widgets/thinking_indicator.dart';

/// The main message bubble rendered inside a [SwipeToReplyWrapper].
/// Handles the visual presentation of user vs assistant messages,
/// quoted text, markdown rendering, streaming indicators, and citations.
class MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  final ColorScheme colorScheme;
  final bool isStreaming;
  final bool usePlainText;

  const MessageBubble({
    super.key,
    required this.msg,
    required this.colorScheme,
    required this.isStreaming,
    required this.usePlainText,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == ChatRole.user;

    // Render search status as an expandable card instead of a normal bubble.
    if (msg.isSearchStatus) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: SearchStatusCard(
            status: msg.searchStatus!,
            statusLabel: msg.text,
            searchResults: msg.searchResults ?? const [],
          ),
        ),
      );
    }

    return RepaintBoundary(
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 340),
          decoration: BoxDecoration(
            color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.quotedText != null && msg.quotedText!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(
                      left: BorderSide(
                        color: isUser ? colorScheme.onPrimary.withValues(alpha: 0.5) : colorScheme.primary.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                  ),
                  child: Text(
                    msg.quotedText!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isUser ? colorScheme.onPrimary.withValues(alpha: 0.8) : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      height: 1.3,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (isStreaming || usePlainText)
                ThinkingIndicator(colorScheme: colorScheme, isActive: usePlainText)
              else if (isUser)
                Text(msg.text, style: TextStyle(color: colorScheme.onPrimary, height: 1.4))
              else
                MarkdownBody(
                  data: msg.text,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4),
                    code: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      backgroundColor: colorScheme.surface,
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A widget that detects horizontal swipe gestures to trigger reply.
/// Shows a reply icon and translates the message container during the swipe.
class SwipeToReplyWrapper extends StatefulWidget {
  final ChatMessage msg;
  final ColorScheme colorScheme;
  final VoidCallback onReply;
  final Widget child;

  const SwipeToReplyWrapper({
    super.key,
    required this.msg,
    required this.colorScheme,
    required this.onReply,
    required this.child,
  });

  @override
  State<SwipeToReplyWrapper> createState() => _SwipeToReplyWrapperState();
}

class _SwipeToReplyWrapperState extends State<SwipeToReplyWrapper>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  static const _triggerThreshold = 80.0;
  static const _maxDrag = 120.0;
  static const _velocityThreshold = 500.0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _resetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
    _resetController.addListener(() {
      setState(() => _dragExtent = _resetAnimation.value);
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _resetDrag() {
    final current = _dragExtent;
    _resetAnimation = Tween<double>(begin: current, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
    _resetController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.msg.role == ChatRole.user;
    final swipeDirection = isUser ? -1.0 : 1.0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) => _resetController.stop(),
      onHorizontalDragUpdate: (details) {
        final delta = details.delta.dx * swipeDirection;
        if (delta <= 0 && _dragExtent == 0) return;
        setState(() {
          _dragExtent = (_dragExtent + delta).clamp(0.0, _maxDrag);
        });
      },
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        final swipeVelocity = velocity * swipeDirection;

        if (_dragExtent >= _triggerThreshold || swipeVelocity > _velocityThreshold) {
          HapticFeedback.mediumImpact();
          widget.onReply();
        }
        _resetDrag();
      },
      onHorizontalDragCancel: () => _resetDrag(),
      child: Stack(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (_dragExtent > 10)
            Opacity(
              opacity: (_dragExtent / _triggerThreshold).clamp(0.0, 1.0),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.reply,
                  size: 20,
                  color: widget.colorScheme.primary,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(isUser ? -_dragExtent : _dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
