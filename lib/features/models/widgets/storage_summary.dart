import 'package:flutter/material.dart';
import 'package:sutra/features/models/widgets/info_chip.dart';

/// Storage usage summary header shown at the top of the local models tab.
class StorageSummary extends StatelessWidget {
  final int totalBytes;
  final int modelCount;
  final int freeDiskBytes;
  const StorageSummary({
    super.key,
    required this.totalBytes,
    required this.modelCount,
    required this.freeDiskBytes,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.storage, size: 20, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Storage Usage',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$modelCount model${modelCount == 1 ? '' : 's'} · ${formatBytes(totalBytes)} used',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
                if (freeDiskBytes > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${formatBytes(freeDiskBytes)} free on device',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
