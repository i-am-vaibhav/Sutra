import 'dart:async';

import 'package:sutra/core/logging/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sutra/core/storage/chat_repository.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/features/chat/chat_state.dart';
import 'package:sutra/features/chat/citation_helpers.dart';
export 'package:sutra/features/chat/chat_state.dart';
import 'package:sutra/features/chat/file_picker_provider.dart';
import 'package:sutra/features/chat/model_selection.dart';
import 'package:sutra/features/chat/title_generator.dart';
import 'package:sutra/runtime/context/context_settings_provider.dart';
import 'package:sutra/runtime/memory/memory_extractor.dart';
import 'package:sutra/runtime/memory/memory_provider.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/provisioning/model_manager_provider.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';
import 'package:sutra/runtime/pipeline/context_builder.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';

// Pre-compiled RegExp constants — avoid re-creating on hot paths.
final _specialTokenRe = RegExp(r'<\|[^|]*\|>');
final _whitespaceRe = RegExp(r'\s+');

final chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>(
  (ref) => ChatNotifier(ref),
);

class ChatNotifier extends StateNotifier<ChatState> {
  final Ref ref;

  ChatNotifier(this.ref) : super(const ChatState());

  String? _generatingSessionId;

  /// Synchronous guard to prevent concurrent _processMessage calls.
  /// Set to true BEFORE any async gap in sendMessage() so a rapid
  /// double-tap cannot start two generations simultaneously.
  bool _busy = false;

  /// Debounce timer for streaming token updates — batches state
  /// notifications so the UI rebuilds ~20×/s instead of every token.
  Timer? _streamDebounceTimer;
  String _streamBuffer = '';
  String? _streamGenId;
  ChatMessage? _streamPlaceholder;

  /// Sessions for which a title has already been generated.
  final Set<String> _titledSessions = {};

  /// Queue of messages waiting to be sent while generation is in progress.
  final List<String> _messageQueue = [];

  /// Switch to a different conversation (or create a new one).
  /// Loads only the last [_pageSize] messages; older messages are
  /// loaded on demand when the user scrolls up.
  static const _pageSize = 50;

  Future<void> switchSession(String sessionId) async {
    // Cancel any in-flight generation and clear queue.
    _generatingSessionId = null;
    _messageQueue.clear();

    state = state.copyWith(
      isGenerating: false,
      activeSessionId: sessionId,
      queuedCount: 0,
      messages: [],
      hasMoreMessages: false,
      isLoadingOlder: false,
      totalMessageCount: 0,
    );

    final repo = ref.read(chatRepositoryProvider);
    final total = await repo.countMessages(sessionId);
    final data = await repo.getMessagesPaginated(sessionId, limit: _pageSize);

    final messages = data
        .map(
          (e) => ChatMessage(
            id: e['id'] as String,
            sessionId: sessionId,
            text: e['text'] as String,
            role: e['role'] == 'user'
                ? ChatRole.user
                : ChatRole.assistant,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              e['createdAt'] as int,
            ),
            quotedText: e['quotedText'] as String?,
            citations: decodeCitations(e['citations'] as String?),
            isWebSearch: (e['isWebSearch'] as int?) == 1,
          ),
        )
        .toList();

    final hasMore = total > _pageSize;
    state = state.copyWith(
      messages: messages,
      hasMoreMessages: hasMore,
      totalMessageCount: total,
    );
  }

  /// Load the next batch of older messages prepending them to the list.
  /// Returns the number of messages loaded so the UI can adjust scroll.
  Future<int> loadOlderMessages() async {
    if (state.isLoadingOlder || !state.hasMoreMessages) return 0;
    final sessionId = state.activeSessionId;
    if (sessionId == null) return 0;

    state = state.copyWith(isLoadingOlder: true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final oldestTimestamp = state.messages.isNotEmpty
          ? state.messages.first.createdAt.millisecondsSinceEpoch
          : DateTime.now().millisecondsSinceEpoch;

      final olderData = await repo.getMessagesBefore(
        sessionId,
        beforeTimestamp: oldestTimestamp,
        limit: _pageSize,
      );

      if (olderData.isEmpty) {
        state = state.copyWith(
          isLoadingOlder: false,
          hasMoreMessages: false,
        );
        return 0;
      }

      final olderMessages = olderData
          .map(
            (e) => ChatMessage(
              id: e['id'] as String,
              sessionId: sessionId,
              text: e['text'] as String,
              role: e['role'] == 'user'
                  ? ChatRole.user
                  : ChatRole.assistant,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                e['createdAt'] as int,
              ),
              quotedText: e['quotedText'] as String?,
              citations: decodeCitations(e['citations'] as String?),
              isWebSearch: (e['isWebSearch'] as int?) == 1,
            ),
          )
          .toList();

      state = state.copyWith(
        messages: [...olderMessages, ...state.messages],
        isLoadingOlder: false,
        hasMoreMessages: olderData.length >= _pageSize,
      );

      return olderMessages.length;
    } catch (e) {
      Log.w('[ChatNotifier] Failed to load older messages: $e');
      state = state.copyWith(isLoadingOlder: false);
      return 0;
    }
  }

  /// Create a new conversation and switch to it.
  Future<String> newSession({String? title}) async {
    final repo = ref.read(chatRepositoryProvider);
    final session = await repo.createSession(title: title);
    await switchSession(session.id);
    return session.id;
  }

  /// Delete a conversation.
  Future<void> deleteSession(String sessionId) async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.deleteSession(sessionId);

    // If we just deleted the active session, clear state.
    if (state.activeSessionId == sessionId) {
      state = state.copyWith(
        messages: [],
        clearSession: true,
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  void setQuote(String text, {String? messageId}) {
    final truncated = text.length > 300 ? '${text.substring(0, 300)}...' : text;
    state = state.copyWith(pendingQuote: truncated, pendingQuoteMessageId: messageId);
  }

  void clearQuote() {
    state = state.copyWith(clearQuote: true);
  }

  /// Stop the current generation in progress.
  /// Saves any partial response to the database so it persists.
  void stopGeneration() {
    final genId = _generatingSessionId;
    // Setting _generatingSessionId to a mismatched value causes
    // the streaming loop to break on the next token.
    _generatingSessionId = null;
    state = state.copyWith(isGenerating: false);

    // Save the partial response so it isn't lost on session reload.
    if (genId != null && state.activeSessionId != null) {
      final partial = state.messages
          .where((m) => m.id == genId && m.text.isNotEmpty)
          .map((m) => m.text)
          .firstOrNull;
      if (partial != null) {
        final repo = ref.read(chatRepositoryProvider);
        repo.saveMessage({
          'id': genId,
          'sessionId': state.activeSessionId!,
          'text': partial,
          'role': 'assistant',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });
        Log.d('[ChatNotifier] Saved partial response (${partial.length} chars) on interrupt');
      }
    }
  }

  /// Send a message. If generation is already in progress,
  /// the message is queued and sent after the current generation completes.
  void sendMessage(String text, {Set<String>? selectedFileIds}) {
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) return;

    final quote = state.pendingQuote;
    final quoteMessageId = state.pendingQuoteMessageId;
    state = state.copyWith(clearQuote: true);

    if (state.isGenerating || _busy) {
      _messageQueue.add(cleanedText);
      state = state.copyWith(queuedCount: _messageQueue.length);
      Log.d('[ChatNotifier] Message queued (${_messageQueue.length} pending)');
      return;
    }

    _pendingFileIds = selectedFileIds;
    _pendingQuote = quote;
    _pendingQuoteMessageId = quoteMessageId;
    _busy = true;
    _processMessage(cleanedText).whenComplete(() {
      _busy = false;
      _pendingFileIds = null;
      _pendingQuote = null;
      _pendingQuoteMessageId = null;
    });
  }

  /// File IDs to include in the current message being processed.
  Set<String>? _pendingFileIds;

  /// Quoted text to include in the current message being processed.
  String? _pendingQuote;

  /// ID of the quoted message, used to exclude it from history.
  String? _pendingQuoteMessageId;

  /// Process the next queued message if any.
  void _processQueuedMessages() {
    if (_messageQueue.isEmpty) return;
    final next = _messageQueue.removeAt(0);
    state = state.copyWith(queuedCount: _messageQueue.length);
    Log.d('[ChatNotifier] Processing queued message (${_messageQueue.length} remaining)');
    _processMessage(next);
  }

  /// Core message processing logic — sends a message and generates a response.
  Future<void> _processMessage(String cleanedText) async {
    Log.d('[ChatNotifier] _processMessage: "$cleanedText"');

    // Auto-create a session if none is active.
    final sessionId = state.activeSessionId ?? await newSession(title: autoTitle(cleanedText));

    final wasAutoMode = ref.read(selectedModelIdProvider) == null;

    state = state.copyWith(clearError: true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final memoryRepo = ref.read(memoryRepositoryProvider);
      final memoryExtractor = MemoryExtractor();
      final selectedId = ref.read(selectedModelIdProvider);
      final hasFiles = _pendingFileIds?.isNotEmpty == true;
      var effectiveId = selectedId;
      if (selectedId == null) {
        effectiveId = selectBestModel(ref, hasFiles: hasFiles, msgLength: cleanedText.length);
        Log.d('[ChatNotifier] Auto-selected model: $effectiveId');
        if (effectiveId != null) {
          ref.read(selectedModelIdProvider.notifier).selectTemporary(effectiveId);
        }
      }
      var modelDef = effectiveId != null
          ? ModelRegistry.all.where((m) => m.id == effectiveId).firstOrNull
          : ModelRegistry.all.firstOrNull;
      var contextBuilder = ContextBuilder(
        chatTemplate: modelDef?.chatTemplate ?? const GenericChatTemplate(),
      );

      final quote = _pendingQuote;
      final effectiveUserText = quote != null
          ? 'In reference to: "$quote"\n\n$cleanedText'
          : cleanedText;

      final userMessage = ChatMessage(
        id: DateTime.now().toIso8601String(),
        sessionId: sessionId,
        text: cleanedText,
        role: ChatRole.user,
        createdAt: DateTime.now(),
        quotedText: quote,
      );

      final previousMessages = [...state.messages, userMessage];

      state = state.copyWith(messages: previousMessages);

      await repo.saveMessage({
        'id': userMessage.id,
        'sessionId': sessionId,
        'text': userMessage.text,
        'role': 'user',
        'createdAt': userMessage.createdAt.millisecondsSinceEpoch,
        'quotedText': quote,
        'isWebSearch': 0,
      });

      // Exclude the quoted assistant message from history since it's already
      // referenced in the new user message via effectiveUserText.
      final quoteMsgId = _pendingQuoteMessageId;
      final historyForPrompt = quoteMsgId != null
          ? previousMessages.where((m) => m.id != quoteMsgId).toList()
          : previousMessages;

      final genId =
          DateTime.now().microsecondsSinceEpoch.toString();
      _generatingSessionId = genId;

      final assistantPlaceholder = ChatMessage(
        id: genId,
        sessionId: sessionId,
        text: '',
        role: ChatRole.assistant,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, assistantPlaceholder],
        isGenerating: true,
      );

      final contextSettings = ref.read(contextSettingsProvider);

      final memoryText = contextSettings.conversationMemoryEnabled
          ? (await memoryRepo.top(limit: 5))
              .map((m) => '- ${m.content}')
              .join('\n')
          : null;

      var ctxLen = modelDef?.contextLength ?? 2048;
      String? fileContent;
      final fileIds = _pendingFileIds;
      if (fileIds != null && fileIds.isNotEmpty) {
        final allFiles = ref.read(uploadedFilesProvider);
        final selectedFiles = allFiles.where((f) => fileIds.contains(f.id)).toList();
        if (selectedFiles.isNotEmpty) {
          if (ctxLen < 4096) {
            final manager = ref.read(modelManagerProvider);
            final installed = manager.state.installedIds;
            final bigger = ModelRegistry.all
                .where((m) => installed.contains(m.id) && m.contextLength >= 4096)
                .toList()
              ..sort((a, b) => b.contextLength.compareTo(a.contextLength));
            if (bigger.isNotEmpty) {
              final best = bigger.first;
              Log.d('[ChatNotifier] Using ${best.name} (${best.contextLength} ctx) for file attachment');
              modelDef = best;
              ctxLen = best.contextLength;
            }
          }
          final maxFileChars = (ctxLen * 4 * 0.4).toInt();
          final filesNotifier = ref.read(uploadedFilesProvider.notifier);
          final buf = StringBuffer('Attached files:');
          for (final file in selectedFiles) {
            buf.write('\n\n--- ${file.displayName} (${file.fileTypeLabel}) ---\n');
            try {
              var content = await filesNotifier.extractText(file);
              content = content.replaceAll(_specialTokenRe, ' ').replaceAll(_whitespaceRe, ' ').trim();
              if (content.length > maxFileChars) {
                content = '${content.substring(0, maxFileChars)}\n... [truncated to fit model context]';
              }
              buf.write(content);
            } catch (e) {
              buf.write('[Could not read file: $e]');
            }
            buf.write('\n---');
          }
          fileContent = buf.toString();
          if (fileContent.length > maxFileChars) {
            fileContent = '${fileContent.substring(0, maxFileChars)}\n... [truncated to fit model context]';
          }
        }
      }

      // Re-resolve the context builder with the final model's template.
      contextBuilder = ContextBuilder(
        chatTemplate: modelDef?.chatTemplate ?? const GenericChatTemplate(),
      );

      final systemPrompt = ref.read(systemPromptProvider);
      final prompt = contextBuilder.buildFullPrompt(
        systemPrompt: systemPrompt,
        chatHistory: historyForPrompt,
        userMessage: effectiveUserText,
        memoryText: memoryText,
        userProfileText: contextSettings.buildUserProfilePrompt(),
        fileContent: fileContent,
      );

      // Show loading state while the model initializes on a background isolate.
      state = state.copyWith(isModelLoading: true);
      Log.d('[ChatNotifier] Waiting for runtime...');
      final runtimeManager =
          await ref.read(runtimeProvider.future);
      Log.d('[ChatNotifier] Runtime ready: isReady=${runtimeManager.isReady}');
      state = state.copyWith(isModelLoading: false);
      var buffer = '';

      Log.d('[ChatNotifier] Starting generateStream...');
      final sw = Stopwatch()..start();

      // Set up debounced streaming updates.
      _streamBuffer = '';
      _streamGenId = genId;
      _streamPlaceholder = assistantPlaceholder;

      await for (final token
          in runtimeManager.generateStream(prompt)) {
        if (_generatingSessionId != genId) break;

        buffer += token;
        _streamBuffer = buffer;
        if (buffer.length <= token.length * 2) {
          Log.d('[ChatNotifier] First token(s) received: "${token.substring(0, token.length.clamp(0, 50))}"');
        }

        // Debounce: only flush to state every 50ms.
        if (_streamDebounceTimer?.isActive != true) {
          _streamDebounceTimer = Timer(const Duration(milliseconds: 50), () {
            _flushStreamBuffer(sessionId);
          });
        }
      }

      // Cancel debounce and flush any remaining tokens.
      _streamDebounceTimer?.cancel();
      _flushStreamBuffer(sessionId);

      sw.stop();
      Log.d('[ChatNotifier] Generation complete in ${sw.elapsedMilliseconds}ms, ${buffer.length} chars');

      if (_generatingSessionId != genId) return;

      await repo.saveMessage({
        'id': genId,
        'sessionId': sessionId,
        'text': buffer,
        'role': 'assistant',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'isWebSearch': 0,
      });

      final extractedMemories =
          memoryExtractor.extract(cleanedText, buffer);
      for (final memory in extractedMemories) {
        await memoryRepo.add(memory);
      }

      final finalIndex = state.messages
          .indexWhere((m) => m.id == genId);
      if (finalIndex != -1) {
        final finalMessages = [...state.messages];
        finalMessages[finalIndex] = ChatMessage(
          id: genId,
          sessionId: sessionId,
          text: buffer,
          role: ChatRole.assistant,
          createdAt: assistantPlaceholder.createdAt,
        );
        state = state.copyWith(
          messages: finalMessages,
          isGenerating: false,
        );
      } else {
        state = state.copyWith(isGenerating: false);
      }
    } catch (e, st) {
      Log.e('[ChatNotifier] ERROR: $e\n$st');
      final messages = [...state.messages];
      messages.removeWhere(
          (m) => m.role == ChatRole.assistant && m.text.isEmpty);

      state = state.copyWith(
        messages: messages,
        isModelLoading: false,
        error: 'Generation failed: $e',
      );
    } finally {
      _streamDebounceTimer?.cancel();
      _clearStreamState();
      state = state.copyWith(
        isGenerating: false,
        isModelLoading: false,
      );

      if (wasAutoMode) {
        ref.read(selectedModelIdProvider.notifier).selectTemporary(null);
      }

      _processQueuedMessages();

      maybeGenerateTitle(
        ref,
        sessionId: sessionId,
        messages: state.messages,
        isGenerating: state.isGenerating,
        titledSessions: _titledSessions,
      );
    }
  }

  /// Replace all messages in state (used for in-place message updates).
  void updateMessages(List<ChatMessage> messages) {
    state = state.copyWith(messages: messages);
  }

  /// Add a search agent response as an assistant message.
  void addSearchResponse(ChatMessage message) {
    final messages = [...state.messages, message];
    state = state.copyWith(messages: messages);

    // Persist to database (including citations as JSON).
    if (state.activeSessionId != null) {
      final repo = ref.read(chatRepositoryProvider);
      repo.saveMessage({
        'id': message.id,
        'sessionId': state.activeSessionId!,
        'text': message.text,
        'role': message.role == ChatRole.user ? 'user' : 'assistant',
        'createdAt': message.createdAt.millisecondsSinceEpoch,
        'citations': encodeCitations(message.citations),
        'isWebSearch': message.isWebSearch ? 1 : 0,
      });
    }
  }

  /// Delete a single message by id.
  Future<void> deleteMessage(String messageId) async {
    final repo = ref.read(chatRepositoryProvider);
    await repo.deleteMessage(messageId);

    final messages = [...state.messages];
    messages.removeWhere((m) => m.id == messageId);
    state = state.copyWith(messages: messages);
  }

  @override
  void dispose() {
    _streamDebounceTimer?.cancel();
    super.dispose();
  }

  /// Flush the accumulated streaming buffer to state (debounced).
  ///
  /// Uses List.from() to create a shallow copy, replacing only the
  /// single streaming message in-place.
  void _flushStreamBuffer(String sessionId) {
    final genId = _streamGenId;
    final ph = _streamPlaceholder;
    if (genId == null || ph == null) return;
    final text = _streamBuffer;
    if (text.isEmpty) return;

    final msgs = state.messages;
    final index = msgs.indexWhere((m) => m.id == genId);
    if (index == -1) return;

    // Only replace the single streaming message — reuse existing
    // ChatMessage objects for the rest of the list.
    final updated = ChatMessage(
      id: genId,
      sessionId: sessionId,
      text: text,
      role: ChatRole.assistant,
      createdAt: ph.createdAt,
    );
    final newMessages = List<ChatMessage>.from(msgs);
    newMessages[index] = updated;
    state = state.copyWith(messages: newMessages);
  }

  /// Clear streaming debounce state after generation completes.
  void _clearStreamState() {
    _streamGenId = null;
    _streamPlaceholder = null;
    _streamBuffer = '';
  }
}
