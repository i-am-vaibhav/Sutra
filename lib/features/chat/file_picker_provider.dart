import 'package:sutra/core/logging/log.dart';
import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sutra/features/chat/file_storage_service.dart';
import 'package:sutra/features/chat/uploaded_file.dart';

const _filesKey = 'uploaded_files';

/// Manages the list of uploaded files and per-message selection state.
class UploadedFilesNotifier extends StateNotifier<List<UploadedFile>> {
  final FileStorageService _storage = FileStorageService();

  UploadedFilesNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_filesKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List)
            .map((e) => UploadedFile.fromJson(e as Map<String, dynamic>))
            .toList();
        state = list;
      } catch (_) { Log.d("[FilePickerProvider] Load failed"); }
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _filesKey,
      jsonEncode(state.map((f) => f.toJson()).toList()),
    );
  }

  /// Pick and add a new file. Returns the uploaded file, or null if cancelled.
  Future<UploadedFile?> addFile() async {
    final file = await _storage.pickAndStoreFile();
    if (file == null) return null;
    state = [...state, file];
    await _save();
    return file;
  }

  /// Remove a file by id and delete it from disk.
  Future<void> removeFile(String id) async {
    final file = state.where((f) => f.id == id).firstOrNull;
    if (file != null) {
      await _storage.deleteFile(file);
    }
    state = state.where((f) => f.id != id).toList();
    await _save();
  }

  /// Extract text content from a file (for prompt injection).
  Future<String> extractText(UploadedFile file) async {
    return _storage.extractText(file);
  }
}

final uploadedFilesProvider =
    StateNotifierProvider<UploadedFilesNotifier, List<UploadedFile>>((ref) {
  return UploadedFilesNotifier();
});

/// IDs of files selected for the current message being composed.
class SelectedFileIdsNotifier extends StateNotifier<Set<String>> {
  SelectedFileIdsNotifier() : super(const {});

  void toggle(String id) {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state, id};
    }
  }

  void clear() => state = const {};

  void selectAll(List<String> ids) => state = ids.toSet();
}

final selectedFileIdsProvider =
    StateNotifierProvider<SelectedFileIdsNotifier, Set<String>>((ref) {
  return SelectedFileIdsNotifier();
});
