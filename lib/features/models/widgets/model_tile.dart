import 'package:flutter/material.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_manager.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/features/models/widgets/info_chip.dart';
import 'package:sutra/features/models/widgets/capability_badge.dart';

/// A card tile showing a locally installed model with select/delete actions.
class ModelTile extends StatelessWidget {
  final ModelDefinition model;
  final ModelManagerState mgrState;
  final bool isSelected;
  final VoidCallback onSelect;
  final ModelManager manager;

  const ModelTile({
    super.key,
    required this.model,
    required this.mgrState,
    required this.isSelected,
    required this.onSelect,
    required this.manager,
  });

  @override
  Widget build(BuildContext context) {
    final state = mgrState.modelStates[model.id] ?? ModelState.notDownloaded;
    final installed = state == ModelState.downloaded;
    final downloading = state == ModelState.downloading;
    final failed = state == ModelState.failed;
    final progress = mgrState.progress[model.id] ?? 0.0;
    final retryAttempt = mgrState.retryAttempts[model.id];
    final colorScheme = Theme.of(context).colorScheme;

    IconData icon;
    Color? iconColor;
    if (installed) {
      icon = isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked;
      iconColor = isSelected ? colorScheme.primary : null;
    } else if (downloading) {
      icon = Icons.download;
      iconColor = colorScheme.primary;
    } else if (failed) {
      icon = Icons.error_outline;
      iconColor = colorScheme.error;
    } else {
      icon = Icons.memory;
    }

    String statusText;
    if (installed) {
      statusText = 'Installed';
    } else if (downloading && retryAttempt != null) {
      statusText = 'Retry $retryAttempt…';
    } else if (downloading) {
      statusText = '${(progress * 100).toStringAsFixed(0)}%';
    } else if (failed) {
      statusText = 'Failed';
    } else {
      statusText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : failed ? colorScheme.error : colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: installed ? onSelect : null,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(model.id, style: TextStyle(fontSize: 12, color: colorScheme.outline)),
                        const SizedBox(width: 8),
                        if (mgrState.modelDiskBytes.containsKey(model.id))
                          InfoChip(
                            icon: Icons.storage,
                            label: formatBytes(mgrState.modelDiskBytes[model.id]!),
                          ),
                      ],
                    ),
                    if (model.capabilities.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: model.capabilities.map((cap) => CapabilityBadge(capability: cap)).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              Text(statusText,
                  style: TextStyle(
                    fontWeight: installed && isSelected ? FontWeight.bold : FontWeight.normal,
                    color: failed ? colorScheme.error : isSelected ? colorScheme.primary : null,
                  )),
              if (installed) ...[
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(Icons.more_vert, size: 18, color: colorScheme.outline),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _confirmDelete(context, colorScheme);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'delete', child: Text('Delete model')),
                  ],
                ),
              ],
              if (failed) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => manager.retryDownload(model.id),
                  icon: const Icon(Icons.refresh, size: 18),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ColorScheme colorScheme) {
    final diskBytes = mgrState.modelDiskBytes[model.id];
    final sizeText = diskBytes != null ? formatBytes(diskBytes) : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete model?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This will permanently remove "${model.name}" from your device. You can re-download it later.'),
            if (sizeText != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storage, size: 16, color: colorScheme.error),
                    const SizedBox(width: 8),
                    Text(
                      '$sizeText will be freed',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              manager.deleteModel(model.id);
            },
            child: Text('Delete', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
  }
}
