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

  Map<String, dynamic> toJson() => {
        'categories': categories.map((c) => c.toJson()).toList(),
      };

  /// All entries across all categories.
  List<ModelCatalogEntry> get allEntries =>
      categories.expand((c) => c.entries).toList();

  /// Hardcoded fallback catalog embedded in the app.
  ///
  /// Ships with the Qwen3.5 series — the latest multimodal models
  /// with early-fusion training on text, images, and visual logic.
  /// Updated daily via [ModelUpdateService].
  static const ModelCatalog fallback = ModelCatalog(categories: [
    // ── Speed ──────────────────────────────────────────────
    ModelCatalogCategory(
      name: 'Fast & Light',
      icon: 'bolt',
      description: 'Ultra-responsive models for quick tasks on any device',
      entries: [
        ModelCatalogEntry(
          id: 'qwen3.5-0.8b',
          name: 'Qwen 3.5 0.8B',
          description:
              'Ultra-compact latest-gen model. Perfect for simple Q&A, sentiment checks, and entity extraction on any device.',
          category: 'fast',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-0.8B-GGUF/resolve/main/Qwen_Qwen3.5-0.8B-Q4_K_M.gguf',
          localPath: 'qwen3.5-0.8b.gguf',
          contextLength: 4096,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'qwen3.5-2b',
          name: 'Qwen 3.5 2B',
          description:
              'Small but highly capable. Best balance of speed and quality under 3B with 8K context for web search.',
          category: 'fast',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-2B-GGUF/resolve/main/Qwen_Qwen3.5-2B-Q4_K_M.gguf',
          localPath: 'qwen3.5-2b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
    // ── Chat ───────────────────────────────────────────────
    ModelCatalogCategory(
      name: 'Chat & General',
      icon: 'chat',
      description:
          'Best all-rounders for conversation, dialogue management, and general tasks',
      entries: [
        ModelCatalogEntry(
          id: 'qwen3.5-4b',
          name: 'Qwen 3.5 4B',
          description:
              'Balanced performance with dual-mode thinking. Excellent at NLU, sentiment analysis, and contextual dialogue.',
          category: 'chat',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-4B-GGUF/resolve/main/Qwen_Qwen3.5-4B-Q4_K_M.gguf',
          localPath: 'qwen3.5-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'qwen3.5-9b',
          name: 'Qwen 3.5 9B',
          description:
              'High-quality reasoning with 16K context. Best for complex multi-step tasks on high-end devices (8GB+ RAM).',
          category: 'chat',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-9B-GGUF/resolve/main/Qwen_Qwen3.5-9B-Q4_K_M.gguf',
          localPath: 'qwen3.5-9b.gguf',
          contextLength: 16384,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
    // ── Web Search ────────────────────────────────────────
    ModelCatalogCategory(
      name: 'Web Search',
      icon: 'search',
      description: 'Models optimized for web search context and retrieval',
      entries: [
        ModelCatalogEntry(
          id: 'qwen3.5-4b-search',
          name: 'Qwen 3.5 4B (Search)',
          description:
              'Best for web search integration. 8K context handles search snippets and multi-source answers.',
          category: 'search',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-4B-GGUF/resolve/main/Qwen_Qwen3.5-4B-Q4_K_M.gguf',
          localPath: 'qwen3.5-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'qwen3.5-9b-search',
          name: 'Qwen 3.5 9B (Search)',
          description:
              'Maximum quality for web search. 16K context for complex multi-source research tasks.',
          category: 'search',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-9B-GGUF/resolve/main/Qwen_Qwen3.5-9B-Q4_K_M.gguf',
          localPath: 'qwen3.5-9b.gguf',
          contextLength: 16384,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
    // ── Summarization & Analysis ───────────────────────────
    ModelCatalogCategory(
      name: 'Summarization & Analysis',
      icon: 'summarize',
      description:
          'Generate concise summaries, analyze text, and extract key information',
      entries: [
        ModelCatalogEntry(
          id: 'qwen3.5-4b-analysis',
          name: 'Qwen 3.5 4B (Analysis)',
          description:
              'Dual-mode thinking for deep analysis. Excellent at summarization and key point extraction.',
          category: 'summarization',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-4B-GGUF/resolve/main/Qwen_Qwen3.5-4B-Q4_K_M.gguf',
          localPath: 'qwen3.5-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'qwen3.5-9b-analysis',
          name: 'Qwen 3.5 9B (Analysis)',
          description:
              'Maximum quality for long document analysis. 16K context handles full articles and research papers.',
          category: 'summarization',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-9B-GGUF/resolve/main/Qwen_Qwen3.5-9B-Q4_K_M.gguf',
          localPath: 'qwen3.5-9b.gguf',
          contextLength: 16384,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
    // ── Translation ────────────────────────────────────────
    ModelCatalogCategory(
      name: 'Translation',
      icon: 'translate',
      description:
          'Strong multilingual support for text translation between languages',
      entries: [
        ModelCatalogEntry(
          id: 'qwen3.5-4b-translation',
          name: 'Qwen 3.5 4B (Multilingual)',
          description:
              'Excels at 29+ languages. Best for English, Chinese, Japanese, Korean, and European translations.',
          category: 'translation',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-4B-GGUF/resolve/main/Qwen_Qwen3.5-4B-Q4_K_M.gguf',
          localPath: 'qwen3.5-4b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
        ModelCatalogEntry(
          id: 'qwen3.5-2b-translation',
          name: 'Qwen 3.5 2B (Quick Translation)',
          description:
              'Fast lightweight translation. Great for quick language swaps on low-end devices.',
          category: 'translation',
          downloadUrl:
              'https://huggingface.co/bartowski/Qwen_Qwen3.5-2B-GGUF/resolve/main/Qwen_Qwen3.5-2B-Q4_K_M.gguf',
          localPath: 'qwen3.5-2b.gguf',
          contextLength: 8192,
          chatTemplateHint: 'qwen',
        ),
      ],
    ),
  ]);
}
