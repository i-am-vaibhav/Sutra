import 'package:flutter/widgets.dart';
import 'package:sutra/core/logging/log.dart';

/// Listens to app lifecycle changes and re-fetches the device profile
/// when the app resumes from background. This triggers [runtimeProvider]
/// to re-evaluate GPU layers and thread count with fresh battery/thermal data.
///
/// Attach via [WidgetsBindingObserver] in the app bootstrap or a
/// root widget. The provider dependency chain handles the rest:
/// resume → profile refresh → runtimeProvider rebuilds → new params.
class BatteryThermalMonitor extends WidgetsBindingObserver {
  final VoidCallback onRefresh;

  BatteryThermalMonitor({required this.onRefresh});

  /// Start listening to lifecycle changes.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    Log.d('[BatteryThermalMonitor] Started listening to lifecycle');
  }

  /// Stop listening and clean up.
  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    Log.d('[BatteryThermalMonitor] Stopped');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Log.d('[BatteryThermalMonitor] App resumed — refreshing profile');
      onRefresh();
    }
  }

  void dispose() => stop();
}
