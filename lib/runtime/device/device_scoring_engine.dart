import 'device_profile.dart';
import 'device_tier.dart';

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

    // GPU bonus (light weight signal)
    if (p.hasGpu) {
      score += 1;
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