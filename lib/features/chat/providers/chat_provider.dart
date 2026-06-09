import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

final chatProvider =
StateNotifierProvider<ChatNotifier, List<ChatMessage>>(
      (ref) => ChatNotifier(),
);

class ChatNotifier extends StateNotifier<List<ChatMessage>> {
  ChatNotifier() : super([]);

  void sendMessage(String text) {
    final userMessage = ChatMessage(
      id: DateTime.now().toIso8601String(),
      text: text,
      role: ChatRole.user,
      createdAt: DateTime.now(),
    );

    state = [...state, userMessage];

    Future.delayed(const Duration(seconds: 1), () {
      final reply = ChatMessage(
        id: DateTime.now().toIso8601String(),
        text: "Hello from local runtime",
        role: ChatRole.assistant,
        createdAt: DateTime.now(),
      );

      state = [...state, reply];
    });
  }
}