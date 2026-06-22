import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:sutra/core/storage/prefs_helper.dart';

/// Centralized feature flags for gating advanced features.
///
/// **v1 → v2 migration**: To enable a feature in v2, flip its default
/// in [_kDefaults] from `false` to `true`. The existing SharedPreferences
/// value takes precedence, so users who explicitly disabled a feature
/// won't be surprised by it turning back on.
enum FeatureFlag {
  /// Web search integration — allows querying the web for answers.
  webSearch,

  /// File attachments — allows uploading and analyzing files.
  fileAttachments,

  /// LLM-based memory extraction — uses the on-device model to extract
  /// structured memories from conversations (vs regex-only fallback).
  llmMemory,

  /// Model warm-up on startup — pre-generates tokens to trigger JIT/AOT
  /// compilation. Adds 2-5s to startup but speeds up first response.
  modelWarmUp,
}

/// Display name for each flag (used in Settings UI).
String featureFlagName(FeatureFlag flag) => switch (flag) {
      FeatureFlag.webSearch => 'Web Search',
      FeatureFlag.fileAttachments => 'File Attachments',
      FeatureFlag.llmMemory => 'Smart Memory',
      FeatureFlag.modelWarmUp => 'Model Warm-Up',
    };

/// Human-readable description for each flag.
String featureFlagDescription(FeatureFlag flag) => switch (flag) {
      FeatureFlag.webSearch =>
        'Search the web for up-to-date answers with citations',
      FeatureFlag.fileAttachments =>
        'Attach files (PDF, text) for the model to analyze',
      FeatureFlag.llmMemory =>
        'Use AI to extract and remember facts from conversations',
      FeatureFlag.modelWarmUp =>
        'Pre-load model on startup for faster first response (+2-5s startup)',
    };

/// v1 defaults — set to `false` to disable advanced features.
/// In v2, flip these to `true` to re-enable.
const Map<FeatureFlag, bool> _kDefaults = {
  FeatureFlag.webSearch: false,       // v1: off (toggle in chat UI)
  FeatureFlag.fileAttachments: false, // v1: off
  FeatureFlag.llmMemory: false,       // v1: off (regex-only)
  FeatureFlag.modelWarmUp: false,     // v1: off (skip warm-up)
};

const String _prefsPrefix = 'feature_flag_';

/// Check whether a feature flag is enabled.
///
/// Convenience function that reads from the Riverpod provider.
/// Use this throughout the codebase:
/// ```dart
/// if (featureEnabled(ref, FeatureFlag.fileAttachments)) { ... }
/// ```
bool featureEnabled(WidgetRef ref, FeatureFlag flag) {
  return ref.read(featureFlagsProvider).isEnabled(flag);
}

/// In-memory state holding all feature flag values.
class FeatureFlags {
  final Map<FeatureFlag, bool> _values;

  const FeatureFlags._(this._values);

  bool isEnabled(FeatureFlag flag) => _values[flag] ?? _kDefaults[flag] ?? false;

  FeatureFlags copyWith(FeatureFlag flag, bool value) {
    return FeatureFlags._({..._values, flag: value});
  }

  /// All flags with their current values.
  Map<FeatureFlag, bool> get all => Map.unmodifiable(_values);
}

/// Loads feature flag values from SharedPreferences, falling back to defaults.
Future<FeatureFlags> loadFeatureFlags() async {
  final prefs = await prefsCache();
  final values = <FeatureFlag, bool>{};
  for (final flag in FeatureFlag.values) {
    values[flag] = prefs.getBool('$_prefsPrefix${flag.name}') ??
        _kDefaults[flag] ??
        false;
  }
  return FeatureFlags._(values);
}

/// Persists a single feature flag value to SharedPreferences.
Future<void> _saveFeatureFlag(FeatureFlag flag, bool value) async {
  final prefs = await prefsCache();
  await prefs.setBool('$_prefsPrefix${flag.name}', value);
  Log.d('[FeatureFlags] ${flag.name} = $value');
}

/// Riverpod notifier for feature flags.
class FeatureFlagsNotifier extends StateNotifier<FeatureFlags> {
  FeatureFlagsNotifier() : super(const FeatureFlags._({})) {
    _load();
  }

  Future<void> _load() async {
    state = await loadFeatureFlags();
  }

  /// Toggle a feature flag on/off.
  Future<void> toggle(FeatureFlag flag) async {
    final current = state.isEnabled(flag);
    final newValue = !current;
    state = state.copyWith(flag, newValue);
    await _saveFeatureFlag(flag, newValue);
  }

  /// Set a feature flag to a specific value.
  Future<void> set(FeatureFlag flag, bool value) async {
    if (state.isEnabled(flag) == value) return;
    state = state.copyWith(flag, value);
    await _saveFeatureFlag(flag, value);
  }
}

/// Global provider for feature flags.
final featureFlagsProvider =
    StateNotifierProvider<FeatureFlagsNotifier, FeatureFlags>((ref) {
  return FeatureFlagsNotifier();
});
