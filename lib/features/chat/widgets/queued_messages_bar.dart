import 'package:flutter/material.dart';

/// Shows queued messages waiting to be sent, with pulse animation
/// for new items and slide-out animation for dismissed items.
class QueuedMessagesBar extends StatefulWidget {
  final List<String> queuedMessages;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final void Function(int index)? onDismiss;
  final VoidCallback? onClearAll;

  const QueuedMessagesBar({
    super.key,
    required this.queuedMessages,
    required this.colorScheme,
    required this.theme,
    this.onDismiss,
    this.onClearAll,
  });

  @override
  State<QueuedMessagesBar> createState() => _QueuedMessagesBarState();
}

class _QueuedMessagesBarState extends State<QueuedMessagesBar>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _prevCount = 0;

  /// Items that have been removed from the queue but are still
  /// animating out (slide-left + fade).
  final List<_QueuedExitItem> _exitingItems = [];

  @override
  void initState() {
    super.initState();
    _prevCount = widget.queuedMessages.length;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant QueuedMessagesBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.queuedMessages.length > _prevCount) {
      // New message queued — trigger a subtle pulse.
      _pulseController.forward(from: 0.0);
    } else if (widget.queuedMessages.length < _prevCount) {
      // Item(s) removed — animate them out.
      final previousSet = oldWidget.queuedMessages.toSet();
      final currentSet = widget.queuedMessages.toSet();
      for (final removed in previousSet.difference(currentSet)) {
        final preview =
            removed.length > 80 ? '${removed.substring(0, 80)}…' : removed;
        final controller = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        );
        _exitingItems.add(_QueuedExitItem(
          text: removed,
          preview: preview,
          controller: controller,
        ));
        controller.addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            if (mounted) {
              setState(() {
                _exitingItems
                    .removeWhere((e) => e.controller == controller);
              });
            }
            controller.dispose();
          }
        });
        controller.forward();
      }
    }
    _prevCount = widget.queuedMessages.length;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    for (final item in _exitingItems) {
      item.controller.dispose();
    }
    _exitingItems.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.queuedMessages.length;
    final colorScheme = widget.colorScheme;
    final theme = widget.theme;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Row(
                children: [
                  Icon(
                    Icons.queue,
                    size: 14,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$count queued message${count > 1 ? 's' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onClearAll != null)
                    GestureDetector(
                      onTap: widget.onClearAll,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.delete_sweep,
                            size: 13,
                            color: colorScheme.error.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Clear all',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.error.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Animate out items that were just removed from the queue.
            ..._exitingItems.map((item) {
              return FadeTransition(
                opacity: CurvedAnimation(
                  parent: item.controller,
                  curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                ),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: Offset.zero,
                    end: const Offset(-0.4, 0.0),
                  ).animate(CurvedAnimation(
                    parent: item.controller,
                    curve: Curves.easeIn,
                  )),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          margin: const EdgeInsets.only(right: 8, top: 1),
                          decoration: BoxDecoration(
                            color: widget.colorScheme.tertiaryContainer
                                .withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.check,
                            size: 10,
                            color: widget.colorScheme.onTertiaryContainer
                                .withValues(alpha: 0.6),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            item.preview,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: widget.theme.textTheme.bodySmall?.copyWith(
                              color: widget.colorScheme.onSurface
                                  .withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            ...widget.queuedMessages.asMap().entries.map((entry) {
              final i = entry.key;
              final text = entry.value;
              final preview =
                  text.length > 80 ? '${text.substring(0, 80)}…' : text;
              final isLatest = i == widget.queuedMessages.length - 1;
              return Dismissible(
                key: ValueKey('queued_$text'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  widget.onDismiss?.call(i);
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 12),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color:
                        colorScheme.errorContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.close,
                      size: 16, color: colorScheme.onErrorContainer),
                ),
                child: _QueuedItem(
                  index: i,
                  preview: preview,
                  colorScheme: colorScheme,
                  theme: theme,
                  animate: isLatest && _pulseController.isAnimating,
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _QueuedItem extends StatefulWidget {
  final int index;
  final String preview;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final bool animate;

  const _QueuedItem({
    required this.index,
    required this.preview,
    required this.colorScheme,
    required this.theme,
    this.animate = false,
  });

  @override
  State<_QueuedItem> createState() => _QueuedItemState();
}

class _QueuedItemState extends State<_QueuedItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.3, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    if (widget.animate) {
      _slideController.forward();
    } else {
      _slideController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant _QueuedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      _slideController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(right: 8, top: 1),
                decoration: BoxDecoration(
                  color: widget.colorScheme.tertiaryContainer,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index + 1}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: widget.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  widget.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: widget.theme.textTheme.bodySmall?.copyWith(
                    color: widget.colorScheme.onSurface.withValues(alpha: 0.7),
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

/// Data class for items animating out of the queue bar.
class _QueuedExitItem {
  final String text;
  final String preview;
  final AnimationController controller;

  _QueuedExitItem({
    required this.text,
    required this.preview,
    required this.controller,
  });
}
