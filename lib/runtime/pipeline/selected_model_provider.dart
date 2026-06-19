import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/core/storage/prefs_helper.dart';

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

  SharedPreferencesWithCache? _prefs;

  Future<void> _load() async {
    _prefs = await prefsCache();
    state = _prefs!.getString(_selectedModelKey);
    _userChoseAuto = _prefs!.getBool(_autoChosenKey) ?? false;
  }

  bool get isAuto => state == null || state == autoModelId;

  Future<void> select(String? modelId) async {
    final p = _prefs ?? await prefsCache();
    if (modelId == null || modelId == autoModelId) {
      _userChoseAuto = true;
      state = null;
      await p.setString(_selectedModelKey, autoModelId);
      await p.setBool(_autoChosenKey, true);
    } else {
      _userChoseAuto = false;
      state = modelId;
      await p.setString(_selectedModelKey, modelId);
      await p.setBool(_autoChosenKey, false);
    }
  }

  void selectTemporary(String? modelId) {
    state = modelId;
  }
}
