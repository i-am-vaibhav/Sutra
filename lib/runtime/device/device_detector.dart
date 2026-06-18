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
}
