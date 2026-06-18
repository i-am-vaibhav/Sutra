import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sutra/core/storage/chat_repository.dart';
import 'package:sutra/features/chat/models/chat_message.dart';
import 'package:sutra/runtime/context/context_settings_provider.dart';
import 'package:sutra/runtime/memory/memory_extractor.dart';
import 'package:sutra/runtime/memory/memory_provider.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/orchestration/chat_template.dart';
import 'package:sutra/runtime/orchestration/context_builder.dart';
import 'package:sutra/runtime/orchestration/runtime_provider.dart';
import 'package:sutra/runtime/orchestration/selected_model_provider.dart';

/// Exposes [ChatState] which bundles messages + UI flags.
class ChatState {
  final List<ChatMessage> messages;
  final bool isGenerating;
  final bool isModelLoading;
  final String? error;
  final String? activeSessionId;

  const ChatState({
    this.messages = const [],
    this.isGenerating = false,
    this.isModelLoading = false,
    this.error,
    this.activeSessionId,
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
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isGenerating: isGenerating ?? this.isGenerating,
      isModelLoading: isModelLoading ?? this.isModelLoading,
      error: clearError ? null : (error ?? this.error),
      activeSessionId:
          clearSession ? null : (activeSessionId ?? this.activeSessionId),
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

  /// Switch to a different conversation (or create a new one).
  Future<void> switchSession(String sessionId) async {
    // Cancel any in-flight generation.
    _generatingSessionId = null;

    state = state.copyWith(
      isGenerating: false,
      activeSessionId: sessionId,
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

  Future<void> sendMessage(String text) async {
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) return;
    if (state.isGenerating) return;
    debugPrint('[ChatNotifier] sendMessage: "$cleanedText"');

    // Auto-create a session if none is active.
    final sessionId = state.activeSessionId ?? await newSession(title: _autoTitle(cleanedText));

    state = state.copyWith(clearError: true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      final memoryRepo = ref.read(memoryRepositoryProvider);
      final memoryExtractor = MemoryExtractor();
      // Resolve the current model's chat template.
      final selectedId = ref.read(selectedModelIdProvider);
      final modelDef = selectedId != null
          ? ModelRegistry.all.where((m) => m.id == selectedId).firstOrNull
          : ModelRegistry.all.firstOrNull;
      final contextBuilder = ContextBuilder(
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
          ? memoryRepo
              .top(limit: 5)
              .map((m) => '- ${m.content}')
              .join('\n')
          : null;

      final systemPrompt = ref.read(systemPromptProvider);
      final prompt = contextBuilder.buildFullPrompt(
        systemPrompt: systemPrompt,
        chatHistory: previousMessages,
        userMessage: cleanedText,
        memoryText: memoryText,
        userProfileText: contextSettings.buildUserProfilePrompt(),
        documentContext: contextSettings.buildDocumentContext(),
      );

      // Show loading state while the model initializes on a background isolate.
      state = state.copyWith(isModelLoading: true);
      debugPrint('[ChatNotifier] Waiting for runtime...');
      final runtimeManager =
          await ref.read(runtimeProvider.future);
      debugPrint('[ChatNotifier] Runtime ready: isReady=${runtimeManager.isReady}');
      state = state.copyWith(isModelLoading: false);
      var buffer = '';

      debugPrint('[ChatNotifier] Starting generateStream...');
      final sw = Stopwatch()..start();
      await for (final token
          in runtimeManager.generateStream(prompt)) {
        if (_generatingSessionId != genId) break;

        buffer += token;
        if (buffer.length <= token.length * 2) {
          debugPrint('[ChatNotifier] First token(s) received: "${token.substring(0, token.length.clamp(0, 50))}"');
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
      debugPrint('[ChatNotifier] Generation complete in ${sw.elapsedMilliseconds}ms, ${buffer.length} chars');

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
      debugPrint('[ChatNotifier] ERROR: $e\n$st');
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
