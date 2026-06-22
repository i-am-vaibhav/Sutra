/// A periodic summary of raw memories for a session.
///
/// Instead of injecting fragmented raw memories into context, we compress
/// them into concise, high-signal facts. This prevents hallucination
/// in long conversations and keeps the context window efficient.
class MemorySummary {
  final String sessionId;
  final String content;
  final DateTime updatedAt;

  MemorySummary({
    required this.sessionId,
    required this.content,
    required this.updatedAt,
  });
}
