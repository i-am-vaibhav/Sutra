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
  /// Updated with latest 2025-2026 models and task-specific categories.
  static const ModelCatalog fallback = ModelCatalog(categories: [
    // ── Speed ──────────────────────────────────────────────
    ModelCatalogCategory(
      name: 'Fast & Light',
      icon: 'bolt',
      description: 'Ultra-responsive models for quick tasks on any device',
      entries: [
        ModelCatalogEntry(
          id: 'qwen3-0.6b',
          name: 'Qwen 3 0.6B Instruct',
          description: 'Ultra-compact with surprising quality. Perfect for simple Q&A, sentiment checks, and entity extraction.',
          category: 'fast',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-0.6B-Instruct-GGUF/resolve/main/Qwen_Qwen3-0.6B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen3-0.6b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'qwen3-1.7b',
          name: 'Qwen 3 1.7B Instruct',
          description: 'Best balance of speed and quality under 2B. Strong at intent recognition and entity extraction.',
          category: 'fast',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-1.7B-Instruct-GGUF/resolve/main/Qwen_Qwen3-1.7B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen3-1.7b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'gemma-3-1b-it',
          name: 'Gemma 3 1B Instruct',
          description: 'Google\'s mobile-optimized model. Great reasoning for its size.',
          category: 'fast',
          downloadUrl: 'https://huggingface.co/bartowski/google_gemma-3-1b-it-GGUF/resolve/main/google_gemma-3-1b-it-Q4_K_M.gguf',
          localPath: 'gemma-3-1b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'gemma',
        ),
        ModelCatalogEntry(
          id: 'llama-3.2-1b-instruct',
          name: 'Llama 3.2 1B Instruct',
          description: 'Meta\'s smallest Llama. Best tool-use support at this size.',
          category: 'fast',
          downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf',
          localPath: 'llama-3.2-1b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'llama3',
        ),
      ],
    ),
    // ── Chat ───────────────────────────────────────────────
    ModelCatalogCategory(
      name: 'Chat & General',
      icon: 'chat',
      description: 'Best all-rounders for conversation, dialogue management, and general tasks',
      entries: [
        ModelCatalogEntry(
          id: 'qwen3-4b',
          name: 'Qwen 3 4B Instruct',
          description: 'Latest gen with dual-mode thinking. Excels at NLU, sentiment analysis, and contextual dialogue.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-4B-Instruct-GGUF/resolve/main/Qwen_Qwen3-4B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen3-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'phi-4-mini',
          name: 'Phi-4 Mini Instruct',
          description: 'Microsoft\'s best reasoning per parameter. Strong at summarization, QA, and text analysis.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf',
          localPath: 'phi-4-mini.gguf',
          contextLength: 8192,
          chatTemplateHint: 'phi3',
        ),
        ModelCatalogEntry(
          id: 'gemma-3-4b-it',
          name: 'Gemma 3 4B Instruct',
          description: 'Google\'s multimodal model. Excellent for text understanding, entity extraction, and function calling.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/google_gemma-3-4b-it-GGUF/resolve/main/google_gemma-3-4b-it-Q4_K_M.gguf',
          localPath: 'gemma-3-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'gemma',
        ),
        ModelCatalogEntry(
          id: 'smollm3-3b',
          name: 'SmolLM3 3B',
          description: 'Fully open by HuggingFace. Good at intent recognition and adaptive responses.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/HuggingFaceTB_SmolLM3-3B-GGUF/resolve/main/HuggingFaceTB_SmolLM3-3B-Q4_K_M.gguf',
          localPath: 'smollm3-3b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'llama3',
        ),
        ModelCatalogEntry(
          id: 'ministral-3b',
          name: 'Ministral 3B Instruct',
          description: 'Mistral\'s edge-optimized model. Fast with structured output for entity extraction.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/mistralai_Ministral-3-3B-Instruct-GGUF/resolve/main/mistralai_Ministral-3-3B-Instruct-Q4_K_M.gguf',
          localPath: 'ministral-3b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'mistral',
        ),
        ModelCatalogEntry(
          id: 'llama-3.2-3b-instruct',
          name: 'Llama 3.2 3B Instruct',
          description: 'Meta\'s 3B. Excellent for dialogue management and context-aware responses.',
          category: 'chat',
          downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
          localPath: 'llama-3.2-3b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'llama3',
        ),
      ],
    ),
    // ── Translation ────────────────────────────────────────
    ModelCatalogCategory(
      name: 'Translation',
      icon: 'translate',
      description: 'Strong multilingual support for text translation between languages',
      entries: [
        ModelCatalogEntry(
          id: 'qwen3-4b-translation',
          name: 'Qwen 3 4B (Multilingual)',
          description: 'Excels at 29+ languages. Best for English, Chinese, Japanese, Korean, and European translations.',
          category: 'translation',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-4B-Instruct-GGUF/resolve/main/Qwen_Qwen3-4B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen3-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'gemma-3-4b-translation',
          name: 'Gemma 3 4B (Multilingual)',
          description: 'Google\'s multilingual model. Strong at European and Asian language pairs.',
          category: 'translation',
          downloadUrl: 'https://huggingface.co/bartowski/google_gemma-3-4b-it-GGUF/resolve/main/google_gemma-3-4b-it-Q4_K_M.gguf',
          localPath: 'gemma-3-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'gemma',
        ),
        ModelCatalogEntry(
          id: 'qwen3-1.7b-translation',
          name: 'Qwen 3 1.7B (Quick Translation)',
          description: 'Fast lightweight translation. Great for quick language swaps on low-end devices.',
          category: 'translation',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-1.7B-Instruct-GGUF/resolve/main/Qwen_Qwen3-1.7B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen3-1.7b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
    // ── Summarization & Analysis ───────────────────────────
    ModelCatalogCategory(
      name: 'Summarization & Analysis',
      icon: 'summarize',
      description: 'Generate concise summaries, analyze text, and extract key information',
      entries: [
        ModelCatalogEntry(
          id: 'phi-4-mini-summary',
          name: 'Phi-4 Mini (Analysis Focus)',
          description: 'Best reasoning per parameter. Ideal for summarization, text analysis, and information extraction.',
          category: 'summarization',
          downloadUrl: 'https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf',
          localPath: 'phi-4-mini.gguf',
          contextLength: 8192,
          chatTemplateHint: 'phi3',
        ),
        ModelCatalogEntry(
          id: 'qwen3-4b-summary',
          name: 'Qwen 3 4B (Analysis Focus)',
          description: 'Dual-mode thinking for deep analysis. Excellent at summarization and key point extraction.',
          category: 'summarization',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-4B-Instruct-GGUF/resolve/main/Qwen_Qwen3-4B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen3-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'qwen3-1.7b-summary',
          name: 'Qwen 3 1.7B (Quick Summary)',
          description: 'Fast summarization for short texts. Good for quick bullet-point summaries.',
          category: 'summarization',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-1.7B-Instruct-GGUF/resolve/main/Qwen_Qwen3-1.7B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen3-1.7b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
    // ── Knowledge & QA ─────────────────────────────────────
    ModelCatalogCategory(
      name: 'Knowledge & QA',
      icon: 'school',
      description: 'Answer specific questions and provide information from general knowledge',
      entries: [
        ModelCatalogEntry(
          id: 'phi-4-mini-qa',
          name: 'Phi-4 Mini (QA Focus)',
          description: 'Trained on high-quality synthetic data. Excellent at factual questions and detailed answers.',
          category: 'qa',
          downloadUrl: 'https://huggingface.co/bartowski/microsoft_Phi-4-mini-instruct-GGUF/resolve/main/microsoft_Phi-4-mini-instruct-Q4_K_M.gguf',
          localPath: 'phi-4-mini.gguf',
          contextLength: 8192,
          chatTemplateHint: 'phi3',
        ),
        ModelCatalogEntry(
          id: 'qwen3-4b-qa',
          name: 'Qwen 3 4B (Knowledge Focus)',
          description: 'Widest knowledge base under 4B. Strong at factual recall and multi-hop reasoning.',
          category: 'qa',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen_Qwen3-4B-Instruct-GGUF/resolve/main/Qwen_Qwen3-4B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen3-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'llama-3.2-3b-qa',
          name: 'Llama 3.2 3B (Knowledge Focus)',
          description: 'Meta\'s broad training data. Good general knowledge and factual accuracy.',
          category: 'qa',
          downloadUrl: 'https://huggingface.co/bartowski/Llama-3.2-3B-Instruct-GGUF/resolve/main/Llama-3.2-3B-Instruct-Q4_K_M.gguf',
          localPath: 'llama-3.2-3b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'llama3',
        ),
      ],
    ),
    // ── Code ───────────────────────────────────────────────
    ModelCatalogCategory(
      name: 'Code',
      icon: 'code',
      description: 'Specialized for code generation, debugging, and programming tasks',
      entries: [
        ModelCatalogEntry(
          id: 'qwen2.5-coder-1.5b',
          name: 'Qwen 2.5 Coder 1.5B',
          description: 'Code-specialized. Supports 90+ programming languages. Fast code generation.',
          category: 'coding',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-1.5B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen2.5-coder-1.5b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'qwen2.5-coder-3b',
          name: 'Qwen 2.5 Coder 3B',
          description: 'Best code model for mobile. Complex programming, debugging, refactoring.',
          category: 'coding',
          downloadUrl: 'https://huggingface.co/bartowski/Qwen2.5-Coder-3B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-3B-Instruct-Q4_K_M.gguf',
          localPath: 'qwen2.5-coder-3b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
  ]);
}
