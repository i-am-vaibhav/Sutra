import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;

  const EmptyState({super.key, required this.colorScheme, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.psychology_outlined, size: 48, color: colorScheme.primary),
            ),
            const SizedBox(height: 20),
            Text('Start a conversation',
              style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Send a message to begin',
              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.outline),
              textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: colorScheme.tertiary),
                  const SizedBox(width: 6),
                  Text('Runs on-device · No data leaves your phone',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.tertiary,
                      fontWeight: FontWeight.w500,
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
