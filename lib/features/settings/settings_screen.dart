import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/app/theme/theme_provider.dart';
import 'package:sutra/core/feature_flags.dart';
import 'package:sutra/core/widgets/info_row.dart';
import 'package:sutra/runtime/context/context_settings.dart';
import 'package:sutra/runtime/context/context_settings_provider.dart';
import 'package:sutra/runtime/device/device_provider.dart';
import 'package:sutra/runtime/device/device_profile.dart';
import 'package:sutra/runtime/device/device_tier.dart';
import 'package:sutra/runtime/provisioning/wifi_only_provider.dart';
import 'package:sutra/runtime/pipeline/context_builder.dart';
import 'package:sutra/runtime/settings/keep_screen_on_provider.dart';
import 'package:sutra/runtime/tts/tts_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _promptController;

  @override
  void initState() {
    super.initState();
    final currentPrompt = ref.read(systemPromptProvider);
    _promptController = TextEditingController(text: currentPrompt);
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tierAsync = ref.watch(deviceTierProvider);
    final systemPrompt = ref.watch(systemPromptProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_promptController.text != systemPrompt) {
      _promptController.text = systemPrompt;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Accessibility ──
          Text('Accessibility',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _ReadAloudSection(colorScheme: colorScheme),
          const SizedBox(height: 8),
          _KeepScreenOnToggle(colorScheme: colorScheme),

          const SizedBox(height: 24),

          // ── Appearance ──
          Text('Appearance',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _ThemeToggleSection(colorScheme: colorScheme),

          const SizedBox(height: 24),

          // ── Downloads ──
          Text('Downloads',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Control how models are downloaded.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
          const SizedBox(height: 12),
          _WifiOnlyToggle(colorScheme: colorScheme),

          const SizedBox(height: 24),

          // ── Feature Flags ──
          _FeatureFlagsSection(colorScheme: colorScheme),

          const SizedBox(height: 24),

          // ── System Prompt ──
          Text('System Prompt',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Defines the assistant\'s behavior and personality.',
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline)),
          const SizedBox(height: 12),
          TextField(
            controller: _promptController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Enter a system prompt…',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            onChanged: (value) {
              ref.read(systemPromptProvider.notifier).update(value);
            },
          ),

          const SizedBox(height: 24),

          // ── Context Features ──
          _ContextSettingsSection(theme: theme, colorScheme: colorScheme),

          const SizedBox(height: 24),

          // ── Device Info ──
          Text('Device',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: _DeviceProfileCard(
              profileAsync: ref.watch(deviceProfileProvider),
              tierAsync: tierAsync,
            ),
          ),

          const SizedBox(height: 24),

          // ── About ──
          Text('About',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const InfoRow(label: 'App', value: 'Sutra'),
                  const InfoRow(label: 'Engine', value: 'llama.cpp (via llamadart)'),
                  const SizedBox(height: 12),
                  Text(
                    'A privacy-first AI assistant that runs entirely on your device. '
                    'No data is sent to external servers.',
                    style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Read Aloud Section ──────────────────────────────────

class _ReadAloudSection extends ConsumerWidget {
  final ColorScheme colorScheme;
  const _ReadAloudSection({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = colorScheme;
    final ttsState = ref.watch(ttsProvider);
    final ttsNotifier = ref.read(ttsProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              ttsState.isEnabled ? Icons.volume_up : Icons.volume_off,
              size: 20,
              color: ttsState.isEnabled ? cs.primary : cs.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Read Aloud', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'Automatically read model responses aloud',
                    style: TextStyle(fontSize: 12, color: cs.outline),
                  ),
                ],
              ),
            ),
            Switch(
              value: ttsState.isEnabled,
              onChanged: ttsNotifier.toggleEnabled,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Context Settings Section ─────────────────────────────────

class _ContextSettingsSection extends ConsumerWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;

  const _ContextSettingsSection({required this.theme, required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(contextSettingsProvider);
    final notifier = ref.read(contextSettingsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.psychology, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('Context Features',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Give the model more context about you and your work.',
          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.outline),
        ),
        const SizedBox(height: 12),

        _FeatureToggle(
          title: 'User Profile',
          subtitle: 'Tell the model about yourself (name, profession, interests)',
          value: settings.userProfileEnabled,
          onChanged: notifier.toggleUserProfile,
          warning: settings.userProfileEnabled
              ? 'Adds ~100-300 tokens to every prompt. Minimal impact on small models.'
              : null,
          icon: Icons.person_outline,
          colorScheme: colorScheme,
        ),

        if (settings.userProfileEnabled) ...[
          const SizedBox(height: 8),
          _UserProfileFields(settings: settings, notifier: notifier),
        ],

        const SizedBox(height: 8),

        _FeatureToggle(
          title: 'Conversation Memory',
          subtitle: 'Remember facts from past conversations across sessions',
          value: settings.conversationMemoryEnabled,
          onChanged: notifier.toggleConversationMemory,
          warning: settings.conversationMemoryEnabled
              ? 'Adds ~50-200 tokens per prompt. Improves continuity but uses more context window.'
              : null,
          icon: Icons.history,
          colorScheme: colorScheme,
        ),

        const SizedBox(height: 8),


      ],
    );
  }
}

// ── Feature Toggle ──────────────────────────────────────────

class _FeatureToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String? warning;
  final IconData icon;
  final ColorScheme colorScheme;

  const _FeatureToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.warning,
    required this.icon,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: value ? colorScheme.primary : colorScheme.outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(fontSize: 12, color: colorScheme.outline)),
                    ],
                  ),
                ),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
            if (warning != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(warning!,
                          style: const TextStyle(fontSize: 11, color: Colors.orange)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── User Profile Fields ─────────────────────────────────────

class _UserProfileFields extends ConsumerStatefulWidget {
  final ContextSettings settings;
  final ContextSettingsNotifier notifier;

  const _UserProfileFields({required this.settings, required this.notifier});

  @override
  ConsumerState<_UserProfileFields> createState() => _UserProfileFieldsState();
}

class _UserProfileFieldsState extends ConsumerState<_UserProfileFields> {
  late TextEditingController _nameCtrl;
  late TextEditingController _professionCtrl;
  late TextEditingController _interestsCtrl;
  late TextEditingController _extraInfoCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.settings.userName);
    _professionCtrl = TextEditingController(text: widget.settings.userProfession);
    _interestsCtrl = TextEditingController(text: widget.settings.userInterests);
    _extraInfoCtrl = TextEditingController(text: widget.settings.userExtraInfo);
  }

  @override
  void didUpdateWidget(covariant _UserProfileFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_nameCtrl.text != widget.settings.userName) {
      _nameCtrl.text = widget.settings.userName;
    }
    if (_professionCtrl.text != widget.settings.userProfession) {
      _professionCtrl.text = widget.settings.userProfession;
    }
    if (_interestsCtrl.text != widget.settings.userInterests) {
      _interestsCtrl.text = widget.settings.userInterests;
    }
    if (_extraInfoCtrl.text != widget.settings.userExtraInfo) {
      _extraInfoCtrl.text = widget.settings.userExtraInfo;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _professionCtrl.dispose();
    _interestsCtrl.dispose();
    _extraInfoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_nameCtrl, 'Name', widget.notifier.updateUserName),
            _field(_professionCtrl, 'Profession', widget.notifier.updateUserProfession),
            _field(_interestsCtrl, 'Interests', widget.notifier.updateUserInterests),
            _field(_extraInfoCtrl, 'Additional Info', widget.notifier.updateUserExtraInfo),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'e.g. ${_hintFor(label)}',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }

  String _hintFor(String label) {
    return switch (label) {
      'Name' => 'Vaibhav',
      'Profession' => 'Software Engineer',
      'Interests' => 'AI, photography, hiking',
      _ => 'anything else you want the model to know',
    };
  }
}

// ── Feature Flags Section ──────────────────────────────────

class _FeatureFlagsSection extends ConsumerWidget {
  final ColorScheme colorScheme;
  const _FeatureFlagsSection({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flags = ref.watch(featureFlagsProvider);
    final notifier = ref.read(featureFlagsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.toggle_on, color: colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text('Feature Flags',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Toggle advanced features on or off.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.outline),
        ),
        const SizedBox(height: 12),
        for (final flag in FeatureFlag.values)
          _FeatureFlagTile(
            flag: flag,
            enabled: flags.isEnabled(flag),
            onChanged: () => notifier.toggle(flag),
            colorScheme: colorScheme,
          ),
      ],
    );
  }
}

class _FeatureFlagTile extends StatelessWidget {
  final FeatureFlag flag;
  final bool enabled;
  final VoidCallback onChanged;
  final ColorScheme colorScheme;

  const _FeatureFlagTile({
    required this.flag,
    required this.enabled,
    required this.onChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.check_circle : Icons.circle_outlined,
              size: 20,
              color: enabled ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(featureFlagName(flag),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(featureFlagDescription(flag),
                      style: TextStyle(fontSize: 12, color: colorScheme.outline)),
                ],
              ),
            ),
            Switch(value: enabled, onChanged: (_) => onChanged()),
          ],
        ),
      ),
    );
  }
}

// ── Keep Screen On Toggle

// ── Keep Screen On Toggle ────────────────────────────────

class _KeepScreenOnToggle extends ConsumerWidget {
  final ColorScheme colorScheme;
  const _KeepScreenOnToggle({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(keepScreenOnProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.screen_lock_rotation : Icons.screen_lock_portrait,
              size: 20,
              color: enabled ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Keep Screen On', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    enabled
                        ? 'Screen stays on for 5 min of inactivity'
                        : 'Screen follows system sleep timeout',
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            Switch(
              value: enabled,
              onChanged: (value) {
                ref.read(keepScreenOnProvider.notifier).toggle(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Theme Toggle Section ────────────────────────────────────

class _ThemeToggleSection extends ConsumerWidget {
  final ColorScheme colorScheme;
  const _ThemeToggleSection({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  currentMode == ThemeMode.dark
                      ? Icons.dark_mode
                      : currentMode == ThemeMode.light
                          ? Icons.light_mode
                          : Icons.brightness_auto,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        'Choose your preferred appearance',
                        style: TextStyle(fontSize: 12, color: colorScheme.outline),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode, size: 18),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode, size: 18),
                  label: Text('Dark'),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto, size: 18),
                  label: Text('System'),
                ),
              ],
              selected: {currentMode},
              onSelectionChanged: (selected) {
                ref.read(themeModeProvider.notifier).setThemeMode(selected.first);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── WiFi-Only Toggle ────────────────────────────────────

class _WifiOnlyToggle extends ConsumerWidget {
  final ColorScheme colorScheme;
  const _WifiOnlyToggle({required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wifiOnly = ref.watch(wifiOnlyProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              wifiOnly ? Icons.wifi : Icons.wifi_off,
              size: 20,
              color: wifiOnly ? colorScheme.primary : colorScheme.outline,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Wi-Fi Only', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    wifiOnly
                        ? 'Models download only on Wi-Fi'
                        : 'Models can download over mobile data',
                    style: TextStyle(fontSize: 12, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            Switch(
              value: wifiOnly,
              onChanged: (value) {
                ref.read(wifiOnlyProvider.notifier).toggle(value);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Device Profile Card ─────────────────────────────────────

class _DeviceProfileCard extends StatelessWidget {
  final AsyncValue<DeviceProfile> profileAsync;
  final AsyncValue<DeviceTier> tierAsync;

  const _DeviceProfileCard({required this.profileAsync, required this.tierAsync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return profileAsync.when(
      data: (profile) {
        final ramGB = (profile.ramMB / 1024).toStringAsFixed(1);
        final platformLabel = profile.platform == 'ios' ? 'iOS' : 'Android';
        final gpuLabel = profile.gpuName;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              tierAsync.when(
                data: (tier) {
                  final tierColor = switch (tier) {
                    DeviceTier.high => Colors.green,
                    DeviceTier.mid => Colors.orange,
                    DeviceTier.low => Colors.red,
                  };
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed, size: 16, color: tierColor),
                        const SizedBox(width: 6),
                        Text('${tier.name.toUpperCase()} TIER',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: tierColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              InfoRow(label: 'RAM', value: '$ramGB GB (${profile.ramMB} MB)'),
              InfoRow(label: 'CPU Cores', value: profile.cpuCores.toString()),
              InfoRow(label: 'GPU', value: gpuLabel, icon: Icons.memory),
              InfoRow(label: 'GPU Tier', value: profile.gpuFamily.toUpperCase()),
              InfoRow(label: 'Platform', value: platformLabel),
            ],
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: colorScheme.error, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Could not detect device: $e',
                    style: TextStyle(color: colorScheme.error))),
          ],
        ),
      ),
    );
  }
}
