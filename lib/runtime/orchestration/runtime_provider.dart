import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/llm/impl/ollama_llm_runtime.dart';

import '../orchestration/runtime_manager.dart';

final runtimeProvider = Provider<RuntimeManager>((ref) {
  return RuntimeManager(
    LlamaCppRuntime(),
  );
});