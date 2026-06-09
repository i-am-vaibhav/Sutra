import 'package:sutra/runtime/llm/impl/fake_llm_runtime.dart';
import 'package:sutra/runtime/llm/llm_runtime.dart';

class RuntimeManager {
  final LlmRuntime llm;

  RuntimeManager({LlmRuntime? llm})
      : llm = llm ?? FakeLlmRuntime();

  Stream<String> generateStream(String prompt) {
    return llm.generateStream(prompt);
  }
}