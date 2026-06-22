import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sutra/core/storage/prefs_helper.dart';

/// Available sound effect options.
enum SoundEffect {
  click,
  chime,
  notification,
  off;

  String get label => switch (this) {
        SoundEffect.click => 'Click',
        SoundEffect.chime => 'Chime',
        SoundEffect.notification => 'Notification',
        SoundEffect.off => 'Off',
      };

  String get description => switch (this) {
        SoundEffect.click => 'Short system click',
        SoundEffect.chime => 'Platform alert chime',
        SoundEffect.notification => 'Platform alert tone',
        SoundEffect.off => 'No sound effects',
      };

  /// The system sound type to play for this effect.
  /// Returns `null` when the effect is off.
  SystemSoundType? get systemSoundType => switch (this) {
        SoundEffect.click => SystemSoundType.click,
        SoundEffect.chime => SystemSoundType.alert,
        SoundEffect.notification => SystemSoundType.alert,
        SoundEffect.off => null,
      };
}

/// Persists the user's sound effect choice across app restarts.
class SoundEffectNotifier extends StateNotifier<SoundEffect> {
  static const _key = 'sound_effect';

  SoundEffectNotifier() : super(SoundEffect.click) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await prefsCache();
    final index = prefs.getInt(_key);
    if (index != null && index < SoundEffect.values.length) {
      state = SoundEffect.values[index];
    }
  }

  Future<void> setEffect(SoundEffect effect) async {
    state = effect;
    final prefs = await prefsCache();
    await prefs.setInt(_key, effect.index);
  }
}

final soundEffectProvider =
    StateNotifierProvider<SoundEffectNotifier, SoundEffect>(
  (ref) => SoundEffectNotifier(),
);

/// Convenience helper that plays the user's configured sound effect.
class AppSound {
  AppSound._();

  /// Plays the configured sound effect if not off.
  static void play(SoundEffect effect) {
    final type = effect.systemSoundType;
    if (type != null) {
      SystemSound.play(type);
    }
  }
}
