import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _selectedModelKey = 'selected_model_id';

final selectedModelIdProvider =
    StateNotifierProvider<SelectedModelNotifier, String?>((ref) {
  return SelectedModelNotifier();
});

class SelectedModelNotifier extends StateNotifier<String?> {
  SelectedModelNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_selectedModelKey);
  }

  Future<void> select(String? modelId) async {
    state = modelId;
    final prefs = await SharedPreferences.getInstance();
    if (modelId == null) {
      await prefs.remove(_selectedModelKey);
    } else {
      await prefs.setString(_selectedModelKey, modelId);
    }
  }
}
