import 'package:sutra/core/logging/log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sutra/core/storage/chat_repository.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/features/chat/file_picker_provider.dart';
import 'package:sutra/runtime/context/context_settings_provider.dart';
import 'package:sutra/runtime/memory/memory_extractor.dart';
import 'package:sutra/runtime/memory/memory_provider.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/provisioning/model_manager_provider.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';
import 'package:sutra/runtime/pipeline/context_builder.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';


/// Exposes [ChatState] which bundles messages + UI flags.
class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isModelLoading;
  final String? error;
  final String? activeSessionId;
  final int queuedCount;

  const ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.isModelLoading = false,
    this.error,
    this.activeSessionId,
    this.queuedCount = 0,
  });

  bool get isBusy => isGenerating || isModelLoading;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isGenerating,
    bool? isModelLoading,
    String? error,
    String? activeSessionId,
    bool clearError = false,
    bool clearSession = false,
    int? queuedCount,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      isModelLoading: isModelLoading ?? this.isModelLoading,
      error: clearError ? null : (error ?? this.error),
      activeSessionId:
          clearSession ? null : (activeSessionId ?? this.activeSessionId),
      queuedCount: queuedCount ?? this.queuedCount,
    );
  }
}

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

  /// Sessions for which a title has already been generated.
  final Set<String> _titledSessions = {};

  /// Queue of messages waiting to be sent while generation is in progress.
  final List<String> _messageQueue = [];

  /// Switch to a different conversation (or create a new one).
  Future<void> switchSession(String sessionId) async {
    // Cancel any in-flight generation and clear queue.
    _generatingSessionId = null;
    _messageQueue.clear();

    state = state.copyWith(
      isGenerating: false,
      activeSessionId: sessionId,
      queuedCount: 0,
    );

    final repo = ref.read(chatRepositoryProvider);
    final data = await repo.getMessages(sessionId);

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
          ),
        )
        .toList();

    state = state.copyWith(messages: messages);
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

    if (state.isGenerating || _busy) {
      _messageQueue.add(cleanedText);
      state = state.copyWith(queuedCount: _messageQueue.length);
      Log.d('[ChatNotifier] Message queued (${_messageQueue.length} pending)');
      return;
    }

    _pendingFileIds = selectedFileIds;
    _busy = true;
    _processMessage(cleanedText).whenComplete(() {
      _busy = false;
      _pendingFileIds = null;
    });
  }

  /// File IDs to include in the current message being processed.
  Set<String>? _pendingFileIds;

  /// Process the next queued message if any.
  void _processQueuedMessages() {
    if (_messageQueue.isEmpty) return;
    final next = _messageQueue.removeAt(0);
    state = state.copyWith(queuedCount: _messageQueue.length);
    Log.d('[ChatNotifier] Processing queued message (${_messageQueue.length} remaining)');
    _processMessage(next);
  }

  /// Select the best model for a prompt based on its characteristics.
  ///
  /// Rules:
  /// - Files attached → largest installed model with ≥4096 ctx
  /// - Long/complex messages (>200 chars) → largest installed model
  /// - Short messages → smallest installed model (fast response)
  /// - Always prefers the biggest available model if only one is installed
  String? _selectBestModel({required bool hasFiles, required int msgLength}) {
    final manager = ref.read(modelManagerProvider);
    final installed = manager.state.installedIds;
    if (installed.isEmpty) return null;

    final candidates = ModelRegistry.all
        .where((m) => installed.contains(m.id))
        .toList()
      ..sort((a, b) => b.contextLength.compareTo(a.contextLength));

    // Only one model installed — use it.
    if (candidates.length == 1) return candidates.first.id;

    // Files or long messages → use the biggest model.
    if (hasFiles || msgLength > 200) {
      return candidates.first.id;
    }

    // Short simple message → use a small/fast model.
    final small = candidates.lastWhere(
      (m) => m.contextLength <= 4096,
      orElse: () => candidates.last,
    );
    return small.id;
  }

  /// Core message processing logic — sends a message and generates a response.
  Future<void> _processMessage(String cleanedText) async {
    Log.d('[ChatNotifier] _processMessage: "$cleanedText"');

    // Auto-create a session if none is active.
    final sessionId = state.activeSessionId ?? await newSession(title: _autoTitle(cleanedText));

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
        effectiveId = _selectBestModel(
          hasFiles: hasFiles,
          msgLength: cleanedText.length,
        );
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

      final userMessage = ChatMessage(
        id: DateTime.now().toIso8601String(),
        sessionId: sessionId,
        text: cleanedText,
        role: ChatRole.user,
        createdAt: DateTime.now(),
      );

      final previousMessages = [...state.messages, userMessage];

      state = state.copyWith(messages: previousMessages);

      await repo.saveMessage({
        'id': userMessage.id,
        'sessionId': sessionId,
        'text': userMessage.text,
        'role': 'user',
        'createdAt': userMessage.createdAt.millisecondsSinceEpoch,
      });

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
              content = content.replaceAll(RegExp(r'<\|[^|]*\|>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
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
        chatHistory: previousMessages,
        userMessage: cleanedText,
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
      await for (final token
          in runtimeManager.generateStream(prompt)) {
        if (_generatingSessionId != genId) break;

        buffer += token;
        if (buffer.length <= token.length * 2) {
          Log.d('[ChatNotifier] First token(s) received: "${token.substring(0, token.length.clamp(0, 50))}"');
        }

        final index = state.messages
            .indexWhere((m) => m.id == genId);
        if (index == -1) continue;

        final newMessages = [...state.messages];
        newMessages[index] = ChatMessage(
          id: genId,
          sessionId: sessionId,
          text: buffer,
          role: ChatRole.assistant,
          createdAt: assistantPlaceholder.createdAt,
        );
        state = state.copyWith(messages: newMessages);
      }

      sw.stop();
      Log.d('[ChatNotifier] Generation complete in ${sw.elapsedMilliseconds}ms, ${buffer.length} chars');

      if (_generatingSessionId != genId) return;

      await repo.saveMessage({
        'id': genId,
        'sessionId': sessionId,
        'text': buffer,
        'role': 'assistant',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
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
      state = state.copyWith(
        isGenerating: false,
        isModelLoading: false,
      );

      if (wasAutoMode) {
        ref.read(selectedModelIdProvider.notifier).selectTemporary(null);
      }

      _processQueuedMessages();

      _maybeGenerateTitle(sessionId);
    }
  }

  /// After 2+ user messages, generate a concise title using the model.
  void _maybeGenerateTitle(String sessionId) async {
    // Don't generate a title if more messages are queued or generating.
    if (_messageQueue.isNotEmpty || state.isGenerating) return;

    // Don't re-generate if we already titled this session.
    if (_titledSessions.contains(sessionId)) return;

    final userMsgCount = state.messages
        .where((m) => m.role == ChatRole.user)
        .length;
    // Generate after the 2nd assistant reply (first real exchange).
    if (userMsgCount < 2) return;

    try {
      final repo = ref.read(chatRepositoryProvider);
      // Build a short transcript of the conversation.
      final transcript = state.messages
          .where((m) => m.text.isNotEmpty)
          .take(6) // first 3 exchanges max
          .map((m) => '${m.role == ChatRole.user ? 'User' : 'Assistant'}: ${m.text}')
          .join('\n');

      final titlePrompt = 'Generate a short conversation title (max 5 words) for this dialogue. Reply with ONLY the title, no quotes or extra text.\n\n$transcript';

      final runtimeManager = await ref.read(runtimeProvider.future);
      var title = '';
      await for (final token in runtimeManager.generateStream(titlePrompt)) {
        title += token;
        if (title.length > 60) break;
      }
      title = title.trim().replaceAll(RegExp(r'["\n]'), '');
      if (title.isEmpty) return;

      Log.d('[ChatNotifier] Generated title: "$title"');
      _titledSessions.add(sessionId);
      await repo.updateSessionTitle(sessionId, title);
    } catch (e) {
      Log.w('[ChatNotifier] Title generation failed: $e');
      // Mark as attempted to avoid retrying on every message.
      _titledSessions.add(sessionId);
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

  /// Auto-generate a title from the first user message.
  String _autoTitle(String text) {
    if (text.length <= 40) return text;
    return '${text.substring(0, 40)}…';
  }
}
