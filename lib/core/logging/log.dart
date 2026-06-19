import 'package:flutter/foundation.dart';

/// Lightweight structured logger that wraps [debugPrint] in release-safe mode.
///
/// Usage:
/// ```dart
/// Log.d('[ChatNotifier] Starting generation');
/// Log.w('[ModelManager] Low storage: $freeBytes bytes free');
/// Log.e('[Runtime] Failed to load model', error: e);
/// ```
///
/// In release builds, `debugPrint` is compiled away by the tree-shaker,
/// so these calls have zero cost.
class Log {
  Log._();

  static void d(String message) {
    debugPrint(message);
  }

  static void w(String message) {
    debugPrint('[WARN] $message');
  }

  static void e(String message, {Object? error, StackTrace? stackTrace}) {
    final buf = StringBuffer('[ERROR] $message');
    if (error != null) buf.write(' — $error');
    debugPrint('$buf');
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }
}
