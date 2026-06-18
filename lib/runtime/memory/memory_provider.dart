import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/memory/memory_repository.dart';

final memoryRepositoryProvider = Provider<MemoryRepository>((ref) {
  return MemoryRepository();
});