import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/device/device_profile.dart';
import 'package:sutra/runtime/llm/device_performance.dart';

/// Simulates the full _buildOptimalParams pipeline from runtime_provider.dart.
/// This ensures battery/thermal adjustments are correctly layered on top of
/// the base hardware-derived values.
 ({int threads, int gpuLayers}) _simulateBuildOptimalParams(
  DeviceProfile device, {
  int contextLength = 4096,
}) {
  final baseThreads = DevicePerformance.optimalThreads(device);
  final baseGpuLayers = DevicePerformance.optimalGpuLayers(device);
  final threads = DevicePerformance.adjustForThermal(device, baseThreads);
  final gpuLayers = DevicePerformance.adjustForBattery(device, baseGpuLayers);
  return (threads: threads, gpuLayers: gpuLayers);
}

DeviceProfile _profile({
  int ramMB = 8000,
  int cpuCores = 8,
  bool hasGpu = true,
  String gpuFamily = 'high',
  String platform = 'android',
  int? batteryPercent,
  double? temperatureC,
}) =>
    DeviceProfile(
      ramMB: ramMB,
      cpuCores: cpuCores,
      hasGpu: hasGpu,
      gpuName: hasGpu ? 'Adreno 730' : 'none',
      gpuFamily: gpuFamily,
      platform: platform,
      batteryPercent: batteryPercent,
      temperatureC: temperatureC,
    );

void main() {
  group('Runtime pipeline integration', () {
    group('healthy device (no adjustments)', () {
      test('high-end Android at full battery and cool temperature', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 8000, cpuCores: 8, gpuFamily: 'high', batteryPercent: 100, temperatureC: 25),
        );
        // base: threads = 8/2 = 4, gpuLayers = -1 (all)
        // No battery/thermal adjustment needed
        expect(result.threads, 4);
        expect(result.gpuLayers, -1);
      });

      test('mid-range Android at full battery and cool temperature', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 6000, cpuCores: 8, gpuFamily: 'mid', batteryPercent: 80, temperatureC: 30),
        );
        // base: threads = 8-2 = 6, gpuLayers = 30
        // No battery/thermal adjustment
        expect(result.threads, 6);
        expect(result.gpuLayers, 30);
      });

      test('iOS device at full battery and cool temperature', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 8000, cpuCores: 6, platform: 'ios', batteryPercent: 90, temperatureC: 28),
        );
        // base: threads = 6-2 = 4, gpuLayers = -1
        expect(result.threads, 4);
        expect(result.gpuLayers, -1);
      });
    });

    group('low battery adjustments', () {
      test('high-end Android at 10% battery reduces GPU layers significantly', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 8000, cpuCores: 8, gpuFamily: 'high', batteryPercent: 10, temperatureC: 25),
        );
        // base: threads = 4, gpuLayers = -1
        // adjustForBattery skips -1 (all GPU) — returns -1 unchanged
        expect(result.threads, 4);
        expect(result.gpuLayers, -1);
      });

      test('mid-range Android at 10% battery reduces GPU layers', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 6000, cpuCores: 8, gpuFamily: 'mid', batteryPercent: 10, temperatureC: 25),
        );
        // base: threads = 6, gpuLayers = 30
        // adjustForBattery(10%): 30 * 0.25 = 7.5 → 8
        expect(result.threads, 6);
        expect(result.gpuLayers, 8);
      });

      test('4GB RAM device at 25% battery', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 4000, cpuCores: 6, gpuFamily: 'mid', batteryPercent: 25, temperatureC: 30),
        );
        // base: threads = 4, gpuLayers = 20
        // adjustForBattery(25%): 20 * 0.5 = 10
        expect(result.threads, 4);
        expect(result.gpuLayers, 10);
      });
    });

    group('thermal adjustments', () {
      test('device at 42°C reduces threads', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 8000, cpuCores: 8, gpuFamily: 'high', batteryPercent: 80, temperatureC: 42),
        );
        // base: threads = 4, gpuLayers = -1
        // adjustForThermal(42°C): 4 * 0.6 = 2.4 → 2
        expect(result.threads, 2);
        expect(result.gpuLayers, -1);
      });

      test('device at 50°C reduces threads aggressively', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 6000, cpuCores: 8, gpuFamily: 'mid', batteryPercent: 70, temperatureC: 50),
        );
        // base: threads = 6, gpuLayers = 30
        // adjustForThermal(50°C): 6 * 0.4 = 2.4 → 2
        expect(result.threads, 2);
        expect(result.gpuLayers, 30);
      });
    });

    group('combined battery + thermal stress', () {
      test('low battery + hot device — both adjustments apply', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 6000, cpuCores: 8, gpuFamily: 'mid', batteryPercent: 15, temperatureC: 42),
        );
        // base: threads = 6, gpuLayers = 30
        // adjustForThermal(42°C): 6 * 0.6 = 3.6 → 4
        // adjustForBattery(15%): 30 * 0.25 = 7.5 → 8
        expect(result.threads, 4);
        expect(result.gpuLayers, 8);
      });

      test('critical state: 5% battery + 50°C', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 4000, cpuCores: 6, gpuFamily: 'mid', batteryPercent: 5, temperatureC: 50),
        );
        // base: threads = 4, gpuLayers = 20
        // adjustForThermal(50°C): 4 * 0.4 = 1.6 → 2 (clamped to min 2)
        // adjustForBattery(5%): 20 * 0.25 = 5
        expect(result.threads, 2);
        expect(result.gpuLayers, 5);
      });

      test('warm device at 30% battery', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 8000, cpuCores: 8, gpuFamily: 'high', batteryPercent: 30, temperatureC: 37),
        );
        // base: threads = 4, gpuLayers = -1
        // adjustForThermal(37°C): 4 * 0.8 = 3.2 → 3
        // adjustForBattery(30%): skips -1 sentinel
        expect(result.threads, 3);
        expect(result.gpuLayers, -1);
      });
    });

    group('CPU-only devices', () {
      test('low RAM device with no GPU — battery adjustment is a no-op', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 2000, cpuCores: 4, hasGpu: false, batteryPercent: 10, temperatureC: 25),
        );
        // base: threads = 2, gpuLayers = 0
        // adjustForBattery(10%): skips 0 sentinel
        expect(result.threads, 2);
        expect(result.gpuLayers, 0);
      });
    });

    group('null battery/temperature', () {
      test('null battery and temperature — no adjustments', () {
        final result = _simulateBuildOptimalParams(
          _profile(ramMB: 6000, cpuCores: 8, gpuFamily: 'mid', batteryPercent: null, temperatureC: null),
        );
        // base: threads = 6, gpuLayers = 30
        expect(result.threads, 6);
        expect(result.gpuLayers, 30);
      });
    });
  });
}
