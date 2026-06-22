import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/features/chat/chat_provider.dart';
import 'package:sutra/runtime/tts/tts_provider.dart';

/// Shows the message actions bottom sheet (copy, reply, regenerate, delete).
///
/// Extracted from ChatScreen for better separation of concerns and
/// to reduce ChatScreen's widget size.
void showMessageActionsSheet(
  BuildContext context,
  WidgetRef ref,
  ChatMessage msg, {
  required VoidCallback onReply,
}) {
  final isUser = msg.role == ChatRole.user;
  final ttsState = ref.read(ttsProvider);
  final ttsNotifier = ref.read(ttsProvider.notifier);

  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () {
              Navigator.of(ctx).pop();
              Clipboard.setData(ClipboardData(text: msg.text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          if (!isUser && msg.text.isNotEmpty)
            ListTile(
              leading: Icon(
                ttsState.speakingMessageId == msg.id ? Icons.stop_circle : Icons.volume_up,
              ),
              title: Text(
                ttsState.speakingMessageId == msg.id ? 'Stop reading' : 'Read aloud',
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                ttsNotifier.speakMessage(msg.id, msg.text);
              },
            ),
          ListTile(
            leading: const Icon(Icons.reply),
            title: const Text('Reply'),
            onTap: () {
              Navigator.of(ctx).pop();
              ref.read(chatProvider.notifier).setQuote(msg.text, messageId: msg.id);
              onReply();
            },
          ),
          if (!isUser && msg.text.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Regenerate'),
              onTap: () {
                Navigator.of(ctx).pop();
                final messages = ref.read(chatProvider).messages;
                final msgIndex = messages.indexWhere((m) => m.id == msg.id);
                if (msgIndex > 0) {
                  final prevUser = messages.sublist(0, msgIndex).lastWhere(
                        (m) => m.role == ChatRole.user,
                        orElse: () => msg,
                      );
                  if (prevUser.role == ChatRole.user) {
                    ref.read(chatProvider.notifier).deleteMessage(msg.id);
                    ref.read(chatProvider.notifier).sendMessage(prevUser.text);
                  }
                }
              },
            ),
          ListTile(
            leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
            title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.of(ctx).pop();
              ref.read(chatProvider.notifier).deleteMessage(msg.id);
            },
          ),
        ],
      ),
    ),
  );
}
