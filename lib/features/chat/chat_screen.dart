import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/runtime/models/model_catalog_service_provider.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/provisioning/model_database.dart';
import 'package:sutra/runtime/provisioning/model_manager.dart';
import 'package:sutra/runtime/provisioning/model_manager_provider.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';
import 'package:sutra/runtime/tts/tts_provider.dart';
import 'file_picker_provider.dart';
import 'uploaded_file.dart';
import 'chat_provider.dart';
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

  /// When true, the list auto-scrolls to bottom on new content.
  /// Disabled when the user manually scrolls up, re-enabled when
  /// they scroll back to the bottom edge.
  bool _autoScroll = true;

  // ── Smart streaming read state ───────────────────────────
  Timer? _streamingReadTimer;
  String? _streamingReadMessageId;
  String _streamingReadBuffer = '';
  static const _streamingReadDelay = Duration(seconds: 2);
  /// Minimum characters before we allow streaming TTS to speak.
  static const _minCharsForStreamingTts = 200;
  /// Track how many characters were already spoken during streaming
  /// so we don't re-read a short snippet when generation completes.
  int _streamingSpokenCharCount = 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    final atBottom = currentScroll >= maxScroll - 80;

    if (atBottom != _showScrollDown) {
      setState(() => _showScrollDown = !atBottom);
    }

    if (atBottom && !_autoScroll) {
      setState(() => _autoScroll = true);
    }
    if (!atBottom && _autoScroll) {
      _autoScroll = false;
    }

    if (!atBottom && _streamingReadTimer?.isActive == true) {
      _streamingReadTimer?.cancel();
    }
  }

  void sendMessage() {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    _autoScroll = true;
    final selectedIds = ref.read(selectedFileIdsProvider);
    ref.read(chatProvider.notifier).sendMessage(text, selectedFileIds: selectedIds);
    ref.read(selectedFileIdsProvider.notifier).clear();
    controller.clear();
    _scrollToBottom();
  }

  /// Whether the scroll position is within [threshold] pixels of the bottom.
  bool _isNearBottom([double threshold = 100]) {
    if (!scrollController.hasClients) return true;
    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;
    return currentScroll >= maxScroll - threshold;
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

  // ── Smart streaming TTS ──────────────────────────────────

  /// Called whenever messages update during streaming.
  /// Accumulates text and speaks it only after enough tokens have arrived.
  void _handleStreamingTts(List<ChatMessage> messages) {
    final ttsState = ref.read(ttsProvider);
    if (!ttsState.isEnabled) return;

    // Find the last assistant message that's being generated.
    ChatMessage? lastAssistant;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == ChatRole.assistant) {
        lastAssistant = messages[i];
        break;
      }
    }

    if (lastAssistant == null || lastAssistant.text.isEmpty) return;

    // Check if this is a new message being streamed.
    if (_streamingReadMessageId != lastAssistant.id) {
      // New streaming message — start accumulating.
      _streamingReadMessageId = lastAssistant.id;
      _streamingReadBuffer = lastAssistant.text;
      _streamingSpokenCharCount = 0;
      _scheduleStreamingRead(lastAssistant.id);
      return;
    }

    // Same message — update buffer and reschedule if not yet spoken.
    _streamingReadBuffer = lastAssistant.text;
    if (_streamingSpokenCharCount == 0) {
      _scheduleStreamingRead(lastAssistant.id);
    }
  }

  void _scheduleStreamingRead(String messageId) {
    _streamingReadTimer?.cancel();
    _streamingReadTimer = Timer(_streamingReadDelay, () {
      if (!mounted) return;
      // Don't speak if user has scrolled away from the bottom.
      if (!_autoScroll) return;
      final currentText = _streamingReadBuffer;
      // Only speak if we have enough content — don't read a tiny fragment.
      if (currentText.length >= _minCharsForStreamingTts) {
        _streamingSpokenCharCount = currentText.length;
        ref.read(ttsProvider.notifier).speakMessage(messageId, currentText);
      }
    });
  }

  /// Called when generation completes — speaks the full response if
  /// we haven't already read it (or if we only read a small fragment
  /// during streaming, speak the complete version).
  void _handleGenerationComplete(ChatState chatState) {
    final ttsState = ref.read(ttsProvider);
    if (!ttsState.isEnabled) return;

    // Cancel any pending streaming read.
    _streamingReadTimer?.cancel();

    // Find the last assistant message.
    ChatMessage? lastAssistant;
    for (int i = chatState.messages.length - 1; i >= 0; i--) {
      if (chatState.messages[i].role == ChatRole.assistant) {
        lastAssistant = chatState.messages[i];
        break;
      }
    }

    if (lastAssistant == null || lastAssistant.text.isEmpty) {
      _streamingReadMessageId = null;
      _streamingReadBuffer = '';
      _streamingSpokenCharCount = 0;
      return;
    }

    final fullText = lastAssistant.text;
    final wasStreamingForThisMsg = _streamingReadMessageId == lastAssistant.id;

    if (!wasStreamingForThisMsg) {
      // New message we haven't been tracking — speak the full thing.
      ref.read(ttsProvider.notifier).speakMessage(lastAssistant.id, fullText);
    } else if (_streamingSpokenCharCount == 0) {
      // We tracked it but never had enough tokens to speak — speak now.
      ref.read(ttsProvider.notifier).speakMessage(lastAssistant.id, fullText);
    } else if (fullText.length > _streamingSpokenCharCount + 50) {
      // We spoke a fragment during streaming but the final response is
      // significantly longer — speak the complete version.
      ref.read(ttsProvider.notifier).speakMessage(lastAssistant.id, fullText);
    }
    // Otherwise: the streaming read already covered the full response.

    _streamingReadMessageId = null;
    _streamingReadBuffer = '';
    _streamingSpokenCharCount = 0;
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    _streamingReadTimer?.cancel();
    super.dispose();
  }

  // ── File attachment sheet ──────────────────────────────

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AttachSheetContent(parentContext: context),
    );
  }

  void _showMessageActions(ChatMessage msg) {
    final isUser = msg.role == ChatRole.user;
    final ttsState = ref.read(ttsProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);

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
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            if (!isUser && msg.text.isNotEmpty)
              ListTile(
                leading: Icon(
                  ttsState.speakingMessageId == msg.id
                      ? Icons.stop_circle
                      : Icons.volume_up,
                ),
                title: Text(
                  ttsState.speakingMessageId == msg.id
                      ? 'Stop reading'
                      : 'Read aloud',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ttsNotifier.speakMessage(msg.id, msg.text);
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
    final ttsState = ref.watch(ttsProvider);

    ref.listen(chatProvider, (prev, next) {
      if (!mounted) return;

      if (prev?.activeSessionId != next.activeSessionId) {
        _streamingReadMessageId = null;
        _streamingReadBuffer = '';
        _streamingReadTimer?.cancel();
        ref.read(ttsProvider.notifier).stop();
      }

      if (_autoScroll && _isNearBottom()) {
        _scrollToBottom();
      }

      if (next.isGenerating) {
        _handleStreamingTts(next.messages);
      } else if (_streamingReadMessageId != null) {
        _handleGenerationComplete(next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sutra'),
        actions: [
          if (ttsState.isSpeaking)
            IconButton(
              icon: const Icon(Icons.stop_circle),
              tooltip: 'Stop reading',
              onPressed: () => ref.read(ttsProvider.notifier).stop(),
            ),
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
      body: Listener(
        onPointerDown: (_) => ScaffoldMessenger.of(context).clearSnackBars(),
        child: Column(
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
          if (chatState.queuedCount > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: colorScheme.secondaryContainer,
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${chatState.queuedCount} message${chatState.queuedCount > 1 ? 's' : ''} queued',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
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
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          final isUser = msg.role == ChatRole.user;
                          final isStreaming = chatState.isGenerating &&
                              !isUser &&
                              msg.text.isEmpty;
                          final usePlainText = chatState.isGenerating &&
                              !isUser &&
                              msg.text.isNotEmpty;

                          final showActions = !isUser &&
                              msg.text.isNotEmpty &&
                              !chatState.isGenerating;

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
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
                              ),
                              if (showActions)
                                _MessageActions(
                                  message: msg,
                                  colorScheme: colorScheme,
                                  onCopy: () {
                                    Clipboard.setData(ClipboardData(text: msg.text));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Copied to clipboard'),
                                        duration: Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  onReadAloud: () {
                                    ref.read(ttsProvider.notifier).speakMessage(msg.id, msg.text);
                                  },
                                  onStopReading: () {
                                    ref.read(ttsProvider.notifier).stop();
                                  },
                                  isSpeaking: ttsState.isSpeaking && ttsState.speakingMessageId == msg.id,
                                ),
                            ],
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
          _AttachedFilesBar(colorScheme: colorScheme),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4), width: 0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // ── Attach / Add button ──
                  Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: chatState.isModelLoading ? null : _showAttachSheet,
                      icon: Icon(Icons.add, color: colorScheme.onSurfaceVariant, size: 22),
                      tooltip: 'Attach file',
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !chatState.isModelLoading,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: chatState.isModelLoading
                            ? 'Loading model...'
                            : chatState.isGenerating
                                ? 'Generating... (tap stop to interrupt)'
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
                      color: chatState.isModelLoading
                          ? colorScheme.surfaceContainerHighest
                          : chatState.isGenerating
                              ? colorScheme.error
                              : colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: chatState.isModelLoading
                          ? null
                          : chatState.isGenerating
                              ? () => ref.read(chatProvider.notifier).stopGeneration()
                              : sendMessage,
                      icon: chatState.isModelLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : chatState.isGenerating
                              ? Icon(Icons.stop, color: colorScheme.onError)
                              : Icon(Icons.arrow_upward, color: colorScheme.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

// ── Attached Files Bar ────────────────────────────────────

class _AttachedFilesBar extends ConsumerWidget {
  final ColorScheme colorScheme;
  const _AttachedFilesBar({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectedFileIdsProvider);
    if (selectedIds.isEmpty) return const SizedBox.shrink();

    final allFiles = ref.watch(uploadedFilesProvider);
    final selected = allFiles.where((f) => selectedIds.contains(f.id)).toList();
    if (selected.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selected.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final file = selected[index];
          return Chip(
            avatar: Icon(_iconForExtension(file.extension), size: 14, color: colorScheme.primary),
            label: Text(
              file.name,
              style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
            deleteIcon: Icon(Icons.close, size: 14, color: colorScheme.outline),
            onDeleted: () {
              ref.read(selectedFileIdsProvider.notifier).toggle(file.id);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.only(left: 2),
            backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          );
        },
      ),
    );
  }
}

IconData _iconForExtension(String ext) {
  return switch (ext.toLowerCase()) {
    '.pdf' => Icons.picture_as_pdf,
    '.docx' || '.doc' => Icons.description,
    '.json' => Icons.data_object,
    '.csv' => Icons.table_chart,
    _ => Icons.insert_drive_file,
  };
}

// ── Attach Sheet ─────────────────────────────────────────

class _AttachSheetContent extends ConsumerWidget {
  final BuildContext parentContext;
  const _AttachSheetContent({required this.parentContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFiles = ref.watch(uploadedFilesProvider);
    final selectedIds = ref.watch(selectedFileIdsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(Icons.attach_file, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Attach Files', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (selectedIds.isNotEmpty)
                  Text(
                    '${selectedIds.length} selected',
                    style: TextStyle(fontSize: 12, color: colorScheme.primary),
                  ),
              ],
            ),
          ),
          // ── Upload new file button ──
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.upload_file, size: 20, color: colorScheme.primary),
            ),
            title: const Text('Upload new file'),
            subtitle: Text(
              'TXT, JSON, CSV, PDF, DOCX, DOC',
              style: TextStyle(fontSize: 11, color: colorScheme.outline),
            ),
            onTap: () async {
              Navigator.pop(context);
              final file = await ref.read(uploadedFilesProvider.notifier).addFile();
              if (file != null) {
                ref.read(selectedFileIdsProvider.notifier).toggle(file.id);
              }
            },
          ),
          const Divider(height: 1),
          // ── Existing files list ──
          if (allFiles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.folder_open, size: 36, color: colorScheme.outline),
                  const SizedBox(height: 8),
                  Text('No files uploaded yet', style: TextStyle(color: colorScheme.outline)),
                  const SizedBox(height: 4),
                  Text(
                    'Upload files above to attach them to messages',
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allFiles.length,
                itemBuilder: (_, index) {
                  final file = allFiles[index];
                  final isSelected = selectedIds.contains(file.id);
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isSelected ? colorScheme.primary : colorScheme.outline)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isSelected ? Icons.check_circle : _iconForExtension(file.extension),
                        size: 18,
                        color: isSelected ? colorScheme.primary : colorScheme.outline,
                      ),
                    ),
                    title: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      '${file.fileTypeLabel} · ${file.sizeLabel}',
                      style: TextStyle(fontSize: 11, color: colorScheme.outline),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error.withValues(alpha: 0.7)),
                      tooltip: 'Delete file',
                      onPressed: () => _confirmDeleteFile(context, ref, file),
                    ),
                    onTap: () {
                      ref.read(selectedFileIdsProvider.notifier).toggle(file.id);
                    },
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _confirmDeleteFile(BuildContext context, WidgetRef ref, UploadedFile file) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 28),
        title: const Text('Delete file?'),
        content: Text(
          'Remove "${file.name}" from uploads? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(selectedFileIdsProvider.notifier).toggle(file.id);
              ref.read(uploadedFilesProvider.notifier).removeFile(file.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Message Action Buttons ────────────────────────────────

class _MessageActions extends StatelessWidget {
  final ChatMessage message;
  final ColorScheme colorScheme;
  final VoidCallback onCopy;
  final VoidCallback onReadAloud;
  final VoidCallback onStopReading;
  final bool isSpeaking;

  const _MessageActions({
    required this.message,
    required this.colorScheme,
    required this.onCopy,
    required this.onReadAloud,
    required this.onStopReading,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _ActionChip(
            icon: Icons.copy,
            label: 'Copy',
            onTap: onCopy,
            colorScheme: colorScheme,
          ),
          const SizedBox(width: 8),
          _ActionChip(
            icon: isSpeaking ? Icons.stop_circle : Icons.volume_up,
            label: isSpeaking ? 'Stop' : 'Read aloud',
            onTap: isSpeaking ? onStopReading : onReadAloud,
            colorScheme: colorScheme,
            isActive: isSpeaking,
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isActive;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.colorScheme,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? colorScheme.primary : colorScheme.outline),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
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

    final isAuto = selectedId == null;
    String modelName;
    if (isAuto) {
      modelName = 'Auto';
    } else {
      final allModels = _allKnownModels(ref);
      final model = allModels.firstWhere((m) => m.id == selectedId, orElse: () => allModels.first);
      modelName = model.name;
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

    if (isAuto) {
      bgColor = colorScheme.tertiaryContainer;
      fgColor = colorScheme.onTertiaryContainer;
      icon = Icons.auto_awesome;
    } else {
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

List<ModelDefinition> _allKnownModels(WidgetRef ref) {
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

void _showModelPicker(BuildContext context, WidgetRef ref, String? currentId) {
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
            final allModels = _allKnownModels(ref);
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
                                      _DetailRow(label: 'Size', value: sizeLabel(model.size)),
                                      _DetailRow(label: 'Context', value: '${model.contextLength} tokens'),
                                      _DetailRow(label: 'Template', value: _templateName(model.chatTemplate)),
                                      _DetailRow(label: 'Parameters', value: _sizeDescription(model.size)),
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

enum _StatusKind { ready, loading, error, none }

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
