import 'package:flutter/services.dart';
import '../device/device_profile.dart';

class DeviceDetector {
  static const _channel = MethodChannel('sutra/device');

  static Future<DeviceProfile> getProfile() async {
    final raw = await _channel.invokeMethod('getDeviceProfile');

    return DeviceProfile(
      ramMB: raw['ramMB'],
      cpuCores: raw['cpuCores'],
      hasGpu: raw['hasGpu'],
      platform: raw['platform'],
    );
  }
}