import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/chat/chat_provider.dart';
import 'package:sutra/features/chat/widgets/model_picker.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';

/// AppBar bottom widget showing the currently selected model and its status.
class ModelStatusBar extends ConsumerWidget implements PreferredSizeWidget {
  const ModelStatusBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(36);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedModelIdProvider);
    final runtimeAsync = ref.watch(runtimeProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isAuto = selectedId == null;
    String modelName;
    if (isAuto) {
      modelName = 'Auto';
    } else {
      final allModels = allKnownModels(ref);
      final model = allModels.firstWhere((m) => m.id == selectedId, orElse: () => allModels.first);
      modelName = model.name;
    }

    final isModelLoading = ref.watch(chatProvider.select((s) => s.isModelLoading));

    _StatusKind status;
    if (isModelLoading) {
      status = _StatusKind.loading;
    } else if (runtimeAsync is AsyncLoading) {
      status = _StatusKind.loading;
    } else if (runtimeAsync is AsyncError) {
      status = _StatusKind.error;
    } else if (selectedId == null) {
      status = _StatusKind.none;
    } else if (runtimeAsync.value?.isReady == true) {
      status = _StatusKind.ready;
    } else {
      status = _StatusKind.none;
    }

    final Color bgColor;
    final Color fgColor;
    final IconData icon;

    if (isAuto) {
      bgColor = colorScheme.tertiaryContainer;
      fgColor = colorScheme.onTertiaryContainer;
      icon = Icons.auto_awesome;
    } else {
      switch (status) {
        case _StatusKind.ready:
          bgColor = colorScheme.primaryContainer;
          fgColor = colorScheme.onPrimaryContainer;
          icon = Icons.check_circle_outline;
        case _StatusKind.loading:
          bgColor = colorScheme.secondaryContainer;
          fgColor = colorScheme.onSecondaryContainer;
          icon = Icons.hourglass_top_rounded;
        case _StatusKind.error:
          bgColor = colorScheme.errorContainer;
          fgColor = colorScheme.onErrorContainer;
          icon = Icons.error_outline;
        case _StatusKind.none:
          bgColor = colorScheme.surfaceContainerHighest;
          fgColor = colorScheme.onSurfaceVariant;
          icon = Icons.memory_outlined;
      }
    }

    return GestureDetector(
      onTap: () => showModelPicker(context, ref, selectedId),
      child: Container(
        height: 36,
        color: bgColor,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (status == _StatusKind.loading)
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fgColor))
            else
              Icon(icon, size: 16, color: fgColor),
            const SizedBox(width: 8),
            Expanded(child: Text(modelName, style: theme.textTheme.labelMedium?.copyWith(color: fgColor, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            if (status == _StatusKind.ready) ...[
              Icon(Icons.shield, size: 12, color: fgColor.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text('On-device', style: theme.textTheme.labelSmall?.copyWith(color: fgColor.withValues(alpha: 0.7), fontSize: 10)),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, size: 16, color: fgColor),
          ],
        ),
      ),
    );
  }
}

enum _StatusKind { ready, loading, error, none }
