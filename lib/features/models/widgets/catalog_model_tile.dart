import 'package:flutter/material.dart';
import 'package:sutra/runtime/models/model_catalog_entry.dart';
import 'package:sutra/runtime/models/model_catalog_service.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_manager.dart';
import 'package:sutra/features/models/widgets/info_chip.dart';
import 'package:sutra/features/models/widgets/capability_badge.dart';
import 'package:sutra/runtime/models/model_definition.dart';

/// A card tile showing a catalog model with download/install status.
class CatalogModelTile extends StatelessWidget {
  final ModelCatalogEntry entry;
  final ModelManagerState mgrState;
  final String? selectedId;
  final ModelManager manager;
  final ModelCatalogService catalogService;
  final bool showCategory;
  final IconData? categoryIcon;

  const CatalogModelTile({
    super.key,
    required this.entry,
    required this.mgrState,
    required this.selectedId,
    required this.manager,
    required this.catalogService,
    this.showCategory = false,
    this.categoryIcon,
  });

  @override
  Widget build(BuildContext context) {
    final modelDef = catalogService.toModelDefinition(entry);
    final state = mgrState.modelStates[entry.id] ?? ModelState.notDownloaded;
    final installed = state == ModelState.downloaded;
    final downloading = state == ModelState.downloading;
    final failed = state == ModelState.failed;
    final deleted = state == ModelState.deleted;
    final progress = mgrState.progress[entry.id] ?? 0.0;
    final retryAttempt = mgrState.retryAttempts[entry.id];
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(entry.description,
                          style: TextStyle(fontSize: 12, color: colorScheme.outline)),
                      if (showCategory) ...[
                        const SizedBox(height: 6),
                        InfoChip(
                          icon: categoryIcon ?? Icons.smart_toy_outlined,
                          label: entry.category,
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (modelDef.capabilities.isNotEmpty) ...[
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: modelDef.capabilities.map((cap) => CapabilityBadge(capability: cap)).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          InfoChip(
                            icon: Icons.memory,
                            label: sizeLabel(modelDef.size),
                          ),
                          const SizedBox(width: 8),
                          if (entry.contextLength > 0)
                            InfoChip(
                              icon: Icons.format_list_numbered,
                              label: '${entry.contextLength} ctx',
                            ),
                          if (installed && mgrState.modelDiskBytes.containsKey(entry.id)) ...[
                            const SizedBox(width: 8),
                            InfoChip(
                              icon: Icons.storage,
                              label: formatBytes(mgrState.modelDiskBytes[entry.id]!),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusColumn(context, colorScheme, installed, downloading, failed, deleted, progress, retryAttempt),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress > 0 ? progress : null),
            ],
            if (!installed && !downloading) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: deleted
                      ? () => manager.redownloadModel(entry.id)
                      : () => manager.downloadModel(modelDef),
                  icon: Icon(deleted ? Icons.refresh : Icons.download, size: 18),
                  label: Text(deleted ? 'Re-download' : 'Download'),
                ),
              ),
            ],
            if (failed) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => manager.retryDownload(entry.id),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusColumn(BuildContext context, ColorScheme colorScheme,
      bool installed, bool downloading, bool failed, bool deleted,
      double progress, int? retryAttempt) {
    if (installed) {
      return Column(
        children: [
          Icon(Icons.check_circle, color: colorScheme.primary, size: 28),
          const SizedBox(height: 4),
          Text('Installed',
              style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold)),
        ],
      );
    }
    if (downloading) {
      return Column(
        children: [
          SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(value: progress > 0 ? progress : null, strokeWidth: 2),
          ),
          const SizedBox(height: 4),
          Text(retryAttempt != null ? 'Retry $retryAttempt' : '${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: colorScheme.outline)),
        ],
      );
    }
    if (failed) {
      return Column(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error, size: 28),
          const SizedBox(height: 4),
          Text('Failed', style: TextStyle(fontSize: 11, color: colorScheme.error)),
        ],
      );
    }
    if (deleted) {
      return Column(
        children: [
          Icon(Icons.delete_outline, color: colorScheme.outline, size: 28),
          const SizedBox(height: 4),
          Text('Deleted', style: TextStyle(fontSize: 11, color: colorScheme.outline)),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
