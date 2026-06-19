import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sutra/features/chat/file_picker_provider.dart';
import 'package:sutra/features/chat/uploaded_file.dart';
import 'package:sutra/runtime/models/model_definition.dart';
import 'package:sutra/runtime/models/model_registry.dart';
import 'package:sutra/runtime/pipeline/selected_model_provider.dart';
import 'package:sutra/runtime/search/web_search_provider.dart';

/// Bottom sheet showing action options: Upload File, Web Search,
/// and a list of previously uploaded files for quick selection.
class AttachSheetContent extends ConsumerWidget {
  const AttachSheetContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allFiles = ref.watch(uploadedFilesProvider);
    final selectedIds = ref.watch(selectedFileIdsProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(Icons.add_circle_outline, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Add', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                if (selectedIds.isNotEmpty)
                  Text(
                    '${selectedIds.length} selected',
                    style: TextStyle(fontSize: 12, color: colorScheme.primary),
                  ),
              ],
            ),
          ),
          // ── Action tiles ──
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.upload_file, size: 20, color: colorScheme.primary),
            ),
            title: const Text('Upload file'),
            subtitle: Text(
              'TXT, JSON, CSV, PDF, DOCX, DOC',
              style: TextStyle(fontSize: 11, color: colorScheme.outline),
            ),
            onTap: () {
              Navigator.pop(context);
              _showFilePicker(context, ref);
            },
          ),
          // ── Web search (only for models with ≥8K context) ──
          Builder(
            builder: (context) {
              final selectedId = ref.watch(selectedModelIdProvider);
              // In auto mode (null selectedId), check the first installed model.
              final model = selectedId != null
                  ? ModelRegistry.all.where((m) => m.id == selectedId).firstOrNull
                  : ModelRegistry.all.firstOrNull;
              final hasSearchCap = model?.supports(ModelCapability.webSearch) ?? false;
              final searchEnabled = ref.watch(webSearchProvider).enabled;

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasSearchCap
                        ? colorScheme.tertiaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.language, size: 20, color: hasSearchCap ? colorScheme.tertiary : colorScheme.outline),
                ),
                title: Row(
                  children: [
                    const Text('Web search'),
                    if (searchEnabled) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.check_circle, size: 14, color: colorScheme.primary),
                    ],
                  ],
                ),
                subtitle: Text(
                  hasSearchCap
                      ? 'Search the web and get an answer with citations'
                      : 'Requires a model with ≥8K context',
                  style: TextStyle(
                    fontSize: 11,
                    color: hasSearchCap ? colorScheme.outline : colorScheme.error.withValues(alpha: 0.7),
                  ),
                ),
                enabled: hasSearchCap,
                onTap: hasSearchCap
                    ? () {
                        Navigator.pop(context);
                        ref.read(webSearchProvider.notifier).toggle();
                      }
                    : null,
              );
            },
          ),
          // ── Existing files list ──
          if (allFiles.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.folder_open, size: 14, color: colorScheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    'Previously uploaded',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.outline),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: allFiles.length,
                itemBuilder: (_, index) {
                  final file = allFiles[index];
                  final isSelected = selectedIds.contains(file.id);
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isSelected ? colorScheme.primary : colorScheme.outline).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        isSelected ? Icons.check_circle : iconForExtension(file.extension),
                        size: 18,
                        color: isSelected ? colorScheme.primary : colorScheme.outline,
                      ),
                    ),
                    title: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: Text(
                      '${file.fileTypeLabel} · ${file.sizeLabel}',
                      style: TextStyle(fontSize: 11, color: colorScheme.outline),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, size: 18, color: colorScheme.error.withValues(alpha: 0.7)),
                      tooltip: 'Delete file',
                      onPressed: () => _confirmDeleteFile(context, ref, file),
                    ),
                    onTap: () {
                      ref.read(selectedFileIdsProvider.notifier).toggle(file.id);
                    },
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _showFilePicker(BuildContext context, WidgetRef ref) async {
    final file = await ref.read(uploadedFilesProvider.notifier).addFile();
    if (file != null && context.mounted) {
      ref.read(selectedFileIdsProvider.notifier).toggle(file.id);
    }
  }

  void _confirmDeleteFile(BuildContext context, WidgetRef ref, UploadedFile file) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.delete_outline, color: colorScheme.error, size: 28),
        title: const Text('Delete file?'),
        content: Text('Remove "${file.name}" from uploads? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: colorScheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(selectedFileIdsProvider.notifier).toggle(file.id);
              ref.read(uploadedFilesProvider.notifier).removeFile(file.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// Returns an icon based on the file extension.
IconData iconForExtension(String ext) {
  return switch (ext.toLowerCase()) {
    '.pdf' => Icons.picture_as_pdf,
    '.docx' || '.doc' => Icons.description,
    '.json' => Icons.data_object,
    '.csv' => Icons.table_chart,
    _ => Icons.insert_drive_file,
  };
}
