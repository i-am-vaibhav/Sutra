import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/features/chat/widgets/attachment_bar.dart';
import 'package:sutra/features/chat/widgets/attach_sheet.dart';
import 'package:sutra/features/chat/widgets/citation_card.dart';
import 'package:sutra/features/chat/widgets/empty_state.dart';
import 'package:sutra/features/chat/widgets/message_bubble.dart';
import 'package:sutra/features/chat/widgets/model_status_bar.dart';
import 'package:sutra/features/chat/widgets/quote_preview_bar.dart';
import 'package:sutra/features/chat/widgets/thinking_indicator.dart';

import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/search/search_agent.dart';
import 'package:sutra/runtime/search/search_result.dart';
import 'package:sutra/runtime/search/web_search_provider.dart';
import 'package:sutra/runtime/tts/tts_provider.dart';
import 'model_selection.dart';
import 'chat_provider.dart';
import 'conversation_list_screen.dart';
import 'file_picker_provider.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController controller = TextEditingController();
  final ScrollController scrollController = ScrollController();
  bool _showScrollDown = false;
  bool _autoScroll = true;
  bool _scrollTickPending = false;

  // ── Smart streaming TTS state ───────────────────────────
  Timer? _streamingReadTimer;
  String? _streamingReadMessageId;
  String _streamingReadBuffer = '';
  static const _streamingReadDelay = Duration(seconds: 2);
  static const _minCharsForStreamingTts = 200;
  int _streamingSpokenCharCount = 0;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    controller.dispose();
    scrollController.dispose();
    _streamingReadTimer?.cancel();
    _cleanupSearchStatusMessage();
    super.dispose();
  }

  /// Remove orphaned search status message if widget is disposed during search.
  void _cleanupSearchStatusMessage() {
    final statusId = _searchStatusMsgId;
    if (statusId != null) {
      ref.read(chatProvider.notifier).deleteMessage(statusId);
      _searchStatusMsgId = null;
    }
  }

  // ── Scroll management ───────────────────────────────────

  void _onScroll() {
    // Coalesce rapid scroll events into a single frame via
    // addPostFrameCallback so setState is called at most once per frame.
    if (_scrollTickPending) return;
    _scrollTickPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollTickPending = false;
      if (!mounted || !scrollController.hasClients) return;
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
        final isGen = ref.read(chatProvider).isGenerating;
        if (!isGen) FocusScope.of(context).unfocus();
      }
      if (!atBottom && _streamingReadTimer?.isActive == true) {
        _streamingReadTimer?.cancel();
      }
      if (currentScroll < 200) {
        _loadOlderIfNeeded();
      }
    });
  }

  bool _isNearBottom([double threshold = 100]) {
    if (!scrollController.hasClients) return true;
    return scrollController.position.pixels >= scrollController.position.maxScrollExtent - threshold;
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

  Future<void> _loadOlderIfNeeded() async {
    final chatState = ref.read(chatProvider);
    if (!chatState.hasMoreMessages || chatState.isLoadingOlder) return;

    final prevMaxScroll = scrollController.hasClients ? scrollController.position.maxScrollExtent : 0.0;
    final prevPixels = scrollController.hasClients ? scrollController.position.pixels : 0.0;

    final loaded = await ref.read(chatProvider.notifier).loadOlderMessages();
    if (loaded > 0 && scrollController.hasClients) {
      final newMaxScroll = scrollController.position.maxScrollExtent;
      final scrollDelta = newMaxScroll - prevMaxScroll;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollController.hasClients) {
          scrollController.jumpTo(prevPixels + scrollDelta);
        }
      });
    }
  }

  // ── Message sending ─────────────────────────────────────

  void sendMessage() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;

    _autoScroll = true;
    final selectedIds = ref.read(selectedFileIdsProvider);
    final searchEnabled = ref.read(webSearchProvider).enabled;
    final isAutoMode = ref.read(selectedModelIdProvider) == null;

    ref.read(selectedFileIdsProvider.notifier).clear();
    controller.clear();
    _scrollToBottom();

    // Auto mode: if a web search model is installed, automatically
    // route through web search without the user needing to toggle it.
    final shouldSearch = searchEnabled || (isAutoMode && hasInstalledWebSearchModel(ref));

    if (shouldSearch) {
      await _runWebSearch(text);
    } else {
      ref.read(chatProvider.notifier).sendMessage(text, selectedFileIds: selectedIds);
    }
  }

  /// ID of the in-progress search status message in chat.
  String? _searchStatusMsgId;

  Future<void> _runWebSearch(String query) async {
    Log.d('[ChatScreen] _runWebSearch START: "$query"');
    final searchNotifier = ref.read(webSearchProvider.notifier);

    var chatState = ref.read(chatProvider);
    if (chatState.activeSessionId == null) {
      await ref.read(chatProvider.notifier).newSession();
      chatState = ref.read(chatProvider);
    }
    final sessionId = chatState.activeSessionId!;

    ref.read(chatProvider.notifier).addSearchResponse(ChatMessage(
      id: DateTime.now().toIso8601String(),
      sessionId: sessionId,
      text: query,
      role: ChatRole.user,
      createdAt: DateTime.now(),
      isWebSearch: true,
    ));

    // Add an initial status message to chat.
    final statusMsgId = 'search_status_${DateTime.now().microsecondsSinceEpoch}';
    _searchStatusMsgId = statusMsgId;
    ref.read(chatProvider.notifier).addSearchResponse(ChatMessage(
      id: statusMsgId,
      sessionId: sessionId,
      text: '',
      role: ChatRole.assistant,
      createdAt: DateTime.now(),
      searchStatus: SearchAgentStatus.analyzing,
      searchResults: const [],
    ));

    // Note: search status listening is handled in build() via ref.listen
    // to comply with Riverpod lifecycle rules.

    try {
      final result = await searchNotifier.runSearch(query);

      if (!mounted) return;

      // Remove the status message.
      _cleanupSearchStatusMessage();

      // Check if the search was cancelled by user.
      final searchState = ref.read(webSearchProvider);
      if (searchState.status == SearchAgentStatus.error &&
          searchState.error == 'Search cancelled.') {
        ref.read(chatProvider.notifier).addSearchResponse(ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sessionId: sessionId,
          text: '⏹️ Search cancelled.',
          role: ChatRole.assistant,
          createdAt: DateTime.now(),
        ));
        return;
      }

      if (result == null) {
        final errorMsg = searchState.error ?? 'Search failed. Please try again.';
        Log.e('[ChatScreen] Web search failed: $errorMsg');
        ref.read(chatProvider.notifier).addSearchResponse(ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sessionId: sessionId,
          text: '⚠️ $errorMsg',
          role: ChatRole.assistant,
          createdAt: DateTime.now(),
        ));
        return;
      }

      if (result.answer.isNotEmpty) {
        ref.read(chatProvider.notifier).addSearchResponse(ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sessionId: sessionId,
          text: result.answer,
          role: ChatRole.assistant,
          createdAt: DateTime.now(),
          citations: result.citations.isNotEmpty ? result.citations : null,
        ));
      } else {
        ref.read(chatProvider.notifier).addSearchResponse(ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sessionId: sessionId,
          text: '⚠️ No results found for your query.',
          role: ChatRole.assistant,
          createdAt: DateTime.now(),
        ));
      }
    } catch (e) {
      Log.e('[ChatScreen] Web search exception: $e');
      if (!mounted) return;
      _cleanupSearchStatusMessage();
      ref.read(chatProvider.notifier).addSearchResponse(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sessionId: sessionId,
        text: '⚠️ Search error: $e',
        role: ChatRole.assistant,
        createdAt: DateTime.now(),
      ));
    }
  }

  /// Update the search status card in chat with latest status and sources.
  /// Uses List.from to avoid spreading the full message list.
  void _updateSearchStatusCard(
    String sessionId,
    SearchAgentStatus status,
    String statusLabel,
    List<SearchResult> searchResults,
  ) {
    final msgs = ref.read(chatProvider).messages;
    final idx = msgs.indexWhere((m) => m.id == _searchStatusMsgId);
    if (idx == -1) return;
    final old = msgs[idx];
    final newMsgs = List<ChatMessage>.from(msgs);
    newMsgs[idx] = ChatMessage(
      id: old.id,
      sessionId: sessionId,
      text: '',
      role: old.role,
      createdAt: old.createdAt,
      searchStatus: status,
      searchResults: searchResults.isNotEmpty ? searchResults : old.searchResults,
    );
    ref.read(chatProvider.notifier).updateMessages(newMsgs);
  }

  // ── Smart streaming TTS ─────────────────────────────────

  void _handleStreamingTts(List<ChatMessage> messages) {
    final ttsState = ref.read(ttsProvider);
    if (!ttsState.isEnabled) return;

    ChatMessage? lastAssistant;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == ChatRole.assistant) {
        lastAssistant = messages[i];
        break;
      }
    }
    if (lastAssistant == null || lastAssistant.text.isEmpty) return;

    if (_streamingReadMessageId != lastAssistant.id) {
      _streamingReadMessageId = lastAssistant.id;
      _streamingReadBuffer = lastAssistant.text;
      _streamingSpokenCharCount = 0;
      _scheduleStreamingRead(lastAssistant.id);
      return;
    }

    _streamingReadBuffer = lastAssistant.text;
    if (_streamingSpokenCharCount == 0) {
      _scheduleStreamingRead(lastAssistant.id);
    }
  }

  void _scheduleStreamingRead(String messageId) {
    _streamingReadTimer?.cancel();
    _streamingReadTimer = Timer(_streamingReadDelay, () {
      if (!mounted || !_autoScroll) return;
      final currentText = _streamingReadBuffer;
      if (currentText.length >= _minCharsForStreamingTts) {
        _streamingSpokenCharCount = currentText.length;
        ref.read(ttsProvider.notifier).speakMessage(messageId, currentText);
      }
    });
  }

  void _handleGenerationComplete(ChatState chatState) {
    final ttsState = ref.read(ttsProvider);
    if (!ttsState.isEnabled) return;

    _streamingReadTimer?.cancel();

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
      ref.read(ttsProvider.notifier).speakMessage(lastAssistant.id, fullText);
    } else if (_streamingSpokenCharCount == 0) {
      ref.read(ttsProvider.notifier).speakMessage(lastAssistant.id, fullText);
    } else if (fullText.length > _streamingSpokenCharCount + 50) {
      ref.read(ttsProvider.notifier).speakMessage(lastAssistant.id, fullText);
    }

    _streamingReadMessageId = null;
    _streamingReadBuffer = '';
    _streamingSpokenCharCount = 0;
  }

  // ── Message actions sheet ───────────────────────────────

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const AttachSheetContent(),
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
                  ttsState.speakingMessageId == msg.id ? Icons.stop_circle : Icons.volume_up,
                ),
                title: Text(
                  ttsState.speakingMessageId == msg.id ? 'Stop reading' : 'Read aloud',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  ttsNotifier.speakMessage(msg.id, msg.text);
                },
              ),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(ctx).pop();
                ref.read(chatProvider.notifier).setQuote(msg.text, messageId: msg.id);
                controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: controller.text.length),
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
                    final prevUser = messages.sublist(0, msgIndex).lastWhere(
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

  // ── Build ───────────────────────────────────────────────

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

    // Listen to search status changes and update the status card in chat.
    ref.listen<WebSearchState>(webSearchProvider, (prev, next) {
      if (!mounted || _searchStatusMsgId == null) return;
      final sid = _searchStatusMsgId;
      if (sid == null) return;
      final chatState = ref.read(chatProvider);
      if (chatState.activeSessionId == null) return;
      _updateSearchStatusCard(
        chatState.activeSessionId!,
        next.status,
        next.statusLabel,
        next.searchResults,
      );
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
        bottom: const ModelStatusBar(),
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
            if (chatState.isModelLoading || chatState.queuedCount > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                color: colorScheme.secondaryContainer,
                child: Row(
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5)),
                    const SizedBox(width: 8),
                    Text(
                      chatState.isModelLoading
                          ? 'Preparing model…'
                          : '${chatState.queuedCount} message${chatState.queuedCount > 1 ? 's' : ''} queued',
                      style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSecondaryContainer),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: messages.isEmpty
                  ? EmptyState(colorScheme: colorScheme, theme: theme)
                  : _MessageList(
                      messages: messages,
                      chatState: chatState,
                      scrollController: scrollController,
                      colorScheme: colorScheme,
                      ttsState: ttsState,
                      showScrollDown: _showScrollDown,
                      onScrollToBottom: _scrollToBottom,
                      onReply: (msg) {
                        ref.read(chatProvider.notifier).setQuote(msg.text, messageId: msg.id);
                        controller.selection = TextSelection.fromPosition(
                          TextPosition(offset: controller.text.length),
                        );
                      },
                      onLongPress: _showMessageActions,
                      onReadAloud: (id, text) => ref.read(ttsProvider.notifier).speakMessage(id, text),
                      onStopSpeaking: () => ref.read(ttsProvider.notifier).stop(),
                    ),
            ),
            QuotePreviewBar(colorScheme: colorScheme),
            AttachmentBar(colorScheme: colorScheme),
            _InputBar(
              chatState: chatState,
              searchState: ref.watch(webSearchProvider),
              colorScheme: colorScheme,
              theme: theme,
              controller: controller,
              onSend: sendMessage,
              onAttach: _showAttachSheet,
              onStopGeneration: () => ref.read(chatProvider.notifier).stopGeneration(),
              onCancelSearch: () => ref.read(webSearchProvider.notifier).cancelSearch(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Message list (extracted for readability) ──────────────

class _MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ChatState chatState;
  final ScrollController scrollController;
  final ColorScheme colorScheme;
  final TtsState ttsState;
  final bool showScrollDown;
  final VoidCallback onScrollToBottom;
  final ValueChanged<ChatMessage> onReply;
  final void Function(ChatMessage) onLongPress;
  final void Function(String messageId, String text) onReadAloud;
  final VoidCallback onStopSpeaking;

  const _MessageList({
    required this.messages,
    required this.chatState,
    required this.scrollController,
    required this.colorScheme,
    required this.ttsState,
    required this.showScrollDown,
    required this.onScrollToBottom,
    required this.onReply,
    required this.onLongPress,
    required this.onReadAloud,
    required this.onStopSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    // Precompute the index of the last assistant message once,
    // so only that message shows streaming indicators.
    final lastAssistantIndex = messages.lastIndexWhere((m) => m.role == ChatRole.assistant);

    return Stack(
      children: [
        ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: messages.length + (chatState.isLoadingOlder ? 1 : 0),
          physics: const AlwaysScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            if (chatState.isLoadingOlder && index == 0) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            final msgIndex = chatState.isLoadingOlder ? index - 1 : index;
            final msg = messages[msgIndex];
            final isUser = msg.role == ChatRole.user;

            // Only the LAST assistant message should show streaming indicators.
            final isLastAssistant = !isUser &&
                msgIndex == lastAssistantIndex;
            final isStreaming = chatState.isGenerating && isLastAssistant && msg.text.isEmpty;
            final usePlainText = chatState.isGenerating && isLastAssistant && msg.text.isNotEmpty;
            final showActions = !isUser && msg.text.isNotEmpty && !chatState.isGenerating;

            return KeyedSubtree(
              key: ValueKey(msg.id),
              child: SwipeToReplyWrapper(
                msg: msg,
                colorScheme: colorScheme,
                onReply: () => onReply(msg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: () => onLongPress(msg),
                      child: MessageBubble(
                        msg: msg,
                        colorScheme: colorScheme,
                        isStreaming: isStreaming,
                        usePlainText: usePlainText,
                      ),
                    ),
                    if (!isUser && msg.citations != null && msg.citations!.isNotEmpty)
                      CitationBar(citations: msg.citations!),
                    if (showActions)
                      MessageActions(
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
                        onReadAloud: () => onReadAloud(msg.id, msg.text),
                        onStopReading: onStopSpeaking,
                        isSpeaking: ttsState.isSpeaking && ttsState.speakingMessageId == msg.id,
                      ),
                    if (msg.isWebSearch && !msg.isSearchStatus)
                      Padding(
                        padding: const EdgeInsets.only(top: 2, left: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.language, size: 11, color: colorScheme.tertiary),
                            const SizedBox(width: 3),
                            Text(
                              'Web search',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.tertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        if (showScrollDown)
          Positioned(
            bottom: 8,
            right: 8,
            child: FloatingActionButton.small(
              onPressed: onScrollToBottom,
              child: const Icon(Icons.arrow_downward),
            ),
          ),
      ],
    );
  }
}

// ── Input bar (extracted for readability) ─────────────────

class _InputBar extends StatelessWidget {
  final ChatState chatState;
  final WebSearchState searchState;
  final ColorScheme colorScheme;
  final ThemeData theme;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onStopGeneration;
  final VoidCallback onCancelSearch;

  const _InputBar({
    required this.chatState,
    required this.searchState,
    required this.colorScheme,
    required this.theme,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.onStopGeneration,
    required this.onCancelSearch,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4), width: 0.5),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: chatState.isModelLoading || searchState.isBusy ? null : onAttach,
                    icon: Icon(Icons.add, color: colorScheme.onSurfaceVariant, size: 22),
                    tooltip: 'Attach or search',
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: !chatState.isModelLoading && !searchState.isBusy,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: chatState.isModelLoading
                          ? 'Loading model...'
                          : searchState.isBusy
                              ? 'Searching... (tap ⏹ to stop)'
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
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    begin: colorScheme.primary,
                    end: chatState.isModelLoading
                        ? colorScheme.surfaceContainerHighest
                        : searchState.isBusy
                            ? colorScheme.error
                            : chatState.isGenerating
                                ? colorScheme.error
                                : colorScheme.primary,
                  ),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  builder: (context, color, _) => Container(
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    child: IconButton(
                      onPressed: chatState.isModelLoading
                          ? null
                          : searchState.isBusy
                              ? onCancelSearch
                              : chatState.isGenerating
                                  ? onStopGeneration
                                  : onSend,
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: chatState.isModelLoading
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : (searchState.isBusy || chatState.isGenerating)
                                ? const Icon(Icons.stop, key: ValueKey<String>('stop'), color: Colors.white)
                                : Icon(Icons.arrow_upward, key: const ValueKey<String>('send'), color: colorScheme.onPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
