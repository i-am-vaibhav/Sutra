import 'package:sutra/runtime/memory/memory_item.dart';

class MemoryExtractor {
  List<MemoryItem> extract(String userMessage, String assistantReply) {
    final List<MemoryItem> items = [];

    if (userMessage.length > 20) {
      items.add(MemoryItem(
        id: DateTime.now().toIso8601String(),
        content: "User said: $userMessage",
        createdAt: DateTime.now(),
        importance: 0.7,
      ));
    }

    if (userMessage.contains("like") ||
        userMessage.contains("prefer") ||
        userMessage.contains("want")) {
      items.add(MemoryItem(
        id: DateTime.now().toIso8601String(),
        content: "Preference: $userMessage",
        createdAt: DateTime.now(),
        importance: 0.9,
      ));
    }

    return items;
  }
}