import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/runtime/device/device_provider.dart';
import 'package:sutra/runtime/device/device_tier.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(deviceTierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: tierAsync.when(
          data: (tier) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Device Capability Tier',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                Text(
                  _tierLabel(tier),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, _) => Text('Error: $e'),
        ),
      ),
    );
  }

  String _tierLabel(DeviceTier tier) {
    switch (tier) {
      case DeviceTier.low:
        return "LOW";
      case DeviceTier.mid:
        return "MID";
      case DeviceTier.high:
        return "HIGH";
    }
  }
}