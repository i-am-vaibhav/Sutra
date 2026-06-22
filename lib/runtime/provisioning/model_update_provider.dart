import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/provisioning/model_manager_provider.dart';
import 'package:sutra/runtime/provisioning/model_update_service.dart';
import 'package:sutra/runtime/models/model_catalog_service_provider.dart';

/// State exposed to the UI for the model update service.
class ModelUpdateState {
  /// Whether a check is currently in progress.
  final bool isChecking;

  /// Result of the most recent check (null if no check has run yet).
  final ModelUpdateResult? lastResult;

  /// When the next check is scheduled (estimated).
  final DateTime? nextCheckAt;

  const ModelUpdateState({
    this.isChecking = false,
    this.lastResult,
    this.nextCheckAt,
  });

  ModelUpdateState copyWith({
    bool? isChecking,
    ModelUpdateResult? lastResult,
    DateTime? nextCheckAt,
  }) {
    return ModelUpdateState(
      isChecking: isChecking ?? this.isChecking,
      lastResult: lastResult ?? this.lastResult,
      nextCheckAt: nextCheckAt ?? this.nextCheckAt,
    );
  }
}

/// Notifier for the model update service state.
class ModelUpdateNotifier extends Notifier<ModelUpdateState> {
  ModelUpdateService? _service;
  Timer? _periodicTimer;
  bool _initialized = false;

  @override
  ModelUpdateState build() {
    ref.onDispose(_dispose);
    return const ModelUpdateState();
  }

  void _dispose() {
    _periodicTimer?.cancel();
  }

  /// Initialize the service and schedule periodic checks.
  ///
  /// Call this once from bootstrap after ModelManager is ready.
  Future<void> init() async {
    if (_initialized) return;

    try {
      final catalogService = ref.read(modelCatalogServiceProvider);
      final manager = ref.read(modelManagerProvider);
      _service = ModelUpdateService(
        catalogService: catalogService,
        manager: manager,
      );

      // Run an immediate check if needed, then schedule periodic checks.
      await _runCheckIfNeeded();

      // Schedule a periodic check every 24 hours.
      _periodicTimer?.cancel();
      _periodicTimer = Timer.periodic(
        const Duration(hours: 24),
        (_) => _runCheckIfNeeded(),
      );

      _initialized = true;
    } catch (e) {
      Log.w('[ModelUpdateNotifier] Init failed (will retry): $e');
      _initialized = false; // Allow retry.
      // Don't rethrow — background service failure is non-fatal.
    }
  }

  /// Force an immediate update check regardless of the timer.
  Future<ModelUpdateResult?> forceCheck() async {
    if (_service == null) return null;
    return _runCheck();
  }

  /// Run a check only if enough time has elapsed since the last one.
  Future<void> _runCheckIfNeeded() async {
    if (_service == null) return;
    if (!(await _service!.shouldCheck)) return;
    await _runCheck();
  }

  /// Execute the check and update state.
  Future<ModelUpdateResult?> _runCheck() async {
    if (_service == null) return null;

    state = state.copyWith(isChecking: true);
    try {
      final result = await _service!.checkForUpdates();
      state = state.copyWith(
        isChecking: false,
        lastResult: result,
        nextCheckAt: DateTime.now().add(const Duration(hours: 24)),
      );
      return result;
    } catch (e) {
      Log.w('[ModelUpdateNotifier] Check failed: $e');
      state = state.copyWith(isChecking: false);
      return null;
    }
  }
}

/// Provider for the model update service notifier.
final modelUpdateProvider =
    NotifierProvider<ModelUpdateNotifier, ModelUpdateState>(
  ModelUpdateNotifier.new,
);
