abstract class LlmRuntime {
  Stream<String> generateStream(String prompt);
}