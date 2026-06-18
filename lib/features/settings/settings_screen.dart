import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/core/widgets/info_row.dart';
import 'package:sutra/runtime/context/context_settings.dart';
import 'package:sutra/runtime/context/context_settings_provider.dart';
import 'package:sutra/runtime/device/device_provider.dart';
import 'package:sutra/runtime/device/device_profile.dart';
import 'package:sutra/runtime/device/device_tier.dart';
import 'package:sutra/runtime/orchestration/context_builder.dart';

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

        // ── User Profile Toggle ──
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

        // ── User Profile Fields (expanded when enabled) ──
        if (settings.userProfileEnabled) ...[
          const SizedBox(height: 8),
          _UserProfileFields(settings: settings, notifier: notifier),
        ],

        const SizedBox(height: 8),

        // ── Conversation Memory Toggle ──
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

        // ── Document Index Toggle ──
        _FeatureToggle(
          title: 'Document Context',
          subtitle: 'Reference documents and notes when answering questions',
          value: settings.documentIndexEnabled,
          onChanged: notifier.toggleDocumentIndex,
          warning: settings.documentIndexEnabled
              ? 'Adds full document text to prompts. Use short documents to avoid context overflow.'
              : null,
          icon: Icons.description_outlined,
          colorScheme: colorScheme,
        ),

        // ── Document List (expanded when enabled) ──
        if (settings.documentIndexEnabled) ...[
          const SizedBox(height: 8),
          _DocumentListSection(settings: settings, notifier: notifier),
        ],
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

class _UserProfileFields extends ConsumerWidget {
  final ContextSettings settings;
  final ContextSettingsNotifier notifier;

  const _UserProfileFields({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field('Name', settings.userName, notifier.updateUserName),
            _field('Profession', settings.userProfession, notifier.updateUserProfession),
            _field('Interests', settings.userInterests, notifier.updateUserInterests),
            _field('Additional Info', settings.userExtraInfo, notifier.updateUserExtraInfo),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: value),
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
      'Name' => 'Alice',
      'Profession' => 'Software Engineer',
      'Interests' => 'AI, photography, hiking',
      _ => 'anything else you want the model to know',
    };
  }
}

// ── Document List Section ───────────────────────────────────

class _DocumentListSection extends ConsumerWidget {
  final ContextSettings settings;
  final ContextSettingsNotifier notifier;

  const _DocumentListSection({required this.settings, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (settings.documents.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No documents added yet.\nTap + to add a note or paste text.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ),
            ),
          )
        else
          ...settings.documents.map((doc) => Card(
                child: ListTile(
                  leading: const Icon(Icons.description, size: 20),
                  title: Text(doc.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    doc.content.length > 80
                        ? '${doc.content.substring(0, 80)}…'
                        : doc.content,
                    style: TextStyle(fontSize: 11, color: colorScheme.outline),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => notifier.removeDocument(doc.id),
                  ),
                ),
              )),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _showAddDocumentDialog(context, ref),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Document'),
          ),
        ),
      ],
    );
  }

  void _showAddDocumentDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. API Documentation',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Paste text or write notes here…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.isNotEmpty && contentCtrl.text.isNotEmpty) {
                ref.read(contextSettingsProvider.notifier).addDocument(DocumentEntry(
                      id: DateTime.now().toIso8601String(),
                      title: titleCtrl.text,
                      content: contentCtrl.text,
                      createdAt: DateTime.now(),
                    ));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
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
