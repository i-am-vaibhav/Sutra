enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final String sessionId;
  final String text;
  final ChatRole role;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.role,
    required this.createdAt,
  });
}
