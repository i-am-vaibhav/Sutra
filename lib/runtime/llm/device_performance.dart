import 'package:sutra/runtime/device/device_profile.dart';
import 'package:sutra/core/logging/log.dart';

/// Derives optimal LLM inference parameters from the actual device
/// hardware profile (CPU cores, RAM, GPU) instead of platform heuristics.
///
/// Uses real data from the DeviceChannelPlugin (native MethodChannel)
/// for accurate thread tuning and GPU layer decisions.
class DevicePerformance {
  const DevicePerformance._();

  /// Optimal thread count for LLM inference on this device.
  ///
  /// Estimates big/performance cores from total core count and GPU tier:
  /// - "high" GPU family → more performance cores (e.g. Snapdragon 8 Elite)
  /// - Default → conservative total - 2 for mobile big.LITTLE
  /// - Desktop → total - 1 (leave one for UI/system)
  static int optimalThreads(DeviceProfile profile) {
    final total = profile.cpuCores;

    if (profile.platform == 'ios') {
      // Apple A-series: 2 efficiency cores (A11-A13) or 4 (M1+)
      // Conservative: total - 2 covers most iPhone SoCs.
      return (total - 2).clamp(2, 6);
    } else if (profile.platform == 'android') {
      // big.LITTLE varies by chip:
      //   Snapdragon 8 Gen 3: 1 prime + 5 perf + 2 eff → 6 big
      //   Snapdragon 8 Elite: 2 prime + 6 eff → 2 big
      //   Dimensity 9000:     1 prime + 3 perf + 4 eff → 4 big
      //
      // "high" gpuFamily suggests a flagship SoC — but they can
      // have fewer big cores (e.g. 8 Elite has only 2 prime).
      // Use total / 2 for a safe estimate across all flagships.
      if (profile.gpuFamily == 'high') {
        return (total ~/ 2).clamp(2, 8);
      }
      // Default: total - 2 (skip 2 little cores)
      return (total - 2).clamp(2, 6);
    }

    // Desktop: use all cores minus one (leave one for UI/system).
    return (total - 1).clamp(2, 8);
  }

  /// Optimal GPU layer count based on available RAM and GPU capability.
  ///
  /// - `gpuLayers = -1` means offload ALL layers to GPU (best speed).
  /// - Reduce layers when RAM is tight to avoid OOM kills.
  ///
  /// | RAM       | GPU Layers | Rationale                              |
  /// |-----------|------------|----------------------------------------|
  /// | ≥ 8 GB    | -1 (all)   | Plenty of RAM — safe to offload all    |
  /// | ≥ 6 GB    | 30 layers  | Mid-range: aggressive but not all      |
  /// | ≥ 4 GB    | 20 layers  | Conservative: keep headroom for OS     |
  /// | ≥ 3 GB    | 10 layers  | Minimal offload                        |
  /// | < 3 GB    | 0 (CPU)    | No GPU — avoid OOM                     |
  static int optimalGpuLayers(DeviceProfile profile) {
    if (!profile.hasGpu) return 0;

    final ramMB = profile.ramMB;

    if (ramMB >= 8000) {
      // 8+ GB RAM — safe to offload ALL layers to GPU.
      return -1;
    } else if (ramMB >= 6000) {
      // 6-8 GB RAM — aggressive but not all layers.
      // Mid-range Android with 6GB often has other apps consuming memory.
      return 30;
    } else if (ramMB >= 4000) {
      // 4-6 GB RAM — conservative offload, keep headroom.
      return 20;
    } else if (ramMB >= 3000) {
      // 3-4 GB RAM — minimal offload.
      return 10;
    }

    // < 3 GB RAM — CPU only to avoid OOM.
    return 0;
  }

  /// Battery-aware GPU layer adjustment.
  ///
  /// Reduces GPU layers when battery is low to:
  /// - Reduce power consumption and heat generation
  /// - Prevent thermal throttling which degrades performance
  /// - Extend battery life during inference
  ///
  /// | Battery Level | GPU Layer Multiplier | Rationale                    |
  /// |---------------|----------------------|------------------------------|
  /// | ≥ 50%         | 1.0 (no change)      | Plenty of battery remaining  |
  /// | 30-50%        | 0.75 (25% reduction) | Start conserving             |
  /// | 20-30%        | 0.5 (50% reduction)  | Aggressive conservation      |
  /// | < 20%         | 0.25 (75% reduction) | Critical — minimize draw     |
  ///
  /// Returns the adjusted GPU layer count, ensuring at least 0 (CPU only)
  /// and respecting the -1 (all layers) sentinel value.
  static int adjustForBattery(DeviceProfile profile, int baseLayers) {
    // Don't adjust if already CPU-only or using all layers on high-end device
    if (baseLayers == 0 || baseLayers == -1) return baseLayers;

    final batteryPercent = profile.batteryPercent;
    if (batteryPercent == null) return baseLayers; // Can't determine battery

    double multiplier;
    if (batteryPercent >= 50) {
      multiplier = 1.0;
    } else if (batteryPercent >= 30) {
      multiplier = 0.75;
    } else if (batteryPercent >= 20) {
      multiplier = 0.5;
    } else {
      multiplier = 0.25;
    }

    if (multiplier == 1.0) return baseLayers;

    final adjusted = (baseLayers * multiplier).round().clamp(0, baseLayers);
    Log.d('[DevicePerformance] Battery $batteryPercent%: GPU layers $baseLayers → $adjusted (×$multiplier)');
    return adjusted;
  }

  /// Thermal-aware thread adjustment.
  ///
  /// Reduces thread count when device is hot to:
  /// - Prevent thermal throttling
  /// - Reduce heat generation
  /// - Maintain sustained performance over time
  ///
  /// | Temperature    | Thread Multiplier | Rationale                    |
  /// |----------------|-------------------|------------------------------|
  /// | < 35°C         | 1.0 (no change)   | Normal operating range       |
  /// | 35-40°C        | 0.8 (20% fewer)   | Warm — start reducing        |
  /// | 40-45°C        | 0.6 (40% fewer)   | Hot — aggressive reduction   |
  /// | > 45°C         | 0.4 (60% fewer)   | Critical — minimize heat     |
  static int adjustForThermal(DeviceProfile profile, int baseThreads) {
    final temperature = profile.temperatureC;
    if (temperature == null) return baseThreads;

    double multiplier;
    if (temperature < 35) {
      multiplier = 1.0;
    } else if (temperature < 40) {
      multiplier = 0.8;
    } else if (temperature < 45) {
      multiplier = 0.6;
    } else {
      multiplier = 0.4;
    }

    if (multiplier == 1.0) return baseThreads;

    final adjusted = (baseThreads * multiplier).round().clamp(2, baseThreads);
    Log.d('[DevicePerformance] Temperature ${temperature}°C: threads $baseThreads → $adjusted (×$multiplier)');
    return adjusted;
  }
}
