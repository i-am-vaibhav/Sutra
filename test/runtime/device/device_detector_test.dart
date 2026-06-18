import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/device/device_detector.dart';
import 'package:sutra/runtime/device/device_profile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('sutra/device');
  final log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  // ── Platform channel correctness ───────────────────────────────

  group('DeviceDetector platform channel bridge', () {
    test('calls getDeviceProfile on the sutra/device channel', () async {
      // Override handler to return Android-style profile
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        return {
          'ramMB': 6000,
          'cpuCores': 8,
          'hasGpu': false,
          'platform': 'android',
        };
      });

      final profile = await DeviceDetector.getProfile();

      expect(log, hasLength(1));
      expect(log.first.method, 'getDeviceProfile');
      expect(profile.platform, 'android');
    });

    test('parses Android device profile correctly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return {
          'ramMB': 8192,
          'cpuCores': 12,
          'hasGpu': false,
          'platform': 'android',
        };
      });

      final profile = await DeviceDetector.getProfile();

      expect(profile.ramMB, 8192);
      expect(profile.cpuCores, 12);
      expect(profile.hasGpu, false);
      expect(profile.platform, 'android');
    });

    test('parses iOS device profile correctly', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return {
          'ramMB': 6144,
          'cpuCores': 6,
          'hasGpu': true,
          'platform': 'ios',
        };
      });

      final profile = await DeviceDetector.getProfile();

      expect(profile.ramMB, 6144);
      expect(profile.cpuCores, 6);
      expect(profile.hasGpu, true);
      expect(profile.platform, 'ios');
    });

    test('parses low-end Android profile', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return {
          'ramMB': 2048,
          'cpuCores': 4,
          'hasGpu': false,
          'platform': 'android',
        };
      });

      final profile = await DeviceDetector.getProfile();

      expect(profile.ramMB, 2048);
      expect(profile.cpuCores, 4);
      expect(profile.hasGpu, false);
    });

    test('parses high-end iOS profile', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return {
          'ramMB': 16384,
          'cpuCores': 16,
          'hasGpu': true,
          'platform': 'ios',
        };
      });

      final profile = await DeviceDetector.getProfile();

      expect(profile.ramMB, 16384);
      expect(profile.cpuCores, 16);
      expect(profile.hasGpu, true);
      expect(profile.platform, 'ios');
    });

    test('returns PlatformException when channel throws', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        throw PlatformException(
          code: 'NO_NATIVE',
          message: 'Native code not available',
        );
      });

      expect(
        () => DeviceDetector.getProfile(),
        throwsA(isA<PlatformException>()),
      );
    });

    test('returns MissingPluginException when no handler registered', () async {
      // Remove the handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      expect(
        () => DeviceDetector.getProfile(),
        throwsA(isA<MissingPluginException>()),
      );
    });

    test('completes within 5 seconds (bridge responsiveness)', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return {
          'ramMB': 6000,
          'cpuCores': 8,
          'hasGpu': false,
          'platform': 'android',
        };
      });

      final stopwatch = Stopwatch()..start();
      final profile = await DeviceDetector.getProfile();
      stopwatch.stop();

      expect(profile, isA<DeviceProfile>());
      expect(
        stopwatch.elapsedMilliseconds,
        lessThan(5000),
        reason:
            'Platform channel bridge should respond within 5 seconds. '
            'Took ${stopwatch.elapsedMilliseconds}ms.',
      );
    });
  });

  // ── Edge cases ─────────────────────────────────────────────────

  group('DeviceDetector edge cases', () {
    test('handles zero RAM gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return {
          'ramMB': 0,
          'cpuCores': 2,
          'hasGpu': false,
          'platform': 'android',
        };
      });

      final profile = await DeviceDetector.getProfile();
      expect(profile.ramMB, 0);
    });

    test('handles null field values gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return {
          'ramMB': null,
          'cpuCores': null,
          'hasGpu': null,
          'platform': null,
        };
      });

      // The DeviceProfile constructor requires non-null types,
      // so this should throw a type error.
      expect(
        () => DeviceDetector.getProfile(),
        throwsA(anything),
      );
    });

    test('handles extra fields in response without crashing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        return {
          'ramMB': 4096,
          'cpuCores': 8,
          'hasGpu': true,
          'platform': 'ios',
          'extraField': 'ignored',
        };
      });

      final profile = await DeviceDetector.getProfile();
      expect(profile.platform, 'ios');
    });
  });
}
