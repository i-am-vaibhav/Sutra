import 'device_profile.dart';

class DeviceDetector {
  static DeviceProfile detect() {
    // MVP heuristic (we improve later via platform channels)
    return DeviceProfile(
      ramGB: 16, // Pixel 9 baseline assumption for now
      cores: 8,
      isMobile: true,
    );
  }
}