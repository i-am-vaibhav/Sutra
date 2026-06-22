import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';

/// Models with ≥8K context can handle web search prompts.
const _webSearchCap = {ModelCapability.webSearch};
const _noCapabilities = <ModelCapability>{};

/// Central registry of built-in models that ship with the app.
///
/// v1: Ship with Qwen3.5 series — the latest multimodal models trained on
/// 2026 data. Models are sized for mobile deployment with RAM-appropriate
/// context lengths.
class ModelRegistry {
  /// Qwen3.5-0.8B — Ultra-lightweight, runs on any device.
  /// ~580MB Q4_K_M, 4K context for basic chat.
  static const qwen35_0_8b = ModelDefinition(
    id: 'qwen3.5-0.8b',
    name: 'Qwen 3.5 0.8B',
    size: ModelSize.tiny,
    contextLength: 4096,
    downloadUrl:
        'https://huggingface.co/bartowski/Qwen_Qwen3.5-0.8B-GGUF/resolve/main/Qwen_Qwen3.5-0.8B-Q4_K_M.gguf',
    localPath: 'qwen3.5-0.8b.gguf',
    chatTemplate: QwenChatTemplate(),
    capabilities: _noCapabilities,
    fileSizeBytes: 580000000,
  );

  /// Qwen3.5-2B — Small but capable, 8K context for web search.
  /// ~1.4GB Q4_K_M, suitable for 2GB+ RAM devices.
  static const qwen35_2b = ModelDefinition(
    id: 'qwen3.5-2b',
    name: 'Qwen 3.5 2B',
    size: ModelSize.small,
    contextLength: 8192,
    downloadUrl:
        'https://huggingface.co/bartowski/Qwen_Qwen3.5-2B-GGUF/resolve/main/Qwen_Qwen3.5-2B-Q4_K_M.gguf',
    localPath: 'qwen3.5-2b.gguf',
    chatTemplate: QwenChatTemplate(),
    capabilities: _webSearchCap,
    fileSizeBytes: 1400000000,
  );

  /// Qwen3.5-4B — Balanced performance, 8K context.
  /// ~3.0GB Q4_K_M, suitable for 4GB+ RAM devices.
  static const qwen35_4b = ModelDefinition(
    id: 'qwen3.5-4b',
    name: 'Qwen 3.5 4B',
    size: ModelSize.medium,
    contextLength: 8192,
    downloadUrl:
        'https://huggingface.co/bartowski/Qwen_Qwen3.5-4B-GGUF/resolve/main/Qwen_Qwen3.5-4B-Q4_K_M.gguf',
    localPath: 'qwen3.5-4b.gguf',
    chatTemplate: QwenChatTemplate(),
    capabilities: _webSearchCap,
    fileSizeBytes: 3010000000,
  );

  /// Qwen3.5-9B — High quality, 16K context for complex tasks.
  /// ~6.2GB Q4_K_M, requires 8GB+ RAM (high-end phones only).
  static const qwen35_9b = ModelDefinition(
    id: 'qwen3.5-9b',
    name: 'Qwen 3.5 9B',
    size: ModelSize.large,
    contextLength: 16384,
    downloadUrl:
        'https://huggingface.co/bartowski/Qwen_Qwen3.5-9B-GGUF/resolve/main/Qwen_Qwen3.5-9B-Q4_K_M.gguf',
    localPath: 'qwen3.5-9b.gguf',
    chatTemplate: QwenChatTemplate(),
    capabilities: _webSearchCap,
    fileSizeBytes: 6170000000,
  );

  /// All built-in chat models, ordered smallest-first for provisioning.
  static const all = [
    qwen35_0_8b,
    qwen35_2b,
    qwen35_4b,
    qwen35_9b,
  ];
}
