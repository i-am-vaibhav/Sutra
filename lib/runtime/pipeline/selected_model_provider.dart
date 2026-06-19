import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _selectedModelKey = 'selected_model_id';

final selectedModelIdProvider =
    StateNotifierProvider<SelectedModelNotifier, String?>((ref) {
  return SelectedModelNotifier();
});

const String autoModelId = 'auto';

class SelectedModelNotifier extends StateNotifier<String?> {
  SelectedModelNotifier() : super(null) {
    _load();
  }

  static const _autoChosenKey = 'user_chose_auto';
  bool _userChoseAuto = false;
  bool get userChoseAuto => _userChoseAuto;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getString(_selectedModelKey);
    _userChoseAuto = prefs.getBool(_autoChosenKey) ?? false;
  }

  bool get isAuto => state == null || state == autoModelId;

  Future<void> select(String? modelId) async {
    final prefs = await SharedPreferences.getInstance();
    if (modelId == null || modelId == autoModelId) {
      _userChoseAuto = true;
      state = null;
      await prefs.setString(_selectedModelKey, autoModelId);
      await prefs.setBool(_autoChosenKey, true);
    } else {
      _userChoseAuto = false;
      state = modelId;
      await prefs.setString(_selectedModelKey, modelId);
      await prefs.setBool(_autoChosenKey, false);
    }
  }

  void selectTemporary(String? modelId) {
    state = modelId;
  }
}
