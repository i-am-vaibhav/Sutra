import 'llama_cpp_bindings.dart';

class LlamaCppEngine {
  Future<bool> loadModel(
      String path,
      ) async {
    return LlamaCppBindings.loadModel(
      path,
    );
  }
}