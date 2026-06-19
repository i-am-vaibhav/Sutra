import 'package:sutra/core/logging/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../runtime/models/model_catalog.dart';
import '../../runtime/models/model_catalog_entry.dart';
import '../../runtime/models/model_catalog_service.dart';
import '../../runtime/models/model_catalog_service_provider.dart';
import '../../runtime/models/model_definition.dart';
import '../../runtime/models/model_registry.dart';
import '../../runtime/provisioning/model_database.dart';
import '../../runtime/provisioning/model_manager.dart';
import '../../runtime/provisioning/model_manager_provider.dart';
import '../../runtime/pipeline/selected_model_provider.dart';

/// Icons mapped to category icon names from the remote catalog.
const _categoryIcons = <String, IconData>{
  'chat': Icons.chat_bubble_outline,
  'code': Icons.code,
  'science': Icons.science_outlined,
  'translate': Icons.translate,
  'image': Icons.image_outlined,
  'video': Icons.videocam_outlined,
  'audio': Icons.audiotrack_outlined,
  'general': Icons.smart_toy_outlined,
};

class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  ModelCatalog? _catalog;
  bool _loadingCatalog = true;
  bool _loadingCatalogInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCatalog();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    if (_loadingCatalogInProgress) return;
    _loadingCatalogInProgress = true;
    try {
      final catalogService = ref.read(modelCatalogServiceProvider);
      final catalog = await catalogService.getCatalog();
      if (!mounted) return;
      _tabController?.dispose();
      _tabController = TabController(
        length: catalog.categories.length + 2, // Local + Queue + categories
        vsync: this,
      );
      setState(() {
        _catalog = catalog;
        _loadingCatalog = false;
      });
    } catch (e) {
      Log.d('[ModelsScreen] Failed to load catalog: $e');
      if (!mounted) return;
      _tabController?.dispose();
      _tabController = TabController(
        length: ModelCatalog.fallback.categories.length + 2,
        vsync: this,
      );
      setState(() {
        _catalog = ModelCatalog.fallback;
        _loadingCatalog = false;
      });
    } finally {
      _loadingCatalogInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedModelIdProvider);
    final manager = ref.read(modelManagerProvider);
    final catalogService = ref.read(modelCatalogServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Models'),
        bottom: _loadingCatalog
            ? null
            : TabBar(
                isScrollable: true,
                controller: _tabController,
                tabs: [
                  const Tab(text: 'Local'),
                  const Tab(text: 'Queue'),
                  ...?_catalog?.categories.map((c) => Tab(
                        child: Text(c.name, style: const TextStyle(fontSize: 13)),
                      )),
                ],
              ),
      ),
      body: _loadingCatalog
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<ModelManagerState>(
              stream: manager.stream,
              initialData: manager.state,
              builder: (context, snapshot) {
                final mgrState = snapshot.data ?? const ModelManagerState();

                // Show SnackBar on storage warning.
                if (mgrState.storageWarning != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(mgrState.storageWarning!),
                          backgroundColor: Theme.of(context).colorScheme.errorContainer,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(
                            label: 'Dismiss',
                            textColor: Theme.of(context).colorScheme.onErrorContainer,
                            onPressed: () => manager.clearStorageWarning(),
                          ),
                        ),
                      );
                      manager.clearStorageWarning();
                    }
                  });
                }

                // Show SnackBar on download completion.
                if (mgrState.downloadCompleteMessage != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(mgrState.downloadCompleteMessage!)),
                            ],
                          ),
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                      manager.clearDownloadComplete();
                    }
                  });
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _LocalModelsTab(
                      mgrState: mgrState,
                      selectedId: selectedId,
                      onModelSelected: (id) {
                        ref.read(selectedModelIdProvider.notifier).select(id);
                      },
                      manager: manager,
                      catalogService: catalogService,
                    ),
                    _QueueTab(
                      mgrState: mgrState,
                      manager: manager,
                      catalogService: catalogService,
                    ),
                    ...?_catalog?.categories.map((category) =>
                        _CatalogCategoryTab(
                          category: category,
                          mgrState: mgrState,
                          selectedId: selectedId,
                          manager: manager,
                          catalogService: catalogService,
                        )),
                  ],
                );
              },
            ),
    );
  }
}

// ── Local (installed) models tab ─────────────────────────────

class _LocalModelsTab extends StatelessWidget {
  final ModelManagerState mgrState;
  final String? selectedId;
  final ValueChanged<String> onModelSelected;
  final ModelManager manager;
  final ModelCatalogService catalogService;

  const _LocalModelsTab({
    required this.mgrState,
    required this.selectedId,
    required this.onModelSelected,
    required this.manager,
    required this.catalogService,
  });

  @override
  Widget build(BuildContext context) {
    final allModels = ModelRegistry.all;
    final installed =
        allModels.where((m) => mgrState.installedIds.contains(m.id)).toList();

    if (installed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_done, size: 48,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No models installed yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Browse categories to download models',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }

    return Column(
      children: [
        _StorageSummary(totalBytes: mgrState.totalDiskBytes, modelCount: installed.length, freeDiskBytes: mgrState.freeDiskBytes),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: installed.length,
            itemBuilder: (context, index) {
              final model = installed[index];
              return _ModelTile(
                model: model,
                mgrState: mgrState,
                isSelected: selectedId == model.id,
                onSelect: () => onModelSelected(model.id),
                manager: manager,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Queue (downloading) tab ──────────────────────────────────

class _QueueTab extends StatelessWidget {
  final ModelManagerState mgrState;
  final ModelManager manager;
  final ModelCatalogService catalogService;

  const _QueueTab({
    required this.mgrState,
    required this.manager,
    required this.catalogService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Collect all models that are downloading.
    final downloadingModels = <MapEntry<String, ModelState>>[];
    mgrState.modelStates.forEach((id, state) {
      if (state == ModelState.downloading || state == ModelState.paused) {
        downloadingModels.add(MapEntry(id, state));
      }
    });

    if (downloadingModels.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_done, size: 48,
                color: colorScheme.outline),
            const SizedBox(height: 16),
            Text('No downloads in queue',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Downloaded models will appear here',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.outline)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: downloadingModels.length,
      itemBuilder: (context, index) {
        final entry = downloadingModels[index];
        final modelId = entry.key;
        final progress = mgrState.progress[modelId] ?? 0.0;
        final retryAttempt = mgrState.retryAttempts[modelId];

        // Find model name from registry or catalog.
        final regModel = ModelRegistry.all
            .where((m) => m.id == modelId)
            .firstOrNull;
        final catEntry = catalogService.catalog.allEntries
            .where((e) => e.id == modelId)
            .firstOrNull;
        final name = regModel?.name ?? catEntry?.name ?? modelId;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(
                        value: progress > 0 ? progress : null,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            retryAttempt != null
                                ? 'Retry $retryAttempt — ${(progress * 100).toStringAsFixed(0)}%'
                                : progress > 0
                                    ? '${(progress * 100).toStringAsFixed(0)}% downloaded'
                                    : 'Starting download...',
                            style: TextStyle(
                                fontSize: 12, color: colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Cancel download',
                      onPressed: () => manager.cancelDownload(modelId),
                    ),
                  ],
                ),
                if (progress > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Catalog category tab ─────────────────────────────────────

class _CatalogCategoryTab extends StatelessWidget {
  final ModelCatalogCategory category;
  final ModelManagerState mgrState;
  final String? selectedId;
  final ModelManager manager;
  final ModelCatalogService catalogService;

  const _CatalogCategoryTab({
    required this.category,
    required this.mgrState,
    required this.selectedId,
    required this.manager,
    required this.catalogService,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  _categoryIcons[category.icon] ?? Icons.smart_toy_outlined,
                  size: 24,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(category.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...category.entries.map((entry) => _CatalogModelTile(
              entry: entry,
              mgrState: mgrState,
              selectedId: selectedId,
              manager: manager,
              catalogService: catalogService,
            )),
      ],
    );
  }
}

// ── Catalog model tile ───────────────────────────────────────

class _CatalogModelTile extends StatelessWidget {
  final ModelCatalogEntry entry;
  final ModelManagerState mgrState;
  final String? selectedId;
  final ModelManager manager;
  final ModelCatalogService catalogService;

  const _CatalogModelTile({
    required this.entry,
    required this.mgrState,
    required this.selectedId,
    required this.manager,
    required this.catalogService,
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.memory,
                            label: sizeLabel(modelDef.size),
                          ),
                          const SizedBox(width: 8),
                          if (entry.contextLength > 0)
                            _InfoChip(
                              icon: Icons.format_list_numbered,
                              label: '${entry.contextLength} ctx',
                            ),
                          if (installed && mgrState.modelDiskBytes.containsKey(entry.id)) ...[
                            const SizedBox(width: 8),
                            _InfoChip(
                              icon: Icons.storage,
                              label: _formatBytes(mgrState.modelDiskBytes[entry.id]!),
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

// ── Local model tile ─────────────────────────────────────────

class _ModelTile extends StatelessWidget {
  final ModelDefinition model;
  final ModelManagerState mgrState;
  final bool isSelected;
  final VoidCallback onSelect;
  final ModelManager manager;

  const _ModelTile({
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
                          _InfoChip(
                            icon: Icons.storage,
                            label: _formatBytes(mgrState.modelDiskBytes[model.id]!),
                          ),
                      ],
                    ),
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
    final sizeText = diskBytes != null ? _formatBytes(diskBytes) : null;

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

// ── Storage summary header ──────────────────────────────────

class _StorageSummary extends StatelessWidget {
  final int totalBytes;
  final int modelCount;
  final int freeDiskBytes;
  const _StorageSummary({required this.totalBytes, required this.modelCount, required this.freeDiskBytes});

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
                  '$modelCount model${modelCount == 1 ? '' : 's'} · ${_formatBytes(totalBytes)} used',
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
                if (freeDiskBytes > 0) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${_formatBytes(freeDiskBytes)} free on device',
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

/// Format bytes to human-readable string.
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

// ── Info chip ────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.outline),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: cs.outline)),
        ],
      ),
    );
  }
}
