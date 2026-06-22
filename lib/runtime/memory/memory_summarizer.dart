import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/memory/memory_item.dart';
import 'package:sutra/runtime/pipeline/runtime_manager.dart';

/// Summarizes raw memory fragments into concise, high-signal facts.
///
/// Uses the on-device LLM to semantically compress related memories
/// (e.g. merging "likes Python" + "uses Python daily" → "User is a Python developer").
/// Falls back to heuristic extraction if the LLM is not ready.
class MemorySummarizer {
  const MemorySummarizer();

  /// Summarize raw memories into concise facts using the LLM.
  ///
  /// Returns a newline-separated list of `- fact` lines. Falls back
  /// to heuristic extraction if [runtime] is null or not ready.
  Future<String> summarize(
    List<MemoryItem> memories, {
    RuntimeManager? runtime,
  }) async {
    if (memories.isEmpty) return '';

    // Try LLM-based summarization first.
    if (runtime != null && runtime.isReady) {
      try {
        final result = await _summarizeWithLlm(memories, runtime);
        if (result.isNotEmpty) return result;
      } catch (e) {
        Log.w('[MemorySummarizer] LLM summarization failed, falling back to heuristic: $e');
      }
    }

    // Fallback: heuristic extraction (instant, no LLM).
    return _summarizeHeuristic(memories);
  }

  /// Use the LLM to produce a concise, merged summary of raw memories.
  Future<String> _summarizeWithLlm(
    List<MemoryItem> memories,
    RuntimeManager runtime,
  ) async {
    final buffer = StringBuffer();
    for (final mem in memories) {
      buffer.writeln('- ${mem.content}');
    }
    final rawFacts = buffer.toString();

    final prompt = 'Summarize the following facts about a user into a concise list. '
        'Merge related facts. Remove duplicates. Keep each fact short (one line). '
        'Output ONLY the summary lines, one per line, starting with "- ". '
        'Do not add any explanation or commentary.\n\nFacts:\n$rawFacts';

    final response = StringBuffer();
    await for (final token in runtime.generateStream(prompt)) {
      response.write(token);
    }

    // Validate and clean the LLM output.
    final lines = response.toString()
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && l.startsWith('- '))
        .toList();

    if (lines.isEmpty) return '';
    return lines.join('\n');
  }

  /// Heuristic extraction — instant, no LLM needed.
  String _summarizeHeuristic(List<MemoryItem> memories) {
    final facts = <String>[];
    final seen = <String>{};

    for (final mem in memories) {
      final fact = _extractFact(mem);
      if (fact == null) continue;

      final normalized = fact.toLowerCase().trim();
      if (seen.contains(normalized)) continue;
      seen.add(normalized);

      facts.add(fact);
    }

    if (facts.isEmpty) return '';
    return facts.map((f) => '- $f').join('\n');
  }

  /// Extract a clean fact from a raw memory fragment.
  String? _extractFact(MemoryItem mem) {
    var content = mem.content.trim();

    if (content.startsWith('User said: ')) {
      content = content.substring('User said: '.length).trim();
    } else if (content.startsWith('Preference: ')) {
      content = content.substring('Preference: '.length).trim();
    }

    if (content.length < 5 || content.length > 300) return null;

    final lower = content.toLowerCase();
    if (lower.startsWith('tell me') ||
        lower.startsWith('what is') ||
        lower.startsWith('how do')) {
      return null;
    }

    return content;
  }
}
