import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';

/// Models with ≥8K context can handle web search prompts.
const _webSearchCap = {ModelCapability.webSearch};
const _noCapabilities = <ModelCapability>{};

/// Central registry of built-in models that ship with the app.
///
/// Models are organized by size tier. The [all] list is ordered
/// smallest-first so provisioning downloads the lightest models first.
class ModelRegistry {
  // ── Ultra-Light (< 1B) ──────────────────────────────────

  static const qwen3_0_6b = ModelDefinition(
    id: 'qwen3-0.6b',
    name: 'Qwen 3 0.6B Instruct',
    size: ModelSize.tiny,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-Instruct-GGUF/resolve/main/Qwen_Qwen3-0.6B-Instruct-Q4_K_M.gguf',
    localPath: 'qwen3-0.6b.gguf',
    chatTemplate: QwenChatTemplate(),
    capabilities: _noCapabilities,
  );

  // ── Light (1-2B) ────────────────────────────────────────

  static const qwen3_1_7b = ModelDefinition(
    id: 'qwen3-1.7b',
    name: 'Qwen 3 1.7B Instruct',
    size: ModelSize.small,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-1.7B-Instruct-GGUF/resolve/main/Qwen_Qwen3-1.7B-Instruct-Q4_K_M.gguf',
    localPath: 'qwen3-1.7b.gguf',
    chatTemplate: QwenChatTemplate(),
    capabilities: _noCapabilities,
  );

  static const gemma3_1b = ModelDefinition(
    id: 'gemma-3-1b-it',
    name: 'Gemma 3 1B Instruct',
    size: ModelSize.small,
    contextLength: 8192,
    downloadUrl: 'https://huggingface.co/bartowski/google_gemma-3-1b-it-GGUF/resolve/main/google_gemma-3-1b-it-Q4_K_M.gguf',
    localPath: 'gemma-3-1b.gguf',
    chatTemplate: GemmaChatTemplate(),
    capabilities: _webSearchCap,
  );

  static const llama32_1b = ModelDefinition(
    id: 'llama-3.2-1b-instruct',
    name: 'Llama 3.2 1B Instruct',
    size: ModelSize.small,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
    localPath: 'llama-3.2-1b.gguf',
    chatTemplate: Llama3ChatTemplate(),
    capabilities: _noCapabilities,
  );

  // ── Standard (3-4B) ─────────────────────────────────────

  static const qwen3_4b = ModelDefinition(
    id: 'qwen3-4b',
    name: 'Qwen 3 4B Instruct',
    size: ModelSize.medium,
    contextLength: 8192,
    downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-4B-Instruct-GGUF/resolve/main/Qwen_Qwen3-4B-Instruct-Q4_K_M.gguf',
    localPath: 'qwen3-4b.gguf',
    chatTemplate: QwenChatTemplate(),
    capabilities: _webSearchCap,
  );

  static const phi4Mini = ModelDefinition(
    id: 'phi-4-mini',
    name: 'Phi-4 Mini Instruct',
    size: ModelSize.medium,
    contextLength: 8192,
    downloadUrl: 'https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf',
    localPath: 'phi-4-mini.gguf',
    chatTemplate: Phi3ChatTemplate(),
    capabilities: _webSearchCap,
  );

  static const gemma3_4b = ModelDefinition(
    id: 'gemma-3-4b-it',
    name: 'Gemma 3 4B Instruct',
    size: ModelSize.medium,
    contextLength: 8192,
    downloadUrl: 'https://huggingface.co/bartowski/google_gemma-3-4b-it-GGUF/resolve/main/google_gemma-3-4b-it-Q4_K_M.gguf',
    localPath: 'gemma-3-4b.gguf',
    chatTemplate: GemmaChatTemplate(),
    capabilities: _webSearchCap,
  );

  static const smolLM3 = ModelDefinition(
    id: 'smollm3-3b',
    name: 'SmolLM3 3B',
    size: ModelSize.medium,
    contextLength: 8192,
    downloadUrl: 'https://huggingface.co/bartowski/HuggingFaceTB_SmolLM3-3B-GGUF/resolve/main/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf',
    localPath: 'smollm3-3b.gguf',
    chatTemplate: Llama3ChatTemplate(),
    capabilities: _webSearchCap,
  );

  static const ministral3b = ModelDefinition(
    id: 'ministral-3b',
    name: 'Ministral 3B Instruct',
    size: ModelSize.medium,
    contextLength: 8192,
    downloadUrl: 'https://huggingface.co/bartowski/mistralai_Ministral-3-3B-Instruct-GGUF/resolve/main/mistralai_Ministral-3-3B-Instruct-Q4_K_M.gguf',
    localPath: 'ministral-3b.gguf',
    chatTemplate: MistralChatTemplate(),
    capabilities: _webSearchCap,
  );

  static const llama32_3b = ModelDefinition(
    id: 'llama-3.2-3b-instruct',
    name: 'Llama 3.2 3B Instruct',
    size: ModelSize.medium,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
    localPath: 'llama-3.2-3b.gguf',
    chatTemplate: Llama3ChatTemplate(),
    capabilities: _noCapabilities,
  );

  // ── Code-specialized ─────────────────────────────────────

  static const qwen25Coder_3b = ModelDefinition(
    id: 'qwen2.5-coder-3b',
    name: 'Qwen 2.5 Coder 3B',
    size: ModelSize.medium,
    contextLength: 4096,
    downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf',
    localPath: 'qwen2.5-coder-3b.gguf',
    chatTemplate: QwenChatTemplate(),
    capabilities: _noCapabilities,
  );

  /// All built-in chat models, ordered smallest-first for provisioning.
  /// Code-specialized models (qwen25Coder_3b) are excluded to avoid
  /// auto-selecting them for general chat prompts.
  static const all = [
    qwen3_0_6b,        // 0.6B
    qwen3_1_7b,        // 1.7B
    gemma3_1b,         // 1B
    llama32_1b,        // 1B
    smolLM3,           // 3B
    ministral3b,        // 3B
    llama32_3b,        // 3B
    qwen3_4b,          // 4B
    phi4Mini,           // 3.8B
    gemma3_4b,         // 4B
  ];
}
