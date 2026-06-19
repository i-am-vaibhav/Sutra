import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Singleton service wrapping [FlutterTts] for text-to-speech.
///
/// Handles initialization, voice configuration, and speech lifecycle.
/// Uses queue mode so multiple speak() calls play sequentially.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  // ── Initialization ──────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // Platform-specific audio category (iOS only).
    try {
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    } catch (_) {
      Log.d('[TtsService] iOS audio category not supported on this platform');
    }

    // Queue mode: each speak() call appends to the queue.
    await _tts.setQueueMode(1);

    // Sensible defaults.
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    // On Android, awaitSpeakCompletion helps the engine be ready
    // before we call getVoices.
    try {
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {
      Log.d('[TtsService] awaitSpeakCompletion not supported on this platform');
    }

    _initialized = true;
    Log.d('[TtsService] Initialized');
  }

  // ── Voice Configuration ─────────────────────────────────

  /// Get available voices on this device.
  Future<List<Map<String, String>>> getVoices() async {
    await init();
    try {
      final raw = await _tts.getVoices;
      final voices = raw
          .map((v) => Map<String, String>.from(v as Map))
          .toList();
      Log.d('[TtsService] Found ${voices.length} voices');
      return voices;
    } catch (e) {
      Log.d('[TtsService] Failed to get voices: $e');
      return [];
    }
  }

  /// Set the voice by name and locale.
  Future<void> setVoice(Map<String, String> voice) async {
    await init();
    await _tts.setVoice(voice);
    Log.d('[TtsService] Voice set to: ${voice['name']} (${voice['locale']})');
  }

  // ── Speech Controls ─────────────────────────────────────

  /// Speak the given text.
  Future<void> speak(String text) async {
    await init();
    if (text.trim().isEmpty) return;
    await _tts.speak(text);
  }

  /// Stop all speech immediately and clear the queue.
  Future<void> stop() async {
    await init();
    await _tts.stop();
  }

  /// Pause speech (platform-dependent support).
  Future<void> pause() async {
    await init();
    await _tts.pause();
  }

  // ── Configuration ───────────────────────────────────────

  Future<void> setSpeechRate(double rate) async {
    await init();
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  Future<void> setPitch(double pitch) async {
    await init();
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  }

  Future<void> setVolume(double volume) async {
    await init();
    await _tts.setVolume(volume.clamp(0.0, 1.0));
  }

  // ── Callbacks ───────────────────────────────────────────

  void setCompletionHandler(VoidCallback handler) {
    _tts.setCompletionHandler(handler);
  }

  void setErrorHandler(void Function(String message) handler) {
    _tts.setErrorHandler((msg) => handler(msg));
  }
}
