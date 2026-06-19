import 'package:sutra/runtime/llm/llm_runtime.dart';

class RuntimeManager {
  final LlmRuntime llm;

  RuntimeManager(this.llm);

  bool get isReady => llm.isReady;

  Stream<String> generateStream(String prompt) {
    return llm.generateStream(prompt);
  }
}