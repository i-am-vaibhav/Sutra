import 'package:sutra/runtime/memory/memory_item.dart';

class MemoryRepository {
  final List<MemoryItem> _memories = [];

  Future<void> add(MemoryItem item) async {
    _memories.add(item);
  }

  List<MemoryItem> getAll() => _memories;

  List<MemoryItem> top({int limit = 10}) {
    final sorted = [..._memories]
      ..sort((a, b) => b.importance.compareTo(a.importance));

    return sorted.take(limit).toList();
  }
}