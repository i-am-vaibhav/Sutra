import 'package:sutra/runtime/device/device_profile.dart';
import 'package:sutra/runtime/device/device_tier.dart';

class DeviceScoringEngine {

  static DeviceTier classify(DeviceProfile p) {
    int score = 0;

    // RAM scoring
    if (p.ramMB >= 8000) {
      score += 3;
    } else if (p.ramMB >= 4000) {
      score += 2;
    } else {
      score += 1;
    }

    // CPU scoring
    if (p.cpuCores >= 8) {
      score += 3;
    } else if (p.cpuCores >= 6) {
      score += 2;
    } else {
      score += 1;
    }

    // GPU scoring — tiered by capability
    switch (p.gpuFamily) {
      case 'high':
        score += 2;
      case 'mid':
        score += 1;
      default:
        break;
    }

    // Platform bias (optional tuning)
    if (p.platform == "ios") {
      score += 1; // iOS devices usually optimized
    }

    // FINAL TIER DECISION
    if (score >= 7) return DeviceTier.high;
    if (score >= 5) return DeviceTier.mid;
    return DeviceTier.low;
  }
}