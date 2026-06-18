import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:sutra/features/chat/models/chat_message.dart';
import 'package:sutra/runtime/models/model_catalog_service_provider.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/orchestration/chat_template.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/models_provision/model_provisioning_service.dart';
import 'package:sutra/runtime/models_provision/model_provisioning_state.dart';
import 'package:sutra/runtime/orchestration/runtime_provider.dart';
import 'package:sutra/runtime/orchestration/selected_model_provider.dart';
import 'providers/chat_provider.dart';
import 'conversation_list_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  bool _showScrollDown = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final atBottom = scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 80;
    if (atBottom != _showScrollDown) {
      setState(() => _showScrollDown = !atBottom);
    }
  }

  void sendMessage() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    ref.read(chatProvider.notifier).sendMessage(text);
    controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showMessageActions(ChatMessage msg) {
    final isUser = msg.role == ChatRole.user;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.of(ctx).pop();
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
            if (!isUser && msg.text.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Regenerate'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  final messages = ref.read(chatProvider).messages;
                  final msgIndex = messages.indexWhere((m) => m.id == msg.id);
                  if (msgIndex > 0) {
                    final prevUser = messages
                        .sublist(0, msgIndex)
                        .lastWhere(
                          (m) => m.role == ChatRole.user,
                          orElse: () => msg,
                        );
                    if (prevUser.role == ChatRole.user) {
                      ref.read(chatProvider.notifier).deleteMessage(msg.id);
                      ref.read(chatProvider.notifier).sendMessage(prevUser.text);
                    }
                  }
                },
              ),
            ListTile(
              leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
              title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(chatProvider.notifier).deleteMessage(msg.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sutra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Conversations',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConversationListScreen()),
              );
            },
          ),
        ],
        bottom: _ModelStatusBar(chatState: chatState),
      ),
      body: Column(
        children: [
          if (chatState.error != null)
            MaterialBanner(
              content: Text(chatState.error!),
              backgroundColor: colorScheme.errorContainer,
              leading: Icon(Icons.error_outline, color: colorScheme.onErrorContainer),
              actions: [
                TextButton(
                  onPressed: () => ref.read(chatProvider.notifier).clearError(),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: messages.isEmpty
                ? _EmptyState(colorScheme: colorScheme, theme: theme)
                : Stack(
                    children: [
                      ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isUser = msg.role == ChatRole.user;
                          final isStreaming = chatState.isGenerating &&
                              !isUser &&
                              msg.text.isEmpty;
                          // During streaming, use plain text to avoid
                          // expensive MarkdownBody re-parse on every token.
                          final usePlainText = chatState.isGenerating &&
                              !isUser &&
                              msg.text.isNotEmpty;

                          return GestureDetector(
                            onLongPress: () => _showMessageActions(msg),
                            child: RepaintBoundary(
                              child: Align(
                                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  constraints: const BoxConstraints(maxWidth: 340),
                                  decoration: BoxDecoration(
                                    color: isUser ? colorScheme.primary : colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                                      bottomRight: Radius.circular(isUser ? 4 : 18),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.06),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: isStreaming
                                      ? SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        )
                                      : isUser || usePlainText
                                          ? Text(msg.text, style: TextStyle(color: isUser ? colorScheme.onPrimary : colorScheme.onSurfaceVariant, height: 1.4))
                                          : MarkdownBody(
                                              data: msg.text,
                                              styleSheet: MarkdownStyleSheet(
                                                p: TextStyle(color: colorScheme.onSurfaceVariant, height: 1.4),
                                                code: TextStyle(
                                                  color: colorScheme.onSurfaceVariant,
                                                  backgroundColor: colorScheme.surface,
                                                  fontFamily: 'monospace',
                                                  fontSize: 13,
                                                ),
                                                codeblockDecoration: BoxDecoration(
                                                  color: colorScheme.surface,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                              ),
                                            ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      if (_showScrollDown)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: FloatingActionButton.small(
                            onPressed: _scrollToBottom,
                            child: const Icon(Icons.arrow_downward),
                          ),
                        ),
                    ],
                  ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4), width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !chatState.isBusy,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: chatState.isModelLoading
                            ? 'Loading model...'
                            : chatState.isGenerating
                                ? 'Generating...'
                                : 'Type a message...',
                        hintStyle: TextStyle(color: colorScheme.outline),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: chatState.isBusy ? colorScheme.surfaceContainerHighest : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: chatState.isBusy ? null : sendMessage,
                      icon: chatState.isGenerating || chatState.isModelLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(Icons.arrow_upward, color: chatState.isBusy ? colorScheme.outline : colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    super.dispose();
  }
}

class _EmptyState extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _EmptyState({required this.colorScheme, required this.theme});

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

class _ModelStatusBar extends ConsumerWidget implements PreferredSizeWidget {
  final ChatState chatState;

  const _ModelStatusBar({required this.chatState});

  @override
  Size get preferredSize => const Size.fromHeight(36);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedModelIdProvider);
    final runtimeAsync = ref.watch(runtimeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String modelName;
    if (selectedId != null) {
      final allModels = _allKnownModels(ref);
      final model = allModels.firstWhere((m) => m.id == selectedId, orElse: () => allModels.first);
      modelName = model.name;
    } else {
      modelName = 'No model';
    }

    _StatusKind status;
    if (chatState.isModelLoading) {
      status = _StatusKind.loading;
    } else if (runtimeAsync is AsyncLoading) {
      status = _StatusKind.loading;
    } else if (runtimeAsync is AsyncError) {
      status = _StatusKind.error;
    } else if (selectedId == null) {
      status = _StatusKind.none;
    } else if (runtimeAsync.value?.isReady == true) {
      status = _StatusKind.ready;
    } else {
      status = _StatusKind.none;
    }

    final Color bgColor;
    final Color fgColor;
    final IconData icon;

    switch (status) {
      case _StatusKind.ready:
        bgColor = colorScheme.primaryContainer;
        fgColor = colorScheme.onPrimaryContainer;
        icon = Icons.check_circle_outline;
      case _StatusKind.loading:
        bgColor = colorScheme.secondaryContainer;
        fgColor = colorScheme.onSecondaryContainer;
        icon = Icons.hourglass_top_rounded;
      case _StatusKind.error:
        bgColor = colorScheme.errorContainer;
        fgColor = colorScheme.onErrorContainer;
        icon = Icons.error_outline;
      case _StatusKind.none:
        bgColor = colorScheme.surfaceContainerHighest;
        fgColor = colorScheme.onSurfaceVariant;
        icon = Icons.memory_outlined;
    }

    return GestureDetector(
      onTap: () => _showModelPicker(context, ref, selectedId),
      child: Container(
        height: 36,
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (status == _StatusKind.loading)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fgColor))
            else
              Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 8),
            Expanded(child: Text(modelName, style: theme.textTheme.labelMedium?.copyWith(color: fgColor, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            if (status == _StatusKind.ready) ...[
              Icon(Icons.shield, size: 12, color: fgColor.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text('On-device', style: theme.textTheme.labelSmall?.copyWith(color: fgColor.withValues(alpha: 0.7), fontSize: 10)),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, size: 16, color: fgColor),
            if (chatState.isGenerating) ...[
              const SizedBox(width: 4),
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: fgColor)),
              const SizedBox(width: 6),
              Text('Generating...', style: theme.textTheme.labelSmall?.copyWith(color: fgColor)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Build a combined list of known models from both the hardcoded registry
/// and the remote catalog, deduplicated by id.
List<ModelDefinition> _allKnownModels(WidgetRef ref) {
  final catalogService = ref.read(modelCatalogServiceProvider);
  final catalogModels = catalogService.catalog.allEntries
      .map((e) => catalogService.toModelDefinition(e))
      .toList();
  // Merge: registry first, then any catalog models not already present.
  final seen = <String>{};
  final result = <ModelDefinition>[];
  for (final m in [...ModelRegistry.all, ...catalogModels]) {
    if (seen.add(m.id)) result.add(m);
  }
  return result;
}

void _showModelPicker(BuildContext context, WidgetRef ref, String? currentId) {
  final provisioningService = ref.read(modelProvisioningServiceProvider);
  String? expandedModelId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: StreamBuilder<ModelProvisioningState>(
          stream: provisioningService.stream,
          initialData: ModelProvisioningState.empty(),
          builder: (context, snapshot) {
            final state = snapshot.data ?? ModelProvisioningState.empty();
            final allModels = _allKnownModels(ref);
            final visibleModels = allModels.where((model) {
              return state.installed.contains(model.id) || state.downloading.contains(model.id) || state.failed.contains(model.id);
            }).toList();

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
                      Text('${state.installed.length} installed', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
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
                  ...visibleModels.map((model) {
                    final installed = state.installed.contains(model.id);
                    final downloading = state.downloading.contains(model.id);
                    final failed = state.failed.contains(model.id);
                    final progress = state.progress[model.id] ?? 0.0;
                    final retryAttempt = state.retryAttempts[model.id];
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
                                  _ModelInfoChip(
                                    icon: Icons.memory_outlined,
                                    label: sizeLabel(model.size),
                                  ),
                                  const SizedBox(width: 6),
                                  _ModelInfoChip(
                                    icon: Icons.format_list_numbered,
                                    label: '${model.contextLength} ctx',
                                  ),
                                  const SizedBox(width: 6),
                                  _ModelInfoChip(
                                    icon: Icons.chat_bubble_outline,
                                    label: _templateName(model.chatTemplate),
                                  ),
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
                                IconButton(icon: const Icon(Icons.refresh, size: 18), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: () => provisioningService.retry(model)),
                              ],
                            ],
                          ),
                          onTap: () {
                            setSheetState(() {
                              expandedModelId = isExpanded ? null : model.id;
                            });
                          },
                        ),
                        // Expandable detail panel
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
                                      // Detail rows
                                      _DetailRow(label: 'Size', value: sizeLabel(model.size)),
                                      _DetailRow(label: 'Context', value: '${model.contextLength} tokens'),
                                      _DetailRow(label: 'Template', value: _templateName(model.chatTemplate)),
                                      _DetailRow(label: 'Parameters', value: _sizeDescription(model.size)),
                                      const SizedBox(height: 8),
                                      // Select button for installed models
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
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    ),
  );
}

enum _StatusKind { ready, loading, error, none }

// ── Model info helpers ──────────────────────────────────────


String _sizeDescription(ModelSize size) {
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

String _templateName(ChatTemplate template) {
  return template.runtimeType.toString().replaceAll('ChatTemplate', '');
}

class _ModelInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ModelInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: cs.outline),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, color: cs.outline)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

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
