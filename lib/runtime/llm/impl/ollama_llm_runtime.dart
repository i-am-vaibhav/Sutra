import 'package:sutra/runtime/llm/impl/llama_cpp/llama_cpp_engine.dart';
import '../llm_runtime.dart';

class LlamaCppRuntime
    implements LlmRuntime {

  final _engine = LlamaCppEngine();

  Future<void> initialize(
      String modelPath,
      ) async {
    final loaded =
    await _engine.loadModel(
      modelPath,
    );

    print(
      'MODEL LOADED: $loaded',
    );
  }

  @override
  Stream<String> generateStream(
      String prompt,
      ) async* {
    yield 'llama.cpp connected';
  }
}