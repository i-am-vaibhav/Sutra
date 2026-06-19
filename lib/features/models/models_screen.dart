import 'package:sutra/core/logging/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/models/widgets/catalog_tiles.dart';
import 'package:sutra/features/models/widgets/storage_summary.dart';

import '../../runtime/models/model_catalog.dart';
import '../../runtime/models/model_catalog_entry.dart';
import '../../runtime/models/model_catalog_service.dart';
import '../../runtime/models/model_catalog_service_provider.dart';
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

/// Icons for search suggestion chips.
const _taskIcons = <String, IconData>{
  'translate': Icons.translate,
  'translation': Icons.translate,
  'summarize': Icons.summarize,
  'summary': Icons.summarize,
  'analysis': Icons.analytics_outlined,
  'code': Icons.code,
  'programming': Icons.code,
  'chat': Icons.chat_bubble_outline,
  'conversation': Icons.chat_bubble_outline,
  'qa': Icons.question_answer_outlined,
  'question': Icons.question_answer_outlined,
  'knowledge': Icons.psychology_outlined,
  'sentiment': Icons.sentiment_satisfied_alt_outlined,
  'entity': Icons.label_outline,
  'intent': Icons.ads_click,
  'fast': Icons.speed,
  'quick': Icons.speed,
  'small': Icons.speed,
  'reasoning': Icons.psychology_outlined,
  'creative': Icons.brush_outlined,
  'writing': Icons.edit_outlined,
};

/// Task keywords that map user intents to relevant model categories/entries.
const _taskKeywords = <String, List<String>>{
  'translate': ['translation', 'multilingual', 'language'],
  'translation': ['translation', 'multilingual', 'language'],
  'summarize': ['summarization', 'summary', 'analysis'],
  'summary': ['summarization', 'summary', 'analysis'],
  'analysis': ['summarization', 'analysis', 'extract'],
  'code': ['coding', 'code', 'programming'],
  'programming': ['coding', 'code', 'programming'],
  'chat': ['chat', 'conversation', 'dialogue'],
  'conversation': ['chat', 'conversation', 'dialogue'],
  'qa': ['qa', 'question', 'knowledge', 'factual'],
  'question': ['qa', 'question', 'knowledge', 'factual'],
  'knowledge': ['qa', 'knowledge', 'factual'],
  'sentiment': ['fast', 'chat', 'nlu', 'sentiment'],
  'entity': ['fast', 'chat', 'nlu', 'entity'],
  'intent': ['fast', 'chat', 'nlu', 'intent'],
  'fast': ['fast', 'light'],
  'quick': ['fast', 'light'],
  'small': ['fast', 'light'],
  'reasoning': ['chat', 'qa', 'analysis'],
  'creative': ['chat', 'summarization'],
  'writing': ['chat', 'summarization'],
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
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchResults = false;

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
    _searchController.dispose();
    super.dispose();
  }

  List<ModelCatalogEntry> _searchCatalog(String query) {
    if (_catalog == null || query.isEmpty) return [];
    final q = query.toLowerCase();

    final expandedTerms = <String>{q};
    _taskKeywords.forEach((key, synonyms) {
      if (q.contains(key) || synonyms.any((s) => q.contains(s))) {
        expandedTerms.add(key);
        expandedTerms.addAll(synonyms);
      }
    });

    final seen = <String>{};
    final results = <ModelCatalogEntry>[];
    for (final entry in _catalog!.allEntries) {
      if (seen.contains(entry.id)) continue;
      final haystack = '${entry.name} ${entry.description} ${entry.category}'.toLowerCase();
      if (expandedTerms.any((term) => haystack.contains(term))) {
        seen.add(entry.id);
        results.add(entry);
      }
    }
    return results;
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
        length: catalog.categories.length + 2,
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

  Widget _buildSearchResults({
    required String? selectedId,
    required ModelManager manager,
    required ModelCatalogService catalogService,
  }) {
    final mgrState = manager.state;
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Try a task', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              'translate', 'summarize', 'code', 'chat', 'qa',
              'sentiment', 'entity', 'reasoning', 'fast', 'writing',
            ].map((task) => ActionChip(
              avatar: Icon(_taskIcons[task] ?? Icons.smart_toy_outlined, size: 16),
              label: Text(task[0].toUpperCase() + task.substring(1)),
              onPressed: () {
                _searchController.text = task;
                setState(() {
                  _searchQuery = task;
                  _showSearchResults = true;
                });
              },
            )).toList(),
          ),
        ],
      );
    }

    final results = _searchCatalog(query);
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No models match "$query"', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Try a different search term',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }

    final categoryNameToIcon = <String, IconData>{};
    for (final cat in _catalog!.categories) {
      categoryNameToIcon[cat.name] = _categoryIcons[cat.icon] ?? Icons.smart_toy_outlined;
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final entry = results[index];
        return CatalogModelTile(
          entry: entry,
          mgrState: mgrState,
          selectedId: selectedId,
          manager: manager,
          catalogService: catalogService,
          showCategory: true,
          categoryIcon: categoryNameToIcon[entry.category],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedId = ref.watch(selectedModelIdProvider);
    final manager = ref.read(modelManagerProvider);
    final catalogService = ref.read(modelCatalogServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearchResults
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search models by task... (e.g. translate, summarize, code)',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
                onChanged: (value) {
                  setState(() { _searchQuery = value; });
                },
              )
            : const Text('Models'),
        actions: [
          if (_showSearchResults)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _showSearchResults = false;
                });
              },
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search models',
              onPressed: () {
                setState(() { _showSearchResults = true; });
              },
            ),
        ],
        bottom: _loadingCatalog || _showSearchResults
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
          : _showSearchResults
              ? _buildSearchResults(selectedId: selectedId, manager: manager, catalogService: catalogService)
              : StreamBuilder<ModelManagerState>(
              stream: manager.stream,
              initialData: manager.state,
              builder: (context, snapshot) {
                final mgrState = snapshot.data ?? const ModelManagerState();

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
                    ),
                    _QueueTab(mgrState: mgrState, manager: manager, catalogService: catalogService),
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

  const _LocalModelsTab({
    required this.mgrState,
    required this.selectedId,
    required this.onModelSelected,
    required this.manager,
  });

  @override
  Widget build(BuildContext context) {
    final allModels = ModelRegistry.all;
    final installed = allModels.where((m) => mgrState.installedIds.contains(m.id)).toList();

    if (installed.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_done, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('No models installed yet', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Browse categories to download models',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      );
    }

    return Column(
      children: [
        StorageSummary(totalBytes: mgrState.totalDiskBytes, modelCount: installed.length, freeDiskBytes: mgrState.freeDiskBytes),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: installed.length,
            itemBuilder: (context, index) {
              final model = installed[index];
              return ModelTile(
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

  const _QueueTab({required this.mgrState, required this.manager, required this.catalogService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            Icon(Icons.download_done, size: 48, color: colorScheme.outline),
            const SizedBox(height: 16),
            Text('No downloads in queue', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Downloaded models will appear here',
                style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
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

        final regModel = ModelRegistry.all.where((m) => m.id == modelId).firstOrNull;
        final catEntry = catalogService.catalog.allEntries.where((e) => e.id == modelId).firstOrNull;
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
                    SizedBox(width: 28, height: 28, child: CircularProgressIndicator(value: progress > 0 ? progress : null, strokeWidth: 2)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(
                            retryAttempt != null
                                ? 'Retry $retryAttempt — ${(progress * 100).toStringAsFixed(0)}%'
                                : progress > 0
                                    ? '${(progress * 100).toStringAsFixed(0)}% downloaded'
                                    : 'Starting download...',
                            style: TextStyle(fontSize: 12, color: colorScheme.outline),
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
                      Text(category.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(category.description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...category.entries.map((entry) => CatalogModelTile(
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
