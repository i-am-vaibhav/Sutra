import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/core/storage/prefs_helper.dart';

const _wifiOnlyKey = 'wifi_only_downloads';

class WifiOnlyNotifier extends StateNotifier<bool> {
  SharedPreferencesWithCache? _prefs;

  WifiOnlyNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    _prefs = await prefsCache();
    state = _prefs!.getBool(_wifiOnlyKey) ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final p = _prefs ?? await prefsCache();
    await p.setBool(_wifiOnlyKey, value);
  }
}

final wifiOnlyProvider = StateNotifierProvider<WifiOnlyNotifier, bool>(
  (ref) => WifiOnlyNotifier(),
);
