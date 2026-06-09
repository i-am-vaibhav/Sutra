import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/core/storage/chat_repository.dart';
import 'package:sutra/runtime/memory/memory_extractor.dart';
import 'package:sutra/runtime/memory/memory_provider.dart';
import 'package:sutra/runtime/orchestration/context_builder.dart';
import 'package:sutra/runtime/orchestration/runtime_provider.dart';

import '../models/chat_message.dart';

final chatProvider =
StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
      (ref) => ChatNotifier(ref),
);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;

  ChatNotifier(this.ref) : super([]) {
    _loadHistory();
  }

  String? _activeSessionId;

  Future<void> _loadHistory() async {
    final repo = ref.read(chatRepositoryProvider);
    final data = await repo.getMessages();

    state = data
        .map(
          (e) => ChatMessage(
        id: e['id'] as String,
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
  }

  Future<void> sendMessage(String text) async {
    final cleanedText = text.trim();
    if (cleanedText.isEmpty) return;

    final repo = ref.read(chatRepositoryProvider);
    final runtime = ref.read(runtimeProvider);
    final memoryRepo = ref.read(memoryRepositoryProvider);
    final memoryExtractor = MemoryExtractor();
    final contextBuilder = ContextBuilder();

    final userMessage = ChatMessage(
      id: DateTime.now().toIso8601String(),
      text: cleanedText,
      role: ChatRole.user,
      createdAt: DateTime.now(),
    );

    final previousMessages = [...state, userMessage];

    state = previousMessages;

    await repo.saveMessage({
      'id': userMessage.id,
      'text': userMessage.text,
      'role': 'user',
      'createdAt': userMessage.createdAt.millisecondsSinceEpoch,
    });

    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _activeSessionId = sessionId;

    final assistantPlaceholder = ChatMessage(
      id: sessionId,
      text: '',
      role: ChatRole.assistant,
      createdAt: DateTime.now(),
    );

    state = [...state, assistantPlaceholder];

    final memoryText = memoryRepo.top(limit: 5).map((m) => '- ${m.content}').join('\n');
    final chatContext = contextBuilder.build(previousMessages);

    final prompt = StringBuffer();
    if (memoryText.trim().isNotEmpty) {
      prompt.writeln('MEMORY:');
      prompt.writeln(memoryText);
      prompt.writeln();
    }
    if (chatContext.trim().isNotEmpty) {
      prompt.writeln('CHAT:');
      prompt.writeln(chatContext);
      prompt.writeln();
    }
    prompt.writeln('[USER]: $cleanedText');
    prompt.writeln('[ASSISTANT]:');

    var buffer = '';

    await for (final token in runtime.generateStream(prompt.toString())) {
      if (_activeSessionId != sessionId) return;

      buffer += token;

      final index = state.indexWhere((m) => m.id == sessionId);
      if (index == -1) continue;

      final newState = [...state];
      newState[index] = ChatMessage(
        id: sessionId,
        text: buffer,
        role: ChatRole.assistant,
        createdAt: assistantPlaceholder.createdAt,
      );
      state = newState;
    }

    if (_activeSessionId != sessionId) return;

    await repo.saveMessage({
      'id': sessionId,
      'text': buffer,
      'role': 'assistant',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });

    final extractedMemories = memoryExtractor.extract(cleanedText, buffer);
    for (final memory in extractedMemories) {
      await memoryRepo.add(memory);
    }

    final finalIndex = state.indexWhere((m) => m.id == sessionId);
    if (finalIndex != -1) {
      final finalState = [...state];
      finalState[finalIndex] = ChatMessage(
        id: sessionId,
        text: buffer,
        role: ChatRole.assistant,
        createdAt: assistantPlaceholder.createdAt,
      );
      state = finalState;
    }
  }
}