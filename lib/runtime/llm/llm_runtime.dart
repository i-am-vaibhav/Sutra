abstract class LlmRuntime {
  /// Whether the runtime has a model loaded and is ready to generate.
  bool get isReady;

  Stream<String> generateStream(String prompt);
}