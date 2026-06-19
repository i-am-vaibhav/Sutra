import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/features/chat/chat_message.dart';

void main() {
  group('ChatMessage', () {
    test('constructor sets all fields', () {
      final msg = ChatMessage(
        id: '1',
        sessionId: 's1',
        text: 'Hello',
        role: ChatRole.user,
        createdAt: DateTime(2024),
      );
      expect(msg.id, '1');
      expect(msg.sessionId, 's1');
      expect(msg.text, 'Hello');
      expect(msg.role, ChatRole.user);
    });

    test('ChatRole enum has user and assistant', () {
      expect(ChatRole.values, [ChatRole.user, ChatRole.assistant]);
    });
  });
}
