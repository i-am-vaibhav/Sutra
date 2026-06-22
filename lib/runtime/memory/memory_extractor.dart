import 'package:sutra/core/feature_flags.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/memory/memory_item.dart';
import 'package:sutra/runtime/pipeline/runtime_manager.dart';

class MemoryExtractor {
  List<MemoryItem> extract(String userMessage, [String? assistantReply]) {
    final List<MemoryItem> items = [];

    if (userMessage.length > 20) {
      items.add(MemoryItem(
        id: DateTime.now().toIso8601String(),
        content: "User said: $userMessage",
        createdAt: DateTime.now(),
        importance: 0.7,
      ));
    }

    if (userMessage.contains("like") ||
        userMessage.contains("prefer") ||
        userMessage.contains("want")) {
      items.add(MemoryItem(
        id: DateTime.now().toIso8601String(),
        content: "Preference: $userMessage",
        createdAt: DateTime.now(),
        importance: 0.9,
      ));
    }

    return items;
  }

  /// v1: Regex-only extraction by default. LLM extraction gated behind
  /// [FeatureFlag.llmMemory]. When disabled, always uses regex fallback.
  Future<List<MemoryItem>> extractWithLLM(
    String userMessage,
    RuntimeManager? runtime, {
    String? assistantReply,
  }) async {
    // Gate LLM extraction behind the feature flag.
    if (runtime == null || !runtime.isReady) {
      return extract(userMessage, assistantReply ?? '');
    }

    // If LLM memory flag is off, always use regex (v1 default).
    final flags = await loadFeatureFlags();
    if (!flags.isEnabled(FeatureFlag.llmMemory)) {
      return extract(userMessage, assistantReply ?? '');
    }

    try {
      final prompt = 'Extract key facts, preferences, and identity information from this conversation. '
          'Return ONLY a JSON array of objects with "content" and "importance" fields. '
          'Importance: 0.0-1.0.\nUser: $userMessage\nJSON:';

      final responseBuffer = StringBuffer();
      await for (final token in runtime.generateStream(prompt)) {
        responseBuffer.write(token);
      }

      final response = responseBuffer.toString();
      final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(response);
      if (jsonMatch != null) {
        final items = <MemoryItem>[];
        final contents = RegExp(r'"content":\s*"([^"]+)"').allMatches(jsonMatch.group(0)!);
        final importances = RegExp(r'"importance":\s*([\d.]+)').allMatches(jsonMatch.group(0)!);
        final now = DateTime.now();
        final contentList = contents.map((m) => m.group(1)!).toList();
        final impList = importances.map((m) => double.parse(m.group(1)!)).toList();
        for (var i = 0; i < contentList.length && i < 3; i++) {
          final imp = i < impList.length ? impList[i] : 0.7;
          if (contentList[i].isNotEmpty && imp > 0.3) {
            items.add(MemoryItem(
              id: '${now.millisecondsSinceEpoch}_llm_$i',
              content: contentList[i],
              createdAt: now,
              importance: imp.clamp(0.0, 1.0),
            ));
          }
        }
        if (items.isNotEmpty) {
          Log.d('[MemoryExtractor] LLM extracted ${items.length} memories');
          return items;
        }
      }
    } catch (e) {
      Log.w('[MemoryExtractor] LLM extraction failed, falling back to regex: $e');
    }

    return extract(userMessage, assistantReply ?? '');
  }
}