import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/orchestration/runtime_manager.dart';

final runtimeProvider = Provider<RuntimeManager>((ref) {
  return RuntimeManager();
});