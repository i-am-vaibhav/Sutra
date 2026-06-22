import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/device/device_profile.dart';
import 'package:sutra/runtime/llm/device_performance.dart';

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
  // ── adjustForBattery ────────────────────────────────────

  group('DevicePerformance.adjustForBattery', () {
    test('returns unchanged when baseLayers is 0 (CPU-only)', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 10),
        0,
      );
      expect(result, 0);
    });

    test('returns unchanged when baseLayers is -1 (all GPU)', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 10),
        -1,
      );
      expect(result, -1);
    });

    test('returns unchanged when batteryPercent is null', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: null),
        30,
      );
      expect(result, 30);
    });

    test('no reduction at ≥ 50% battery', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 50),
        30,
      );
      expect(result, 30);
    });

    test('no reduction at 100% battery', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 100),
        30,
      );
      expect(result, 30);
    });

    test('25% reduction at 30-50% battery', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 40),
        30,
      );
      // 30 * 0.75 = 22.5 → rounds to 23
      expect(result, 23);
    });

    test('25% reduction at exact 30% battery', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 30),
        20,
      );
      // 20 * 0.75 = 15
      expect(result, 15);
    });

    test('50% reduction at 20-30% battery', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 25),
        30,
      );
      // 30 * 0.5 = 15
      expect(result, 15);
    });

    test('50% reduction at exact 20% battery', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 20),
        20,
      );
      // 20 * 0.5 = 10
      expect(result, 10);
    });

    test('75% reduction at < 20% battery', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 10),
        30,
      );
      // 30 * 0.25 = 7.5 → rounds to 8
      expect(result, 8);
    });

    test('75% reduction at 0% battery', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 0),
        40,
      );
      // 40 * 0.25 = 10
      expect(result, 10);
    });

    test('result is clamped to minimum 0', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 5),
        3,
      );
      // 3 * 0.25 = 0.75 → rounds to 1
      expect(result, 1);
      expect(result, greaterThanOrEqualTo(0));
    });

    test('result is clamped to maximum baseLayers', () {
      final result = DevicePerformance.adjustForBattery(
        _profile(batteryPercent: 60),
        30,
      );
      expect(result, 30);
    });
  });

  // ── adjustForThermal ────────────────────────────────────

  group('DevicePerformance.adjustForThermal', () {
    test('returns unchanged when temperature is null', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: null),
        6,
      );
      expect(result, 6);
    });

    test('no reduction below 35°C', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 30),
        6,
      );
      expect(result, 6);
    });

    test('no reduction at exactly 34.9°C', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 34.9),
        6,
      );
      expect(result, 6);
    });

    test('20% reduction at 35-40°C', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 37),
        6,
      );
      // 6 * 0.8 = 4.8 → rounds to 5
      expect(result, 5);
    });

    test('20% reduction at exact 35°C', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 35),
        10,
      );
      // 10 * 0.8 = 8
      expect(result, 8);
    });

    test('40% reduction at 40-45°C', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 42),
        6,
      );
      // 6 * 0.6 = 3.6 → rounds to 4
      expect(result, 4);
    });

    test('40% reduction at exact 40°C', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 40),
        10,
      );
      // 10 * 0.6 = 6
      expect(result, 6);
    });

    test('60% reduction above 45°C', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 50),
        6,
      );
      // 6 * 0.4 = 2.4 → rounds to 2
      expect(result, 2);
    });

    test('60% reduction at exact 45°C', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 45),
        10,
      );
      // 10 * 0.4 = 4
      expect(result, 4);
    });

    test('result is clamped to minimum 2 threads', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 50),
        3,
      );
      // 3 * 0.4 = 1.2 → rounded to 1, but clamped to min 2
      expect(result, 2);
    });

    test('result never exceeds baseThreads', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 37),
        4,
      );
      // 4 * 0.8 = 3.2 → rounds to 3
      expect(result, lessThanOrEqualTo(4));
    });

    test('handles extreme temperature', () {
      final result = DevicePerformance.adjustForThermal(
        _profile(temperatureC: 60),
        8,
      );
      // 8 * 0.4 = 3.2 → rounds to 3
      expect(result, 3);
    });
  });
}
