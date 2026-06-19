import 'package:flutter/services.dart';
import 'package:sutra/runtime/device/device_profile.dart';

class DeviceDetector {
  static const _channel = MethodChannel('sutra/device');

  static Future<DeviceProfile> getProfile() async {
    final raw = await _channel.invokeMethod('getDeviceProfile');

    return DeviceProfile(
      ramMB: raw['ramMB'],
      cpuCores: raw['cpuCores'],
      hasGpu: raw['hasGpu'],
      gpuName: raw['gpuName'] as String? ?? 'none',
      gpuFamily: raw['gpuFamily'] as String? ?? 'none',
      platform: raw['platform'],
    );
  }

  /// Returns free disk space in bytes using native platform APIs.
  /// On Android: StatFs on the data directory.
  /// On iOS: URLResourceKey.volumeAvailableCapacityForImportantUsageKey.
  static Future<int> getFreeDiskSpace() async {
    try {
      final result = await _channel.invokeMethod('getFreeDiskSpace');
      return result as int;
    } catch (e) {
      return 0;
    }
  }
}
