import 'package:sutra/runtime/models/model_catalog_entry.dart';

/// Remote model catalog — a curated, categorized list of GGUF models.
///
/// Hosted as a static JSON file, this catalog can be updated without
/// app releases. The catalog is fetched once and cached in memory.
class ModelCatalog {
  final List<ModelCatalogCategory> categories;

  const ModelCatalog({required this.categories});

  factory ModelCatalog.fromJson(Map<String, dynamic> json) {
    final cats = (json['categories'] as List)
        .map((c) => ModelCatalogCategory.fromJson(c as Map<String, dynamic>))
        .toList();
    return ModelCatalog(categories: cats);
  }

  /// All entries across all categories.
  List<ModelCatalogEntry> get allEntries =>
      categories.expand((c) => c.entries).toList();

  /// Hardcoded fallback catalog embedded in the app.
  static const ModelCatalog fallback = ModelCatalog(categories: [
    ModelCatalogCategory(
      name: 'Chat & General',
      icon: 'chat',
      description: 'Best for conversation, Q&A, and general text tasks',
      entries: [
        ModelCatalogEntry(
          id: 'qwen2.5-0.5b',
          name: 'Qwen 2.5 0.5B Instruct',
          description: 'Ultra-compact, fast responses. Great for simple tasks on low-end devices.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-0.5B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen2.5-0.5b.gguf',
          contextLength: 2048,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'tinyllama-1.1b',
          name: 'TinyLlama 1.1B Chat',
          description: 'Lightweight chat model, good for basic conversations.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
          localPath: 'tinyllama.gguf',
          contextLength: 2048,
          chatTemplateHint: 'tinyllama',
        ),
        ModelCatalogEntry(
          id: 'llama-3.2-1b-instruct',
          name: 'Llama 3.2 1B Instruct',
          description: 'Meta\'s smallest Llama 3.2. Good balance of speed and quality.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
          localPath: 'llama-3.2-1b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'llama3',
        ),
        ModelCatalogEntry(
          id: 'qwen2.5-1.5b',
          name: 'Qwen 2.5 1.5B Instruct',
          description: 'Solid mid-range model with strong instruction following.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-1.5B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen2.5-1.5b.gguf',
          contextLength: 2048,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'gemma-2-2b-it',
          name: 'Gemma 2 2B Instruct',
          description: 'Google\'s compact instruct model. Good reasoning for its size.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf',
          localPath: 'gemma-2-2b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'gemma',
        ),
        ModelCatalogEntry(
          id: 'qwen2.5-3b',
          name: 'Qwen 2.5 3B Instruct',
          description: 'Strong 3B model. Best quality under 4B parameters.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen2.5-3b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'llama-3.2-3b-instruct',
          name: 'Llama 3.2 3B Instruct',
          description: 'Meta\'s 3B model. Excellent for chat and instruction following.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
          localPath: 'llama-3.2-3b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'llama3',
        ),
        ModelCatalogEntry(
          id: 'phi3-mini',
          name: 'Phi-3 Mini 4K',
          description: 'Microsoft\'s small but capable model. Strong reasoning.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct-Q4_K_M.gguf',
          localPath: 'phi3-mini.gguf',
          contextLength: 4096,
          chatTemplateHint: 'phi3',
        ),
      ],
    ),
    ModelCatalogCategory(
      name: 'Coding',
      icon: 'code',
      description: 'Specialized for code generation and programming tasks',
      entries: [
        ModelCatalogEntry(
          id: 'qwen2.5-coder-1.5b',
          name: 'Qwen 2.5 Coder 1.5B',
          description: 'Code-specialized model. Supports 90+ programming languages.',
          category: 'coding',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen2.5-coder-1.5b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'qwen2.5-coder-3b',
          name: 'Qwen 2.5 Coder 3B',
          description: 'Larger code model. Better for complex programming tasks.',
          category: 'coding',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen2.5-coder-3b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
    ModelCatalogCategory(
      name: 'Research & Analysis',
      icon: 'science',
      description: 'Models with strong reasoning and analysis capabilities',
      entries: [
        ModelCatalogEntry(
          id: 'phi-3.5-mini',
          name: 'Phi-3.5 Mini Instruct',
          description: 'Enhanced reasoning and multi-language support.',
          category: 'research',
          downloadUrl: 'https://huggingface.co/bartowski/Phi-3.5-mini-instruct-GGUF/resolve/main/Phi-3.5-mini-instruct-Q4_K_M.gguf',
          localPath: 'phi-3.5-mini.gguf',
          contextLength: 4096,
          chatTemplateHint: 'phi3',
        ),
        ModelCatalogEntry(
          id: 'gemma-2-2b',
          name: 'Gemma 2 2B (Base)',
          description: 'Base model for fine-tuning and research. Not instruction-tuned.',
          category: 'research',
          downloadUrl: 'https://huggingface.co/bartowski/gemma-2-2b-GGUF/resolve/main/gemma-2-2b-Q4_K_M.gguf',
          localPath: 'gemma-2-2b-base.gguf',
          contextLength: 4096,
          chatTemplateHint: 'generic',
        ),
      ],
    ),
    ModelCatalogCategory(
      name: 'Multilingual',
      icon: 'translate',
      description: 'Strong performance across multiple languages',
      entries: [
        ModelCatalogEntry(
          id: 'qwen2.5-3b-multilingual',
          name: 'Qwen 2.5 3B (Multilingual)',
          description: 'Excels at 29+ languages. Best for non-English tasks.',
          category: 'multilingual',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen2.5-3b-multilingual.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
  ]);
}
