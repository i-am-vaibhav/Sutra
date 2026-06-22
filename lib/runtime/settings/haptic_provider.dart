import 'package:flutter/services.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sutra/core/storage/prefs_helper.dart';

/// Available haptic feedback intensities.
enum HapticIntensity {
  light,
  medium,
  heavy,
  off;

  String get label => switch (this) {
        HapticIntensity.light => 'Light',
        HapticIntensity.medium => 'Medium',
        HapticIntensity.heavy => 'Heavy',
        HapticIntensity.off => 'Off',
      };

  String get description => switch (this) {
        HapticIntensity.light => 'Subtle tap feedback',
        HapticIntensity.medium => 'Noticeable vibration',
        HapticIntensity.heavy => 'Strong vibration',
        HapticIntensity.off => 'No haptic feedback',
      };
}

/// Persists the user's haptic intensity choice across app restarts.
class HapticIntensityNotifier extends StateNotifier<HapticIntensity> {
  static const _key = 'haptic_intensity';

  HapticIntensityNotifier() : super(HapticIntensity.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await prefsCache();
    final index = prefs.getInt(_key);
    if (index != null && index < HapticIntensity.values.length) {
      state = HapticIntensity.values[index];
    }
  }

  Future<void> setIntensity(HapticIntensity intensity) async {
    state = intensity;
    final prefs = await prefsCache();
    await prefs.setInt(_key, intensity.index);
  }
}

final hapticIntensityProvider =
    StateNotifierProvider<HapticIntensityNotifier, HapticIntensity>(
  (ref) => HapticIntensityNotifier(),
);

/// Convenience helper that triggers haptic feedback at the user's configured
/// intensity. Call [light], [medium], or [heavy] to fire the corresponding
/// [HapticFeedback] call only if the configured intensity is at least that level.
class AppHaptic {
  AppHaptic._();

  /// Fires [HapticFeedback.lightImpact] if intensity is light or higher.
  static void light(HapticIntensity intensity) {
    if (intensity == HapticIntensity.off) return;
    HapticFeedback.lightImpact();
  }

  /// Fires [HapticFeedback.mediumImpact] if intensity is medium or higher.
  static void medium(HapticIntensity intensity) {
    if (intensity == HapticIntensity.light || intensity == HapticIntensity.off) {
      return;
    }
    HapticFeedback.mediumImpact();
  }

  /// Fires [HapticFeedback.heavyImpact] if intensity is heavy.
  static void heavy(HapticIntensity intensity) {
    if (intensity != HapticIntensity.heavy) return;
    HapticFeedback.heavyImpact();
  }
}
