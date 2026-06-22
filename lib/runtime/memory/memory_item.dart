class MemoryItem {
  final String id;
  final String content;
  final DateTime createdAt;
  final double importance; // 0.0 - 1.0
  final String? sessionId;

  MemoryItem({
    required this.id,
    required this.content,
    required this.createdAt,
    this.importance = 0.5,
    this.sessionId,
  });
}
