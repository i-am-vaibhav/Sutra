import 'dart:async';

import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/memory/memory_repository.dart';
import 'package:sutra/runtime/memory/memory_summarizer.dart';
import 'package:sutra/runtime/memory/memory_summary.dart';
import 'package:sutra/runtime/pipeline/runtime_manager.dart';

/// Schedules periodic memory summarization in the background.
///
/// Summarization is triggered after every [_messagesPerBatch] message
/// exchanges complete. The actual work runs in a microtask so the UI
/// thread is never blocked — the user sees zero lag.
///
/// Uses the on-device LLM for semantic compression (merging related
/// facts), falling back to heuristic extraction if the runtime is
/// not ready.
class MemoryScheduler {
  /// How many message exchanges between re-summarizations.
  static const int _messagesPerBatch = 5;

  final MemoryRepository _repository;
  final MemorySummarizer _summarizer;

  /// Callback to obtain the current RuntimeManager (may be null if model
  /// hasn't loaded yet).  Provided by the provider so the scheduler stays
  /// decoupled from the runtime lifecycle.
  final Future<RuntimeManager?> Function() _runtimeProvider;

  /// Counters per session — tracks how many exchanges since last summary.
  final Map<String, int> _counters = {};

  MemoryScheduler({
    required this._repository,
    required this._runtimeProvider,
    MemorySummarizer? summarizer,
  }) : _summarizer = summarizer ?? const MemorySummarizer();

  /// Call this after every completed message exchange (user msg → AI response).
  ///
  /// Returns immediately — the summarization runs in the background.
  void onExchangeComplete(String sessionId) {
    final count = (_counters[sessionId] ?? 0) + 1;
    _counters[sessionId] = count;

    if (count >= _messagesPerBatch) {
      _counters[sessionId] = 0;
      _runSummarization(sessionId);
    }
  }

  /// Force a summarization run (e.g., when switching sessions).
  void maybeSummarize(String sessionId) {
    final count = _counters[sessionId] ?? 0;
    if (count >= 2) {
      _counters[sessionId] = 0;
      _runSummarization(sessionId);
    }
  }

  /// Fire-and-forget background summarization.
  void _runSummarization(String sessionId) {
    unawaited(_summarizeAsync(sessionId));
  }

  Future<void> _summarizeAsync(String sessionId) async {
    try {
      final sw = Stopwatch()..start();

      final memories = await _repository.allForSession(sessionId);

      if (memories.isEmpty) {
        Log.d('[MemoryScheduler] No memories for session $sessionId, skipping');
        return;
      }

      // Try to get the runtime for LLM-based summarization.
      RuntimeManager? runtime;
      try {
        runtime = await _runtimeProvider();
      } catch (_) {
        // Runtime not available — will fall back to heuristic.
      }

      final summaryText = await _summarizer.summarize(
        memories,
        runtime: runtime,
      );

      if (summaryText.isEmpty) {
        Log.d('[MemoryScheduler] Summary empty for session $sessionId, skipping');
        return;
      }

      await _repository.saveSummary(MemorySummary(
        sessionId: sessionId,
        content: summaryText,
        updatedAt: DateTime.now(),
      ));

      // Prune old raw memories now that they've been compressed into a summary.
      // Keep the 50 most important as fallback if no summary is available yet.
      final pruned = await _repository.pruneOldMemories(
        sessionId,
        keepAtMost: 50,
      );

      sw.stop();
      Log.d(
        '[MemoryScheduler] Summarized ${memories.length} memories → '
        '${summaryText.length} chars, pruned $pruned raw (${sw.elapsedMilliseconds}ms)',
      );
    } catch (e) {
      Log.w('[MemoryScheduler] Summarization failed for $sessionId: $e');
    }
  }

  /// Reset counter for a session (e.g., when deleting a session).
  void reset(String sessionId) {
    _counters.remove(sessionId);
  }

  void dispose() {
    _counters.clear();
  }
}
