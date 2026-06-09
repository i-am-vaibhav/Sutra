import 'package:sutra/runtime/llm/impl/fake_llm_runtime.dart';

class RuntimeManager {
  final llm = FakeLlmRuntime();

  Stream<String> generateStream(String prompt) {
    return llm.generateStream(prompt);
  }
}