import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/features/chat/file_picker_provider.dart';
import 'package:sutra/features/chat/model_selection.dart';
import 'package:sutra/runtime/context/context_settings_provider.dart';
import 'package:sutra/runtime/memory/conversation_summarizer.dart';
import 'package:sutra/runtime/memory/memory_provider.dart';
import 'package:sutra/runtime/memory/memory_repository.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/provisioning/model_manager_provider.dart';
import 'package:sutra/runtime/pipeline/chat_template.dart';
import 'package:sutra/runtime/pipeline/context_builder.dart';
import 'package:sutra/runtime/pipeline/runtime_manager.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';

/// Pre-compiled RegExp constants — avoid re-creating on hot paths.
final _specialTokenRe = RegExp(r'<\|[^|]*\|>');
final _whitespaceRe = RegExp(r'\s+');

/// Assembled context ready for LLM prompt construction.
class AssembledContext {
  final String prompt;
  final ModelDefinition? modelDef;
  final String sessionId;

  const AssembledContext({
    required this.prompt,
    required this.modelDef,
    required this.sessionId,
  });
}

/// Handles all context assembly for message processing:
/// model selection, memory retrieval, file extraction, and prompt construction.
class ContextAssemblyService {
  final Ref _ref;

  ContextAssemblyService(this._ref);

  /// Assemble the full LLM prompt from all context sources.
  ///
  /// [sessionId] — the active session (auto-created if null).
  /// [cleanedText] — the user's trimmed message.
  /// [chatHistory] — current messages list including the new user message.
  /// [quote] — optional quoted text from a previous message.
  /// [quoteMsgId] — ID of the quoted message to exclude from history.
  /// [selectedFileIds] — optional file attachments.
  Future<AssembledContext> assemble({
    required String sessionId,
    required String cleanedText,
    required List<ChatMessage> chatHistory,
    String? quote,
    String? quoteMsgId,
    Set<String>? selectedFileIds,
  }) async {
    final memoryRepo = _ref.read(memoryRepositoryProvider);
    final contextSettings = _ref.read(contextSettingsProvider);

    // ── Model selection ──────────────────────────────────
    final selectedId = _ref.read(selectedModelIdProvider);
    final hasFiles = selectedFileIds?.isNotEmpty == true;
    var effectiveId = selectedId;
    if (selectedId == null) {
      effectiveId = selectBestModel(_ref, hasFiles: hasFiles, msgLength: cleanedText.length);
      if (effectiveId != null) {
        _ref.read(selectedModelIdProvider.notifier).selectTemporary(effectiveId);
      }
    }
    var modelDef = effectiveId != null
        ? ModelRegistry.all.where((m) => m.id == effectiveId).firstOrNull
        : ModelRegistry.all.firstOrNull;

    // ── Effective user text (with quote) ─────────────────
    final effectiveUserText = quote != null
        ? 'In reference to: "$quote"\n\n$cleanedText'
        : cleanedText;

    // ── History summarization (sliding window) ─────────
    var historyForPrompt = quoteMsgId != null
        ? chatHistory.where((m) => m.id != quoteMsgId).toList()
        : chatHistory;

    // If history exceeds context budget, compress old messages.
    final ctxLen = modelDef?.contextLength ?? 2048;
    final maxMsgs = _adaptiveMaxMessages(ctxLen);
    if (historyForPrompt.length > maxMsgs) {
      RuntimeManager? runtime;
      try {
        runtime = await _ref.read(runtimeProvider.future);
      } catch (_) {}
      historyForPrompt = await const ConversationSummarizer().summarizeIfNeeded(
        messages: historyForPrompt,
        maxMessages: maxMsgs,
        maxChars: _adaptiveMaxChars(ctxLen),
        runtime: runtime,
      );
    }

    // ── Memory retrieval (session-scoped) ─────────────
    String? memoryText;
    if (contextSettings.conversationMemoryEnabled) {
      memoryText = await _retrieveMemory(memoryRepo, sessionId);
    }

    // ── File content extraction ──────────────────────────
    var effectiveCtxLen = ctxLen;
    String? fileContent;
    if (selectedFileIds != null && selectedFileIds.isNotEmpty) {
      final result = await _extractFileContent(selectedFileIds, effectiveCtxLen);
      fileContent = result.content;
      if (result.modelDef != null) {
        modelDef = result.modelDef;
        effectiveCtxLen = result.modelDef!.contextLength;
      }
    }

    // ── Prompt construction ──────────────────────────────
    final contextBuilder = ContextBuilder(
      chatTemplate: modelDef?.chatTemplate ?? const GenericChatTemplate(),
      maxMessages: _adaptiveMaxMessages(effectiveCtxLen),
      maxChars: _adaptiveMaxChars(effectiveCtxLen),
    );

    final systemPrompt = _ref.read(systemPromptProvider);
    final prompt = contextBuilder.buildFullPrompt(
      systemPrompt: systemPrompt,
      chatHistory: historyForPrompt,
      userMessage: effectiveUserText,
      memoryText: memoryText,
      userProfileText: contextSettings.buildUserProfilePrompt(),
      fileContent: fileContent,
    );

    return AssembledContext(
      prompt: prompt,
      modelDef: modelDef,
      sessionId: sessionId,
    );
  }

  /// Retrieve the top-N most important memories as prompt context.
  /// Scoped to the current session only.
  Future<String?> _retrieveMemory(
    MemoryRepository memoryRepo,
    String sessionId,
  ) async {
    final memories = await memoryRepo.top(limit: 5, sessionId: sessionId);
    if (memories.isEmpty) return null;
    return memories.map((m) => '- ${m.content}').join('\n');
  }

  /// Extract text content from attached files.
  Future<_FileExtractionResult> _extractFileContent(
    Set<String> fileIds,
    int currentCtxLen,
  ) async {
    final allFiles = _ref.read(uploadedFilesProvider);
    final selectedFiles = allFiles.where((f) => fileIds.contains(f.id)).toList();
    if (selectedFiles.isEmpty) return const _FileExtractionResult();

    ModelDefinition? modelDefOverride;

    // If current model has <4K context, try to find a bigger one
    var ctxLen = currentCtxLen;
    if (ctxLen < 4096) {
      final manager = _ref.read(modelManagerProvider);
      final installed = manager.state.installedIds;
      final bigger = ModelRegistry.all
          .where((m) => installed.contains(m.id) && m.contextLength >= 4096)
          .toList()
        ..sort((a, b) => b.contextLength.compareTo(a.contextLength));
      if (bigger.isNotEmpty) {
        modelDefOverride = bigger.first;
        ctxLen = bigger.first.contextLength;
      }
    }

    final maxFileChars = (ctxLen * 4 * 0.4).toInt();
    final filesNotifier = _ref.read(uploadedFilesProvider.notifier);
    final buf = StringBuffer('Attached files:');
    for (final file in selectedFiles) {
      buf.write('\n\n--- ${file.displayName} (${file.fileTypeLabel}) ---\n');
      try {
        var content = await filesNotifier.extractText(file);
        content = content.replaceAll(_specialTokenRe, ' ').replaceAll(_whitespaceRe, ' ').trim();
        if (content.length > maxFileChars) {
          content = '${content.substring(0, maxFileChars)}\n... [truncated to fit model context]';
        }
        buf.write(content);
      } catch (e) {
        buf.write('[Could not read file: $e]');
      }
      buf.write('\n---');
    }
    var fileContent = buf.toString();
    if (fileContent.length > maxFileChars) {
      fileContent = '${fileContent.substring(0, maxFileChars)}\n... [truncated to fit model context]';
    }

    return _FileExtractionResult(
      content: fileContent,
      modelDef: modelDefOverride?.contextLength != 0 ? modelDefOverride : null,
    );
  }

  /// Adaptive max messages based on context window size.
  int _adaptiveMaxMessages(int contextLength) {
    if (contextLength >= 8192) return 24;
    if (contextLength >= 4096) return 16;
    return 12;
  }

  /// Adaptive max chars based on context window size.
  int _adaptiveMaxChars(int contextLength) {
    if (contextLength >= 8192) return 6000;
    if (contextLength >= 4096) return 4000;
    return 3000;
  }
}

class _FileExtractionResult {
  final String? content;
  final ModelDefinition? modelDef;
  const _FileExtractionResult({this.content, this.modelDef});
}
