import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/orchestration/runtime_provider.dart';
import '../models/chat_message.dart';

final chatProvider =
StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
      (ref) => ChatNotifier(ref),
);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  final Ref ref;

  ChatNotifier(this.ref) : super([]);

  String? _activeSessionId;

  void sendMessage(String text) async {
    final runtime = ref.read(runtimeProvider);

    // 1. user message
    final userMessage = ChatMessage(
      id: DateTime.now().toIso8601String(),
      text: text,
      role: ChatRole.user,
      createdAt: DateTime.now(),
    );

    state = [...state, userMessage];

    // 2. create stable session id for assistant stream
    final sessionId = DateTime.now().microsecondsSinceEpoch.toString();
    _activeSessionId = sessionId;

    String buffer = "";

    await for (final token in runtime.generateStream(text)) {
      // if a newer request started, ignore old stream
      if (_activeSessionId != sessionId) return;

      buffer += token;

      final existingIndex =
      state.indexWhere((m) => m.id == sessionId);

      final updatedMessage = ChatMessage(
        id: sessionId,
        text: buffer,
        role: ChatRole.assistant,
        createdAt: DateTime.now(),
      );

      if (existingIndex == -1) {
        state = [...state, updatedMessage];
      } else {
        final newState = [...state];
        newState[existingIndex] = updatedMessage;
        state = newState;
      }
    }

    // 3. finalize (lock message properly)
    final finalIndex =
    state.indexWhere((m) => m.id == sessionId);

    if (finalIndex != -1) {
      final finalState = [...state];
      finalState[finalIndex] = ChatMessage(
        id: sessionId,
        text: buffer,
        role: ChatRole.assistant,
        createdAt: DateTime.now(),
      );
      state = finalState;
    }
  }
}