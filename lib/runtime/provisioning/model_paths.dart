import 'dart:io';

import 'package:sutra/core/logging/log.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sutra/runtime/device/device_detector.dart';

class ModelPaths {
  static Future<Directory> modelsDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(root.path, 'models'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> fileFor(String relativePath) async {
    final dir = await modelsDirectory();
    return File(p.join(dir.path, relativePath));
  }

  /// Get free disk space in bytes using native platform APIs.
  /// On Android: StatFs on the data directory.
  /// On iOS: URLResourceKey.volumeAvailableCapacityForImportantUsageKey.
  static Future<int> freeDiskSpace() async {
    try {
      return await DeviceDetector.getFreeDiskSpace();
    } catch (e) {
      Log.w('[ModelPaths] Disk space check failed: $e');
      return 0;
    }
  }

  /// Total size of all files in the models directory.
  static Future<int> totalModelsSize() async {
    int total = 0;
    final dir = await modelsDirectory();
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File && !entity.path.endsWith('.tmp')) {
        total += await entity.length();
      }
    }
    return total;
  }

  /// Delete all files in the models directory (used for cleanup).
  static Future<void> cleanupTempFiles() async {
    final dir = await modelsDirectory();
    await for (final entity in dir.list(recursive: false)) {
      if (entity is File && entity.path.endsWith('.tmp')) {
        await entity.delete(recursive: true);
      }
    }
  }
}