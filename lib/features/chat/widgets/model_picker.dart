import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/models/widgets/info_chip.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_manager.dart';
import 'package:sutra/runtime/provisioning/model_manager_provider.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';
import 'package:sutra/runtime/models/model_catalog_service_provider.dart';

/// Bottom sheet for selecting which LLM to use for generation.
Future<void> showModelPicker(BuildContext context, WidgetRef ref, String? currentId) async {
  final manager = ref.read(modelManagerProvider);
  String? expandedModelId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: StreamBuilder<ModelManagerState>(
          stream: manager.stream,
          initialData: manager.state,
          builder: (context, snapshot) {
            final mgrState = snapshot.data ?? const ModelManagerState();
            final allModels = allKnownModels(ref);
            final visibleModels = allModels.where((model) {
              final s = mgrState.modelStates[model.id];
              return s == ModelState.downloaded || s == ModelState.downloading || s == ModelState.failed || s == ModelState.paused;
            }).toList();

            final screenHeight = MediaQuery.of(context).size.height;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(margin: const EdgeInsets.only(top: 12), width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      Icon(Icons.smart_toy_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Select Model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                      Text('${mgrState.installedIds.length} installed', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                    ],
                  ),
                ),
                if (visibleModels.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(children: [
                      Icon(Icons.download_done_outlined, size: 40, color: Theme.of(context).colorScheme.outline),
                      const SizedBox(height: 12),
                      Text('No models downloaded yet', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
                      const SizedBox(height: 4),
                      Text('Go to Models tab to download one', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                    ]),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: screenHeight * 0.55),
                    child: ListView(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      children: [
                        // ── Auto mode tile ──
                        ListTile(
                          leading: Icon(
                            currentId == null ? Icons.radio_button_checked : Icons.auto_awesome,
                            color: currentId == null ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                          ),
                          title: const Text('Auto', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            'Automatically picks the best model for each message',
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                          ),
                          onTap: () {
                            ref.read(selectedModelIdProvider.notifier).select(null);
                            Navigator.of(ctx).pop();
                          },
                        ),
                        const Divider(height: 1),
                        // ── Individual model tiles ──
                        ...visibleModels.map((model) {
                          final modelState = mgrState.modelStates[model.id] ?? ModelState.notDownloaded;
                          final installed = modelState == ModelState.downloaded;
                          final downloading = modelState == ModelState.downloading;
                          final failed = modelState == ModelState.failed;
                          final progress = mgrState.progress[model.id] ?? 0.0;
                          final retryAttempt = mgrState.retryAttempts[model.id];
                          final isExpanded = expandedModelId == model.id;
                          final colorScheme = Theme.of(context).colorScheme;

                          String statusText;
                          if (installed) {
                            statusText = 'Ready';
                          } else if (downloading && retryAttempt != null) {
                            statusText = 'Retry $retryAttempt...';
                          } else if (downloading) {
                            statusText = '${(progress * 100).toStringAsFixed(0)}%';
                          } else if (failed) {
                            statusText = 'Failed';
                          } else {
                            statusText = '';
                          }
                          IconData tileIcon;
                          if (model.id == currentId) {
                            tileIcon = Icons.radio_button_checked;
                          } else if (installed) {
                            tileIcon = Icons.check_circle;
                          } else if (downloading) {
                            tileIcon = Icons.downloading;
                          } else if (failed) {
                            tileIcon = Icons.error_outline;
                          } else {
                            tileIcon = Icons.radio_button_unchecked;
                          }
                          final isSelected = model.id == currentId;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: Icon(tileIcon, color: isSelected ? colorScheme.primary : failed ? colorScheme.error : installed ? colorScheme.primary.withValues(alpha: 0.7) : null),
                                title: Text(model.name, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        InfoChip(icon: Icons.memory_outlined, label: sizeLabel(model.size), compact: true),
                                        const SizedBox(width: 6),
                                        InfoChip(icon: Icons.format_list_numbered, label: '${model.contextLength} ctx', compact: true),
                                        const SizedBox(width: 6),
                                        InfoChip(icon: Icons.chat_bubble_outline, label: templateName(model.chatTemplate), compact: true),
                                        if (model.supports(ModelCapability.webSearch)) ...[
                                          const SizedBox(width: 6),
                                          InfoChip(icon: Icons.language, label: 'Search', compact: true),
                                        ],
                                      ],
                                    ),
                                    if (downloading) Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: progress, minHeight: 3, borderRadius: BorderRadius.circular(2))),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (statusText.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: failed ? colorScheme.errorContainer : installed && isSelected ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: failed ? colorScheme.error : installed && isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant)),
                                      ),
                                    if (failed) ...[
                                      const SizedBox(width: 4),
                                      IconButton(icon: const Icon(Icons.refresh, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => manager.retryDownload(model.id)),
                                    ],
                                  ],
                                ),
                                onTap: () {
                                  setSheetState(() {
                                    expandedModelId = isExpanded ? null : model.id;
                                  });
                                },
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeInOut,
                                child: isExpanded
                                    ? Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            DetailRow(label: 'Size', value: sizeLabel(model.size)),
                                            DetailRow(label: 'Context', value: '${model.contextLength} tokens'),
                                            DetailRow(label: 'Template', value: templateName(model.chatTemplate)),
                                            DetailRow(label: 'Parameters', value: sizeDescription(model.size)),
                                            const SizedBox(height: 8),
                                            if (installed)
                                              SizedBox(
                                                width: double.infinity,
                                                child: FilledButton.icon(
                                                  onPressed: () {
                                                    Navigator.of(ctx).pop();
                                                    ref.read(selectedModelIdProvider.notifier).select(model.id);
                                                  },
                                                  icon: Icon(isSelected ? Icons.check : Icons.play_arrow, size: 18),
                                                  label: Text(isSelected ? 'Currently active' : 'Use this model'),
                                                ),
                                              ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    ),
  );
}

/// Retrieves all known models from both registry and catalog.
List<ModelDefinition> allKnownModels(WidgetRef ref) {
  final catalogService = ref.read(modelCatalogServiceProvider);
  final catalogModels = catalogService.catalog.allEntries
      .map((e) => catalogService.toModelDefinition(e))
      .toList();
  final seen = <String>{};
  final result = <ModelDefinition>[];
  for (final m in [...ModelRegistry.all, ...catalogModels]) {
    if (seen.add(m.id)) {
      result.add(m);
    }
  }
  return result;
}

/// Format [ModelSize] into a human-readable description.
String sizeDescription(ModelSize size) {
  switch (size) {
    case ModelSize.tiny:
      return '< 1B params · Fast, simple tasks';
    case ModelSize.small:
      return '1-2B params · Good balance';
    case ModelSize.medium:
      return '3-4B params · Strong quality';
    case ModelSize.large:
      return '4B+ params · Best quality';
  }
}

/// Format a [ChatTemplate] into a short name.
String templateName(ChatTemplate template) {
  return template.runtimeType.toString().replaceAll('ChatTemplate', '');
}

/// A label-value row used in expanded model details.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const DetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12, color: cs.outline, fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))),
        ],
      ),
    );
  }
}
