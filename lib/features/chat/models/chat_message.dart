enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final String text;
  final ChatRole role;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    required this.createdAt,
  });
}