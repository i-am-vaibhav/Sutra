import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/device/device_detector.dart';
import 'device_scoring_engine.dart';
import 'device_tier.dart';

final deviceTierProvider = FutureProvider<DeviceTier>((ref) async {
  final profile = await DeviceDetector.getProfile();

  return DeviceScoringEngine.classify(profile);
});