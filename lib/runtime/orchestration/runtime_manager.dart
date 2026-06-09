import 'package:sutra/runtime/llm/llm_runtime.dart';

class RuntimeManager {
  final LlmRuntime llm;

  RuntimeManager(this.llm);

  Stream<String> generateStream(String prompt) {
    return llm.generateStream(prompt);
  }
}