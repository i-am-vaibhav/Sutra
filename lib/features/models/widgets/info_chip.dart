import 'package:flutter/material.dart';

/// Small chip showing model metadata (size, context, etc.).
///
/// Set [compact] to `true` for tighter spacing in dense layouts
/// (e.g. inside chat model picker subtitles).
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool compact;

  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: compact ? 0.7 : 1),
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 10 : 12, color: cs.outline),
          SizedBox(width: compact ? 3 : 4),
          Text(
            label,
            style: TextStyle(fontSize: compact ? 10 : 11, color: cs.outline),
          ),
        ],
      ),
    );
  }
}

/// Format bytes to human-readable string.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
