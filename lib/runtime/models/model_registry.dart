import 'model_definition.dart';

class ModelRegistry {
  static const tiny = ModelDefinition(
    id: 'tinyllama-1.1b',
    name: 'TinyLlama 1.1B Chat',
    size: ModelSize.small,
    contextLength: 2048,
    downloadUrl:
    'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    localPath: 'models/tinyllama.gguf',
  );

  static const small = ModelDefinition(
    id: 'phi3-mini',
    name: 'Phi-3 Mini 4K',
    size: ModelSize.medium,
    contextLength: 4096,
    downloadUrl:
    'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
    localPath: 'models/phi3-mini.gguf',
  );

  static const medium = ModelDefinition(
    id: 'qwen2.5-3b',
    name: 'Qwen 2.5 3B Instruct',
    size: ModelSize.large,
    contextLength: 8192,
    downloadUrl:
    'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
    localPath: 'models/qwen2.5-3b.gguf',
  );

  static const all = [
    tiny,
    small,
    medium,
  ];
}