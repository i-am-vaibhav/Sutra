import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/core/storage/prefs_helper.dart';

/// Persists the user's theme mode choice across app restarts.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const _key = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  SharedPreferencesWithCache? _prefs;

  Future<void> _load() async {
    _prefs = await prefsCache();
    final index = _prefs!.getInt(_key);
    if (index != null && index < ThemeMode.values.length) {
      state = ThemeMode.values[index];
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final p = _prefs ?? await prefsCache();
    await p.setInt(_key, mode.index);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(),
);
