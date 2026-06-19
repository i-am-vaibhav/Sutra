import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/chat/file_picker_provider.dart';
import 'package:sutra/features/chat/widgets/attach_sheet.dart';
import 'package:sutra/runtime/search/web_search_provider.dart';

/// Combines the web search indicator chip and attached-file chips into a
/// single animated container that smoothly reveals / hides as items change.
///
/// When both are empty the widget collapses to zero height with a fade.
/// When one or both appear, the container grows and fades in as a unit.
class AttachmentBar extends ConsumerWidget {
  final ColorScheme colorScheme;

  const AttachmentBar({super.key, required this.colorScheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIds = ref.watch(selectedFileIdsProvider);
    final searchEnabled = ref.watch(webSearchProvider.select((s) => s.enabled));

    final hasFiles = selectedIds.isNotEmpty;
    final showSearch = searchEnabled;
    final visible = hasFiles || showSearch;

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: visible
            ? Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Web search chip ──
                    if (showSearch) _WebSearchChip(colorScheme: colorScheme),
                    // ── Attached files chips ──
                    if (hasFiles) ...[
                      if (showSearch) const SizedBox(height: 4),
                      _FileChips(colorScheme: colorScheme, selectedIds: selectedIds),
                    ],
                  ],
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// ── Web search chip (inline, simplified — no outer AnimatedSize) ──────

class _WebSearchChip extends ConsumerStatefulWidget {
  final ColorScheme colorScheme;
  const _WebSearchChip({required this.colorScheme});

  @override
  ConsumerState<_WebSearchChip> createState() => _WebSearchChipState();
}

class _WebSearchChipState extends ConsumerState<_WebSearchChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceScale;
  bool _prevEnabled = false;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(webSearchProvider.select((s) => s.enabled));
    if (enabled && !_prevEnabled) {
      _bounceCtrl.forward(from: 0);
    }
    _prevEnabled = enabled;

    return ScaleTransition(
      scale: _bounceScale,
      child: GestureDetector(
        onTap: () => ref.read(webSearchProvider.notifier).toggle(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language, size: 14, color: widget.colorScheme.tertiary),
              const SizedBox(width: 6),
              Text(
                'Web search',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.colorScheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.close, size: 14, color: widget.colorScheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Attached file chips (inline, simplified) ──────────────────────────

class _FileChips extends ConsumerWidget {
  final ColorScheme colorScheme;
  final Set<String> selectedIds;

  const _FileChips({required this.colorScheme, required this.selectedIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFiles = ref.watch(uploadedFilesProvider);
    final selected = allFiles.where((f) => selectedIds.contains(f.id)).toList();
    if (selected.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: selected.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, index) {
          final file = selected[index];
          return Chip(
            avatar: Icon(
              iconForExtension(file.extension),
              size: 14,
              color: colorScheme.primary,
            ),
            label: Text(
              file.name,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            deleteIcon: Icon(Icons.close, size: 14, color: colorScheme.outline),
            onDeleted: () {
              ref.read(selectedFileIdsProvider.notifier).toggle(file.id);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.only(left: 2),
            backgroundColor:
                colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          );
        },
      ),
    );
  }
}
