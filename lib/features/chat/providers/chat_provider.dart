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

  void sendMessage(String text) async {
    final userMessage = ChatMessage(
      id: DateTime.now().toIso8601String(),
      text: text,
      role: ChatRole.user,
      createdAt: DateTime.now(),
    );

    state = [...state, userMessage];

    final runtime = ref.read(runtimeProvider);

    final sessionId = DateTime.now().toIso8601String();
    String buffer = "";

    await for (final token in runtime.generateStream(text)) {
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
  }
}