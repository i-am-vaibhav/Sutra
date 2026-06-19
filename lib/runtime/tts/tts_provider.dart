import 'dart:async';

import 'package:sutra/core/logging/log.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/runtime/tts/tts_service.dart';

const _enabledKey = 'read_aloud_enabled';
const _voiceKey = 'read_aloud_voice';

/// State for the TTS provider.
class TtsState {
  final bool isEnabled;
  final bool isSpeaking;
  final String? speakingMessageId;
  final String selectedVoiceName;
  final String selectedVoiceLocale;

  const TtsState({
    this.isEnabled = false,
    this.isSpeaking = false,
    this.speakingMessageId,
    this.selectedVoiceName = '',
    this.selectedVoiceLocale = '',
  });

  TtsState copyWith({
    bool? isEnabled,
    bool? isSpeaking,
    String? speakingMessageId,
    bool clearSpeakingMessage = false,
    String? selectedVoiceName,
    String? selectedVoiceLocale,
  }) {
    return TtsState(
      isEnabled: isEnabled ?? this.isEnabled,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      speakingMessageId: clearSpeakingMessage
          ? null
          : (speakingMessageId ?? this.speakingMessageId),
      selectedVoiceName: selectedVoiceName ?? this.selectedVoiceName,
      selectedVoiceLocale:
          selectedVoiceLocale ?? this.selectedVoiceLocale,
    );
  }
}

/// Manages TTS state: enable/disable, voice selection, speak/stop lifecycle.
class TtsNotifier extends StateNotifier<TtsState> {
  TtsNotifier() : super(const TtsState()) {
    _load();
  }

  final TtsService _tts = TtsService.instance;

  // ── Persistent state ────────────────────────────────────

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    final voiceRaw = prefs.getString(_voiceKey);

    String voiceName = '';
    String voiceLocale = '';
    if (voiceRaw != null && voiceRaw.contains('|')) {
      final parts = voiceRaw.split('|');
      voiceName = parts[0];
      voiceLocale = parts.length > 1 ? parts[1] : '';
    }

    state = state.copyWith(
      isEnabled: enabled,
      selectedVoiceName: voiceName,
      selectedVoiceLocale: voiceLocale,
    );

    if (voiceName.isNotEmpty && voiceLocale.isNotEmpty) {
      await _tts.setVoice({'name': voiceName, 'locale': voiceLocale});
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, state.isEnabled);
    if (state.selectedVoiceName.isNotEmpty) {
      await prefs.setString(_voiceKey,
          '${state.selectedVoiceName}|${state.selectedVoiceLocale}');
    }
  }

  // ── Public API ──────────────────────────────────────────

  void toggleEnabled(bool value) {
    state = state.copyWith(isEnabled: value);
    _save();
    if (!value && state.isSpeaking) {
      stop();
    }
  }

  Future<void> setVoice(String name, String locale) async {
    state = state.copyWith(
      selectedVoiceName: name,
      selectedVoiceLocale: locale,
    );
    await _tts.setVoice({'name': name, 'locale': locale});
    _save();
  }

  /// Speak a specific message by its ID.
  Future<void> speakMessage(String messageId, String text) async {
    if (text.trim().isEmpty) return;

    // If already speaking this message, stop it.
    if (state.isSpeaking && state.speakingMessageId == messageId) {
      await stop();
      return;
    }

    // Set up callbacks.
    _tts.setCompletionHandler(() {
      state = state.copyWith(
        isSpeaking: false,
        clearSpeakingMessage: true,
      );
    });


    _tts.setErrorHandler((msg) {
      Log.d('[TtsProvider] Error: $msg');
      state = state.copyWith(
        isSpeaking: false,
        clearSpeakingMessage: true,
      );
    });

    state = state.copyWith(
      isSpeaking: true,
      speakingMessageId: messageId,
    );

    await _tts.speak(text);
  }

  /// Stop all speech.
  Future<void> stop() async {
    await _tts.stop();
    state = state.copyWith(
      isSpeaking: false,
      clearSpeakingMessage: true,
    );
  }
}

final ttsProvider =
    StateNotifierProvider<TtsNotifier, TtsState>((ref) {
  return TtsNotifier();
});
