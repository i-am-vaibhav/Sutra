import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/runtime/context/context_settings.dart';

const _settingsKey = 'context_settings';

/// Manages [ContextSettings] with SharedPreferences persistence.
class ContextSettingsNotifier extends StateNotifier<ContextSettings> {
  ContextSettingsNotifier() : super(const ContextSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw != null) {
      try {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        state = _fromJson(json);
      } catch (_) {
        // Corrupted data — keep defaults.
      }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(_toJson(state)));
  }

  // ── Toggle helpers ──────────────────────────────────────

  void toggleUserProfile(bool value) {
    state = state.copyWith(userProfileEnabled: value);
    _save();
  }

  void toggleConversationMemory(bool value) {
    state = state.copyWith(conversationMemoryEnabled: value);
    _save();
  }

  void toggleDocumentIndex(bool value) {
    state = state.copyWith(documentIndexEnabled: value);
    _save();
  }

  // ── Profile field updates ──────────────────────────────

  void updateUserName(String value) {
    state = state.copyWith(userName: value);
    _save();
  }

  void updateUserProfession(String value) {
    state = state.copyWith(userProfession: value);
    _save();
  }

  void updateUserInterests(String value) {
    state = state.copyWith(userInterests: value);
    _save();
  }

  void updateUserExtraInfo(String value) {
    state = state.copyWith(userExtraInfo: value);
    _save();
  }

  // ── Document management ────────────────────────────────

  void addDocument(DocumentEntry doc) {
    state = state.copyWith(documents: [...state.documents, doc]);
    _save();
  }

  void removeDocument(String id) {
    state = state.copyWith(
      documents: state.documents.where((d) => d.id != id).toList(),
    );
    _save();
  }

  // ── Serialization ──────────────────────────────────────

  static Map<String, dynamic> _toJson(ContextSettings s) => {
    'userProfileEnabled': s.userProfileEnabled,
    'conversationMemoryEnabled': s.conversationMemoryEnabled,
    'documentIndexEnabled': s.documentIndexEnabled,
    'userName': s.userName,
    'userProfession': s.userProfession,
    'userInterests': s.userInterests,
    'userExtraInfo': s.userExtraInfo,
    'documents': s.documents.map((d) => d.toJson()).toList(),
  };

  static ContextSettings _fromJson(Map<String, dynamic> j) {
    final docs = (j['documents'] as List?)
            ?.map((d) => DocumentEntry.fromJson(d as Map<String, dynamic>))
            .toList() ??
        [];
    return ContextSettings(
      userProfileEnabled: j['userProfileEnabled'] as bool? ?? false,
      conversationMemoryEnabled:
          j['conversationMemoryEnabled'] as bool? ?? true,
      documentIndexEnabled: j['documentIndexEnabled'] as bool? ?? false,
      userName: j['userName'] as String? ?? '',
      userProfession: j['userProfession'] as String? ?? '',
      userInterests: j['userInterests'] as String? ?? '',
      userExtraInfo: j['userExtraInfo'] as String? ?? '',
      documents: docs,
    );
  }
}

final contextSettingsProvider =
    StateNotifierProvider<ContextSettingsNotifier, ContextSettings>((ref) {
  return ContextSettingsNotifier();
});
