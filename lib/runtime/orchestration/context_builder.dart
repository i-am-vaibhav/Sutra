import '../../features/chat/models/chat_message.dart';

class ContextBuilder {
  final int maxMessages;
  final int maxChars;

  ContextBuilder({
    this.maxMessages = 12,
    this.maxChars = 3000,
  });

  String build(List<ChatMessage> messages) {
    final recent = messages.length > maxMessages
        ? messages.sublist(messages.length - maxMessages)
        : messages;

    final buffer = StringBuffer();
    int charCount = 0;

    for (final msg in recent) {
      final role = msg.role.name.toUpperCase();
      final line = "[$role]: ${msg.text}\n";

      if (charCount + line.length > maxChars) break;

      buffer.write(line);
      charCount += line.length;
    }

    return buffer.toString();
  }
}