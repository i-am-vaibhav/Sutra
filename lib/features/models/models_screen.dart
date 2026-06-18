import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../runtime/models/model_catalog.dart';
import '../../runtime/models/model_catalog_entry.dart';
import '../../runtime/models/model_catalog_service.dart';
import '../../runtime/models/model_catalog_service_provider.dart';
import '../../runtime/models/model_definition.dart';
import '../../runtime/models/model_registry.dart';
import '../../runtime/models_provision/model_provisioning_service.dart';
import '../../runtime/models_provision/model_provisioning_state.dart';
import '../../runtime/orchestration/selected_model_provider.dart';

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
    with SingleTickerProviderStateMixin {
  bool _autoSelected = false;
  late TabController _tabController;
  ModelCatalog? _catalog;
  bool _loadingCatalog = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Defer ref.read() to after first frame so Riverpod is fully ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadCatalog();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalogService = ref.read(modelCatalogServiceProvider);
      final catalog = await catalogService.getCatalog();
      if (mounted) {
        setState(() {
          _catalog = catalog;
          _loadingCatalog = false;
          _tabController.dispose();
          _tabController = TabController(
            length: catalog.categories.length + 1,
            vsync: this,
          );
        });
      }
    } catch (e) {
      debugPrint('[ModelsScreen] Failed to load catalog: $e');
      // Always fall back to embedded catalog on error.
      if (mounted) {
        setState(() {
          _catalog = ModelCatalog.fallback;
          _loadingCatalog = false;
          _tabController.dispose();
          _tabController = TabController(
            length: ModelCatalog.fallback.categories.length + 1,
            vsync: this,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedModelIdProvider);
    final provisioningService = ref.read(modelProvisioningServiceProvider);
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
                  ...?_catalog?.categories.map((c) => Tab(
                        child: Text(c.name, style: const TextStyle(fontSize: 13)),
                      )),
                ],
              ),
      ),
      body: _loadingCatalog
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<ModelProvisioningState>(
              stream: provisioningService.stream,
              initialData: ModelProvisioningState.empty(),
              builder: (context, snapshot) {
                final state =
                    snapshot.data ?? ModelProvisioningState.empty();

                if (!_autoSelected &&
                    selectedId == null &&
                    state.installed.isNotEmpty) {
                  _autoSelected = true;
                  final firstInstalled = ModelRegistry.all.firstWhere(
                    (m) => state.installed.contains(m.id),
                    orElse: () => ModelRegistry.all.first,
                  );
                  Future.microtask(() {
                    if (mounted) {
                      ref
                          .read(selectedModelIdProvider.notifier)
                          .select(firstInstalled.id);
                    }
                  });
                }

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _LocalModelsTab(
                      state: state,
                      selectedId: selectedId,
                      onModelSelected: (id) {
                        ref.read(selectedModelIdProvider.notifier).select(id);
                      },
                      provisioningService: provisioningService,
                      catalogService: catalogService,
                    ),
                    ...?_catalog?.categories.map((category) =>
                        _CatalogCategoryTab(
                          category: category,
                          state: state,
                          selectedId: selectedId,
                          provisioningService: provisioningService,
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
  final ModelProvisioningState state;
  final String? selectedId;
  final ValueChanged<String> onModelSelected;
  final ModelProvisioningService provisioningService;
  final ModelCatalogService catalogService;

  const _LocalModelsTab({
    required this.state,
    required this.selectedId,
    required this.onModelSelected,
    required this.provisioningService,
    required this.catalogService,
  });

  @override
  Widget build(BuildContext context) {
    final allModels = ModelRegistry.all;
    final installed =
        allModels.where((m) => state.installed.contains(m.id)).toList();

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

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: installed.length,
      itemBuilder: (context, index) {
        final model = installed[index];
        return _ModelTile(
          model: model,
          state: state,
          isSelected: selectedId == model.id,
          onSelect: () => onModelSelected(model.id),
          onRetry: state.failed.contains(model.id)
              ? () => provisioningService.retry(model)
              : null,
        );
      },
    );
  }
}

// ── Catalog category tab ─────────────────────────────────────

class _CatalogCategoryTab extends StatelessWidget {
  final ModelCatalogCategory category;
  final ModelProvisioningState state;
  final String? selectedId;
  final ModelProvisioningService provisioningService;
  final ModelCatalogService catalogService;

  const _CatalogCategoryTab({
    required this.category,
    required this.state,
    required this.selectedId,
    required this.provisioningService,
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
              state: state,
              selectedId: selectedId,
              provisioningService: provisioningService,
              catalogService: catalogService,
            )),
      ],
    );
  }
}

// ── Catalog model tile ───────────────────────────────────────

class _CatalogModelTile extends StatelessWidget {
  final ModelCatalogEntry entry;
  final ModelProvisioningState state;
  final String? selectedId;
  final ModelProvisioningService provisioningService;
  final ModelCatalogService catalogService;

  const _CatalogModelTile({
    required this.entry,
    required this.state,
    required this.selectedId,
    required this.provisioningService,
    required this.catalogService,
  });

  @override
  Widget build(BuildContext context) {
    final modelDef = catalogService.toModelDefinition(entry);
    final installed = state.installed.contains(entry.id);
    final downloading = state.downloading.contains(entry.id);
    final failed = state.failed.contains(entry.id);
    final progress = state.progress[entry.id] ?? 0.0;
    final retryAttempt = state.retryAttempts[entry.id];
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
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildStatusColumn(context, colorScheme, installed, downloading, failed, progress, retryAttempt),
              ],
            ),
            if (downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(value: progress),
            ],
            if (!installed && !downloading) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => provisioningService.provision([modelDef]),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download'),
                ),
              ),
            ],
            if (failed) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => provisioningService.retry(modelDef),
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



  Widget _buildStatusColumn(BuildContext context, ColorScheme colorScheme, bool installed, bool downloading, bool failed, double progress, int? retryAttempt) {
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
    return const SizedBox.shrink();
  }
}

// ── Local model tile ─────────────────────────────────────────

class _ModelTile extends StatelessWidget {
  final ModelDefinition model;
  final ModelProvisioningState state;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback? onRetry;

  const _ModelTile({
    required this.model,
    required this.state,
    required this.isSelected,
    required this.onSelect,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final installed = state.installed.contains(model.id);
    final downloading = state.downloading.contains(model.id);
    final failed = state.failed.contains(model.id);
    final progress = state.progress[model.id] ?? 0.0;
    final retryAttempt = state.retryAttempts[model.id];
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
                    Text(model.id, style: TextStyle(fontSize: 12, color: colorScheme.outline)),
                  ],
                ),
              ),
              Text(statusText,
                  style: TextStyle(
                    fontWeight: installed && isSelected ? FontWeight.bold : FontWeight.normal,
                    color: failed ? colorScheme.error : isSelected ? colorScheme.primary : null,
                  )),
              if (failed && onRetry != null) ...[
                const SizedBox(width: 8),
                IconButton(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18),
                    constraints: const BoxConstraints(), padding: EdgeInsets.zero),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
