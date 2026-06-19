import 'package:flutter_riverpod/legacy.dart';
import 'package:sutra/core/storage/prefs_helper.dart';

const _keepScreenOnKey = 'keep_screen_on';

class KeepScreenOnNotifier extends StateNotifier<bool> {
  KeepScreenOnNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await prefsCache();
    state = prefs.getBool(_keepScreenOnKey) ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await prefsCache();
    await prefs.setBool(_keepScreenOnKey, value);
  }
}

final keepScreenOnProvider = StateNotifierProvider<KeepScreenOnNotifier, bool>(
  (ref) => KeepScreenOnNotifier(),
);
