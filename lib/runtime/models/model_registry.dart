import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/orchestration/chat_template.dart';

class ModelRegistry {
  static const micro = ModelDefinition(
    id: 'qwen2.5-0.5b',
    name: 'Qwen 2.5 0.5B Instruct',
    size: ModelSize.tiny,
    contextLength: 2048,
    downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
    localPath: 'qwen2.5-0.5b.gguf',
    chatTemplate: QwenChatTemplate(),
  );

  static const tiny = ModelDefinition(
    id: 'tinyllama-1.1b',
    name: 'TinyLlama 1.1B Chat',
    size: ModelSize.small,
    contextLength: 2048,
    downloadUrl: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
    localPath: 'tinyllama.gguf',
    chatTemplate: TinyLlamaChatTemplate(),
  );

  static const small = ModelDefinition(
    id: 'qwen2.5-1.5b',
    name: 'Qwen 2.5 1.5B Instruct',
    size: ModelSize.small,
    contextLength: 2048,
    downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
    localPath: 'qwen2.5-1.5b.gguf',
    chatTemplate: QwenChatTemplate(),
  );

  static const medium = ModelDefinition(
    id: 'qwen2.5-3b',
    name: 'Qwen 2.5 3B Instruct',
    size: ModelSize.medium,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
    localPath: 'qwen2.5-3b.gguf',
    chatTemplate: QwenChatTemplate(),
  );

  static const phi3Mini = ModelDefinition(
    id: 'phi3-mini',
    name: 'Phi-3 Mini 4K',
    size: ModelSize.medium,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf',
    localPath: 'phi3-mini.gguf',
    chatTemplate: Phi3ChatTemplate(),
  );

  static const gemma2b = ModelDefinition(
    id: 'gemma-2-2b-it',
    name: 'Gemma 2 2B Instruct',
    size: ModelSize.small,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
    localPath: 'gemma-2-2b.gguf',
    chatTemplate: GemmaChatTemplate(),
  );

  static const llama32_1b = ModelDefinition(
    id: 'llama-3.2-1b-instruct',
    name: 'Llama 3.2 1B Instruct',
    size: ModelSize.tiny,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    localPath: 'llama-3.2-1b.gguf',
    chatTemplate: Llama3ChatTemplate(),
  );

  static const llama32_3b = ModelDefinition(
    id: 'llama-3.2-3b-instruct',
    name: 'Llama 3.2 3B Instruct',
    size: ModelSize.medium,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    localPath: 'llama-3.2-3b.gguf',
    chatTemplate: Llama3ChatTemplate(),
  );

  static const all = [
    micro,       // 0.5B
    tiny,        // 1.1B
    llama32_1b,  // 1B
    small,       // 1.5B
    gemma2b,     // 2B
    medium,      // 3B (Qwen)
    llama32_3b,  // 3B (Llama)
    phi3Mini,    // 3.8B (Phi-3)
  ];
}
