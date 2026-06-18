import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/device/device_profile.dart';
import 'package:sutra/runtime/device/device_scoring_engine.dart';
import 'package:sutra/runtime/device/device_tier.dart';

void main() {
  group('DeviceScoringEngine.classify', () {
    // ── Low-tier devices ──────────────────────────────────────

    test('classifies low-end Android as low tier', () {
      final profile = DeviceProfile(
        ramMB: 2048,
        cpuCores: 4,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 1 + CPU 1 + GPU 0 + platform 0 = 2 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('classifies minimal Android device as low tier', () {
      final profile = DeviceProfile(
        ramMB: 1024,
        cpuCores: 2,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 1 + CPU 1 + GPU 0 + platform 0 = 2 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    // ── Mid-tier devices ──────────────────────────────────────

    test('classifies mid-range Android as mid tier', () {
      final profile = DeviceProfile(
        ramMB: 6000,
        cpuCores: 8,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 2 + CPU 3 + GPU 0 + platform 0 = 5 → mid
      expect(DeviceScoringEngine.classify(profile), DeviceTier.mid);
    });

    test('classifies mid-range iOS as mid tier', () {
      final profile = DeviceProfile(
        ramMB: 4000,
        cpuCores: 6,
        hasGpu: true,
        gpuName: 'Apple GPU',
        gpuFamily: 'mid',
        platform: 'ios',
      );
      // Score: RAM 2 + CPU 2 + GPU 1 + platform 1 = 6 → mid
      expect(DeviceScoringEngine.classify(profile), DeviceTier.mid);
    });

    test('classifies 4GB RAM / 6-core Android without GPU as low tier', () {
      final profile = DeviceProfile(
        ramMB: 4000,
        cpuCores: 6,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 2 + CPU 2 + GPU 0 + platform 0 = 4 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('classifies 4GB RAM / 6-core Android with mid GPU as mid tier', () {
      final profile = DeviceProfile(
        ramMB: 4000,
        cpuCores: 6,
        hasGpu: true,
        gpuName: 'OpenGL ES 3.0',
        gpuFamily: 'mid',
        platform: 'android',
      );
      // Score: RAM 2 + CPU 2 + GPU 1 + platform 0 = 5 → mid
      expect(DeviceScoringEngine.classify(profile), DeviceTier.mid);
    });

    // ── High-tier devices ─────────────────────────────────────

    test('classifies high-end iPhone as high tier', () {
      final profile = DeviceProfile(
        ramMB: 8192,
        cpuCores: 6,
        hasGpu: true,
        gpuName: 'Apple A15 GPU',
        gpuFamily: 'high',
        platform: 'ios',
      );
      // Score: RAM 3 + CPU 2 + GPU 2 + platform 1 = 8 → high
      expect(DeviceScoringEngine.classify(profile), DeviceTier.high);
    });

    test('classifies 16GB Android without GPU as mid tier', () {
      final profile = DeviceProfile(
        ramMB: 16384,
        cpuCores: 12,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 3 + CPU 3 + GPU 0 + platform 0 = 6 → mid
      expect(DeviceScoringEngine.classify(profile), DeviceTier.mid);
    });

    test('classifies top-tier Android with Vulkan GPU as high tier', () {
      final profile = DeviceProfile(
        ramMB: 16384,
        cpuCores: 12,
        hasGpu: true,
        gpuName: 'Vulkan GPU',
        gpuFamily: 'high',
        platform: 'android',
      );
      // Score: RAM 3 + CPU 3 + GPU 2 + platform 0 = 8 → high
      expect(DeviceScoringEngine.classify(profile), DeviceTier.high);
    });

    test('classifies iPad Pro as high tier', () {
      final profile = DeviceProfile(
        ramMB: 16384,
        cpuCores: 8,
        hasGpu: true,
        gpuName: 'Apple M1 GPU',
        gpuFamily: 'high',
        platform: 'ios',
      );
      // Score: RAM 3 + CPU 3 + GPU 2 + platform 1 = 9 → high
      expect(DeviceScoringEngine.classify(profile), DeviceTier.high);
    });

    // ── GPU family tier tests ─────────────────────────────────

    test('high GPU family gives 2 points', () {
      final profile = DeviceProfile(
        ramMB: 2000,
        cpuCores: 4,
        hasGpu: true,
        gpuName: 'Vulkan GPU',
        gpuFamily: 'high',
        platform: 'android',
      );
      // Score: RAM 1 + CPU 1 + GPU 2 + platform 0 = 4 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('mid GPU family gives 1 point', () {
      final profile = DeviceProfile(
        ramMB: 2000,
        cpuCores: 4,
        hasGpu: true,
        gpuName: 'OpenGL ES 3.0',
        gpuFamily: 'mid',
        platform: 'android',
      );
      // Score: RAM 1 + CPU 1 + GPU 1 + platform 0 = 3 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('low GPU family gives 0 points', () {
      final profile = DeviceProfile(
        ramMB: 2000,
        cpuCores: 4,
        hasGpu: true,
        gpuName: 'OpenGL ES 2.0',
        gpuFamily: 'low',
        platform: 'android',
      );
      // Score: RAM 1 + CPU 1 + GPU 0 + platform 0 = 2 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('GPU family tier affects classification at boundary', () {
      // Two devices with same specs but different GPU tiers
      final lowGpu = DeviceProfile(
        ramMB: 4000,
        cpuCores: 6,
        hasGpu: true,
        gpuName: 'OpenGL ES 2.0',
        gpuFamily: 'low',
        platform: 'android',
      );
      final midGpu = DeviceProfile(
        ramMB: 4000,
        cpuCores: 6,
        hasGpu: true,
        gpuName: 'OpenGL ES 3.0',
        gpuFamily: 'mid',
        platform: 'android',
      );
      final highGpu = DeviceProfile(
        ramMB: 4000,
        cpuCores: 6,
        hasGpu: true,
        gpuName: 'Vulkan GPU',
        gpuFamily: 'high',
        platform: 'android',
      );
      // lowGpu:  RAM 2 + CPU 2 + GPU 0 = 4 → low
      // midGpu:  RAM 2 + CPU 2 + GPU 1 = 5 → mid
      // highGpu: RAM 2 + CPU 2 + GPU 2 = 6 → mid
      expect(DeviceScoringEngine.classify(lowGpu), DeviceTier.low);
      expect(DeviceScoringEngine.classify(midGpu), DeviceTier.mid);
      expect(DeviceScoringEngine.classify(highGpu), DeviceTier.mid);
    });

    // ── Boundary value tests ──────────────────────────────────

    test('RAM at 4000 boundary gets mid score (2)', () {
      final profile = DeviceProfile(
        ramMB: 4000,
        cpuCores: 4,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 2 + CPU 1 + GPU 0 + platform 0 = 3 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('RAM at 7999 gets mid score (2)', () {
      final profile = DeviceProfile(
        ramMB: 7999,
        cpuCores: 4,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 2 + CPU 1 + GPU 0 + platform 0 = 3 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('RAM at 8000 boundary gets high score (3)', () {
      final profile = DeviceProfile(
        ramMB: 8000,
        cpuCores: 4,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 3 + CPU 1 + GPU 0 + platform 0 = 4 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('CPU at 6 boundary gets mid score (2)', () {
      final profile = DeviceProfile(
        ramMB: 2000,
        cpuCores: 6,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 1 + CPU 2 + GPU 0 + platform 0 = 3 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('CPU at 8 boundary gets high score (3)', () {
      final profile = DeviceProfile(
        ramMB: 2000,
        cpuCores: 8,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 1 + CPU 3 + GPU 0 + platform 0 = 4 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    // ── Edge cases ────────────────────────────────────────────

    test('zero RAM and zero CPU still classifies', () {
      final profile = DeviceProfile(
        ramMB: 0,
        cpuCores: 0,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      // Score: RAM 1 + CPU 1 + GPU 0 + platform 0 = 2 → low
      expect(DeviceScoringEngine.classify(profile), DeviceTier.low);
    });

    test('iOS platform bonus only affects result at boundary', () {
      final android = DeviceProfile(
        ramMB: 4000,
        cpuCores: 6,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'android',
      );
      final ios = DeviceProfile(
        ramMB: 4000,
        cpuCores: 6,
        hasGpu: false,
        gpuName: 'none',
        gpuFamily: 'none',
        platform: 'ios',
      );
      // Android: RAM 2 + CPU 2 + GPU 0 + platform 0 = 4 → low
      // iOS:     RAM 2 + CPU 2 + GPU 0 + platform 1 = 5 → mid
      expect(DeviceScoringEngine.classify(android), DeviceTier.low);
      expect(DeviceScoringEngine.classify(ios), DeviceTier.mid);
    });
  });
}
