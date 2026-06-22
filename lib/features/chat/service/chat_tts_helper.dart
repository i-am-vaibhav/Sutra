import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/features/chat/chat_provider.dart';
import 'package:sutra/runtime/tts/tts_provider.dart';

/// Manages smart streaming TTS for chat responses.
///
/// Reads assistant responses aloud as they stream in, with debouncing
/// to avoid excessive TTS calls. Extracted from ChatScreen for better
/// separation of concerns and testability.
class ChatTtsHelper {
  final WidgetRef _ref;

  Timer? _streamingReadTimer;
  String? _streamingReadMessageId;
  String _streamingReadBuffer = '';
  int _streamingSpokenCharCount = 0;

  /// Whether a streaming TTS read is currently active.
  bool get isStreamingActive => _streamingReadMessageId != null;

  /// The current autoScroll state — TTS only fires when the user
  /// is near the bottom of the conversation.
  bool _autoScroll = true;

  /// Update the autoScroll state from the parent widget.
  void updateAutoScroll(bool value) => _autoScroll = value;

  static const _streamingReadDelay = Duration(seconds: 2);
  static const _minCharsForStreamingTts = 200;

  ChatTtsHelper(this._ref);

  /// Handle streaming TTS during active generation.
  ///
  /// Called on every state update while `isGenerating` is true.
  void handleStreamingTts(List<ChatMessage> messages) {
    final ttsState = _ref.read(ttsProvider);
    if (!ttsState.isEnabled) return;

    ChatMessage? lastAssistant;
    for (int i = messages.length - 1; i >= 0; i--) {
      if (messages[i].role == ChatRole.assistant) {
        lastAssistant = messages[i];
        break;
      }
    }
    if (lastAssistant == null || lastAssistant.text.isEmpty) return;

    if (_streamingReadMessageId != lastAssistant.id) {
      _streamingReadMessageId = lastAssistant.id;
      _streamingReadBuffer = lastAssistant.text;
      _streamingSpokenCharCount = 0;
      _scheduleStreamingRead(lastAssistant.id);
      return;
    }

    _streamingReadBuffer = lastAssistant.text;
    if (_streamingSpokenCharCount == 0) {
      _scheduleStreamingRead(lastAssistant.id);
    }
  }

  /// Handle generation completion — speak the final response if needed.
  void handleGenerationComplete(ChatState chatState, {required bool autoScroll}) {
    final ttsState = _ref.read(ttsProvider);
    if (!ttsState.isEnabled) return;

    _streamingReadTimer?.cancel();

    ChatMessage? lastAssistant;
    for (int i = chatState.messages.length - 1; i >= 0; i--) {
      if (chatState.messages[i].role == ChatRole.assistant) {
        lastAssistant = chatState.messages[i];
        break;
      }
    }

    if (lastAssistant == null || lastAssistant.text.isEmpty) {
      _streamingReadMessageId = null;
      _streamingReadBuffer = '';
      _streamingSpokenCharCount = 0;
      return;
    }

    final fullText = lastAssistant.text;
    final wasStreamingForThisMsg = _streamingReadMessageId == lastAssistant.id;

    if (!wasStreamingForThisMsg) {
      _ref.read(ttsProvider.notifier).speakMessage(lastAssistant.id, fullText);
    } else if (_streamingSpokenCharCount == 0) {
      _ref.read(ttsProvider.notifier).speakMessage(lastAssistant.id, fullText);
    } else if (fullText.length > _streamingSpokenCharCount + 50) {
      _ref.read(ttsProvider.notifier).speakMessage(lastAssistant.id, fullText);
    }

    _streamingReadMessageId = null;
    _streamingReadBuffer = '';
    _streamingSpokenCharCount = 0;
  }

  /// Reset TTS state when switching sessions.
  void reset() {
    _streamingReadMessageId = null;
    _streamingReadBuffer = '';
    _streamingReadTimer?.cancel();
  }

  /// Cancel streaming TTS when user scrolls away from bottom.
  void cancelIfActive() {
    if (_streamingReadTimer?.isActive == true) {
      _streamingReadTimer?.cancel();
    }
  }

  void _scheduleStreamingRead(String messageId) {
    _streamingReadTimer?.cancel();
    _streamingReadTimer = Timer(_streamingReadDelay, () {
      if (!_autoScroll) return;
      final currentText = _streamingReadBuffer;
      if (currentText.length >= _minCharsForStreamingTts) {
        _streamingSpokenCharCount = currentText.length;
        _ref.read(ttsProvider.notifier).speakMessage(messageId, currentText);
      }
    });
  }

  void dispose() {
    _streamingReadTimer?.cancel();
  }
}
