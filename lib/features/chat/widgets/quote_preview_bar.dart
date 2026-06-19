import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/chat/chat_provider.dart';

/// Bar showing the pending quoted text above the input field.
class QuotePreviewBar extends ConsumerWidget {
  final ColorScheme colorScheme;
  const QuotePreviewBar({super.key, required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quote = ref.watch(chatProvider.select((s) => s.pendingQuote));
    if (quote == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              quote,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: colorScheme.outline),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => ref.read(chatProvider.notifier).clearQuote(),
          ),
        ],
      ),
    );
  }
}
