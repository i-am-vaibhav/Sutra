import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _wifiOnlyKey = 'wifi_only_downloads';

/// Manages the WiFi-only download preference with SharedPreferences persistence.
class WifiOnlyNotifier extends StateNotifier<bool> {
  WifiOnlyNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_wifiOnlyKey) ?? true;
  }

  Future<void> toggle(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wifiOnlyKey, value);
  }
}

final wifiOnlyProvider = StateNotifierProvider<WifiOnlyNotifier, bool>(
  (ref) => WifiOnlyNotifier(),
);
