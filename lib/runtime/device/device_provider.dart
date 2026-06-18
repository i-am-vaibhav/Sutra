import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/device/device_detector.dart';
import 'package:sutra/runtime/device/device_profile.dart';
import 'package:sutra/runtime/device/device_scoring_engine.dart';
import 'package:sutra/runtime/device/device_tier.dart';

/// Fetches the device profile once and caches it.
final deviceProfileProvider = FutureProvider<DeviceProfile>((ref) async {
  return DeviceDetector.getProfile();
});

/// Classifies the cached profile into a [DeviceTier].
final deviceTierProvider = FutureProvider<DeviceTier>((ref) async {
  final profile = await ref.watch(deviceProfileProvider.future);
  return DeviceScoringEngine.classify(profile);
});