import 'package:shared_preferences/shared_preferences.dart';

class ModelStore {
  static const _key = "installed_models";

  Future<Set<String>> loadInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }

  Future<void> saveInstalled(Set<String> models) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, models.toList());
  }
}