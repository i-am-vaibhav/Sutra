import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../runtime/device/device_provider.dart';
import '../../runtime/llm/ffi/llama_native.dart';
import '../../runtime/models/model_definition.dart';
import '../../runtime/models/model_policy.dart';
import '../../runtime/models_provision/model_provisioning_service.dart';
import '../../runtime/models_provision/model_provisioning_state.dart';

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(deviceTierProvider);

    final provisioningService =
    ref.read(modelProvisioningServiceProvider);

    return tierAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),

      error: (error, _) => Center(
        child: Text('Error: $error'),
      ),

      data: (tier) {
        final models = ModelPolicy.required(tier);

        return StreamBuilder<ModelProvisioningState>(
          stream: provisioningService.stream,
          initialData: ModelProvisioningState.empty(),
          builder: (context, snapshot) {
            final state =
                snapshot.data ??
                    ModelProvisioningState.empty();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _SectionCard(
                  title: 'Device',
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tier: ${tier.name.toUpperCase()}',
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Models are selected automatically based on device capability.',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _SectionCard(
                  title: 'Runtime',
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backend: Local Inference',
                      ),

                      const SizedBox(height: 4),

                      const Text(
                        'Engine: llama.cpp',
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Native: ${LlamaNative.version()}',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Local Models',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge,
                ),

                const SizedBox(height: 8),

                ...models.map(
                      (model) => _ModelTile(
                    model: model,
                    state: state,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 12),

            child,
          ],
        ),
      ),
    );
  }
}

class _ModelTile extends StatelessWidget {
  final ModelDefinition model;
  final ModelProvisioningState state;

  const _ModelTile({
    required this.model,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final installed =
    state.installed.contains(model.id);

    final downloading =
    state.downloading.contains(model.id);

    final progress =
        state.progress[model.id] ?? 0.0;

    return Card(
      margin: const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Icon(
                  installed
                      ? Icons.check_circle
                      : downloading
                      ? Icons.download
                      : Icons.memory,
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        model.id,
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Context Length: ${model.contextLength}',
                      ),

                      Text(
                        'Storage: ${model.localPath}',
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Text(
                  installed
                      ? 'Installed'
                      : downloading
                      ? '${(progress * 100).toStringAsFixed(0)}%'
                      : 'Pending',
                ),
              ],
            ),

            if (downloading) ...[
              const SizedBox(height: 12),

              LinearProgressIndicator(
                value: progress,
              ),
            ],
          ],
        ),
      ),
    );
  }
}