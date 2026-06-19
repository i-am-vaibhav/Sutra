import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:sutra/core/storage/chat_repository.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';

/// After 2+ user messages, generate a concise title using the model.
Future<void> maybeGenerateTitle(
  Ref ref, {
  required String sessionId,
  required List<ChatMessage> messages,
  required bool isGenerating,
  required Set<String> titledSessions,
}) async {
  // Don't generate a title if more messages are queued or generating.
  if (isGenerating) return;

  // Don't re-generate if we already titled this session.
  if (titledSessions.contains(sessionId)) return;

  final userMsgCount = messages
      .where((m) => m.role == ChatRole.user)
      .length;
  // Generate after the 2nd assistant reply (first real exchange).
  if (userMsgCount < 2) return;

  try {
    final repo = ref.read(chatRepositoryProvider);
    // Build a short transcript of the conversation.
    final transcript = messages
        .where((m) => m.text.isNotEmpty)
        .take(6) // first 3 exchanges max
        .map((m) => '${m.role == ChatRole.user ? 'User' : 'Assistant'}: ${m.text}')
        .join('\n');

    final titlePrompt = 'Generate a short conversation title (max 5 words) for this dialogue. Reply with ONLY the title, no quotes or extra text.\n\n$transcript';

    final runtimeManager = await ref.read(runtimeProvider.future);
    var title = '';
    await for (final token in runtimeManager.generateStream(titlePrompt)) {
      title += token;
      if (title.length > 60) break;
    }
    title = title.trim().replaceAll(RegExp(r'["\n]'), '');
    if (title.isEmpty) return;

    Log.d('[ChatNotifier] Generated title: "$title"');
    titledSessions.add(sessionId);
    await repo.updateSessionTitle(sessionId, title);
  } catch (e) {
    Log.w('[ChatNotifier] Title generation failed: $e');
    // Mark as attempted to avoid retrying on every message.
    titledSessions.add(sessionId);
  }
}

/// Auto-generate a title from the first user message.
String autoTitle(String text) {
  if (text.length <= 40) return text;
  return '${text.substring(0, 40)}…';
}
