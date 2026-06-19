import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sutra/core/storage/chat_repository.dart';

import 'chat_provider.dart';

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  bool _showArchived = false;
  List<ChatSession> _sessions = [];
  bool _loading = true;

  // ── Multi-select state ────────────────────────────────
  bool _selectMode = false;
  final Set<String> _selectedIds = {};

  /// Cached date formatter — avoid re-creating per itemBuilder call.
  static final _dateFmt = DateFormat.yMd().add_jm();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  /// Load sessions from DB.
  Future<void> _loadSessions() async {
    final chatRepo = ref.read(chatRepositoryProvider);
    final sessions = await chatRepo.getSessions(includeArchived: _showArchived);
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    }
  }

  /// Optimistic refresh: update list immediately after mutations.
  void _refreshSessions() {
    final chatRepo = ref.read(chatRepositoryProvider);
    chatRepo.getSessions(includeArchived: _showArchived).then((sessions) {
      if (mounted) setState(() => _sessions = sessions);
    });
  }

  void _enterSelectMode(String id) {
    setState(() {
      _selectMode = true;
      _selectedIds.clear();
      _selectedIds.add(id);
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _selectMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _sessions.length) {
        _selectedIds.clear();
        _selectMode = false;
      } else {
        _selectedIds.addAll(_sessions.map((s) => s.id));
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectMode
          ? _buildSelectAppBar()
          : AppBar(
              title:
                  Text(_showArchived ? 'Archived' : 'Conversations'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () async {
                    final id = await ref
                        .read(chatProvider.notifier)
                        .newSession();
                    if (context.mounted) {
                      Navigator.of(context).pop(id);
                    }
                  },
                ),
              ],
            ),
      body: Listener(
        onPointerDown: (_) =>
            ScaffoldMessenger.of(context).clearSnackBars(),
        child: Column(
          children: [
            if (!_selectMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Active',
                      selected: !_showArchived,
                      onTap: () {
                        setState(() => _showArchived = false);
                        _loadSessions();
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Archived',
                      selected: _showArchived,
                      onTap: () {
                        setState(() => _showArchived = true);
                        _loadSessions();
                      },
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _sessions.isEmpty
                      ? _buildEmptyState()
                      : _buildSessionList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _showArchived
                ? Icons.archive_outlined
                : Icons.forum_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            _showArchived
                ? 'No archived conversations'
                : 'No conversations yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _showArchived
                ? 'Swipe left on a conversation to archive it'
                : 'Tap + to start one',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionList() {
    return ListView.builder(
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        final dateStr =
            _dateFmt.format(session.updatedAt);
        final isSelected = _selectedIds.contains(session.id);

        if (_selectMode) {
          return _buildSelectTile(session, dateStr, isSelected);
        }
        return _buildNormalTile(session, dateStr);
      },
    );
  }

  // ── Select mode AppBar ─────────────────────────────────

  PreferredSizeWidget _buildSelectAppBar() {
    final hasSelection = _selectedIds.isNotEmpty;
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectMode,
      ),
      title: Text('${_selectedIds.length} selected'),
      actions: [
        IconButton(
          icon: Icon(
            hasSelection ? Icons.deselect : Icons.select_all,
          ),
          tooltip: hasSelection ? 'Deselect all' : 'Select all',
          onPressed: _selectAll,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete selected',
          onPressed:
              hasSelection ? () => _confirmBulkDelete() : null,
        ),
      ],
    );
  }

  // ── Normal (non-select) tile ───────────────────────────

  Widget _buildNormalTile(ChatSession session, String dateStr) {
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: Icon(
          Icons.delete,
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete conversation?'),
            content: Text(
                'This will permanently delete "${session.title}".'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final chatRepo = ref.read(chatRepositoryProvider);
        final messages =
            await chatRepo.getMessages(session.id);
        await ref
            .read(chatProvider.notifier)
            .deleteSession(session.id);
        if (!mounted) return;
        // Optimistic: remove from local list immediately.
        setState(() {
          _sessions.removeWhere((s) => s.id == session.id);
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${session.title}" deleted'),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await chatRepo.restoreSession(
                      session, messages);
                  _refreshSessions();
                },
              ),
            ),
          );
      },
      child: ListTile(
        leading: Icon(
          session.archived
              ? Icons.archive
              : Icons.chat_bubble_outline,
        ),
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Text(dateStr),
            if (session.messageCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${session.messageCount} msg${session.messageCount != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.more_vert,
            size: 18,
            color: Theme.of(context).colorScheme.outline,
          ),
          onSelected: (value) =>
              _handleMenuAction(context, session, value),
          itemBuilder: (ctx) => [
            if (session.archived)
              const PopupMenuItem(
                value: 'unarchive',
                child: Text('Unarchive'),
              )
            else
              const PopupMenuItem(
                value: 'archive',
                child: Text('Archive'),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
        ),
        onTap: () {
          if (session.archived) return;
          ref
              .read(chatProvider.notifier)
              .switchSession(session.id);
          Navigator.of(context).pop(session.id);
        },
        onLongPress: () => _enterSelectMode(session.id),
      ),
    );
  }

  // ── Select mode tile ───────────────────────────────────

  Widget _buildSelectTile(
      ChatSession session, String dateStr, bool isSelected) {
    return ListTile(
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outline,
      ),
      title: Text(
        session.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight:
              isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: Text(dateStr),
      selected: isSelected,
      onTap: () => _toggleSelection(session.id),
    );
  }

  // ── Bulk delete confirmation ───────────────────────────

  void _confirmBulkDelete() {
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversations?'),
        content: Text(
            'This will permanently delete $count conversation${count > 1 ? 's' : ''}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _bulkDeleteFromDialog();
            },
            child: Text('Delete',
                style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _bulkDeleteFromDialog() async {
    final chatRepo = ref.read(chatRepositoryProvider);
    final toDelete = _sessions
        .where((s) => _selectedIds.contains(s.id))
        .toList();

    final snapshots = <_DeletedSnapshot>[];
    for (final session in toDelete) {
      final messages =
          await chatRepo.getMessages(session.id);
      await ref
          .read(chatProvider.notifier)
          .deleteSession(session.id);
      snapshots.add(_DeletedSnapshot(
          session: session, messages: messages));
    }

    _exitSelectMode();
    if (!mounted) return;
    // Optimistic: remove deleted sessions from local list.
    final deletedIds = _selectedIds.toSet();
    setState(() {
      _sessions.removeWhere(
          (s) => deletedIds.contains(s.id));
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${snapshots.length} conversation${snapshots.length > 1 ? 's' : ''} deleted'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              for (final snap in snapshots) {
                await chatRepo.restoreSession(
                    snap.session, snap.messages);
              }
              _refreshSessions();
            },
          ),
        ),
      );
    }
  }

  // ── Menu actions ───────────────────────────────────────

  Future<void> _handleMenuAction(
      BuildContext context,
      ChatSession session,
      String action) async {
    final chatRepo = ref.read(chatRepositoryProvider);

    switch (action) {
      case 'archive':
        await chatRepo.archiveSession(session.id);
        _refreshSessions();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${session.title}" archived'),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  await chatRepo
                      .unarchiveSession(session.id);
                  _refreshSessions();
                },
              ),
            ),
          );
        }
        break;
      case 'unarchive':
        await chatRepo.unarchiveSession(session.id);
        _refreshSessions();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('"${session.title}" unarchived'),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        break;
      case 'delete':
        _confirmDelete(context, session);
        break;
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ChatSession session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete conversation?'),
        content: Text(
            'This will permanently delete "${session.title}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final chatRepo = ref.read(chatRepositoryProvider);
      final messages =
          await chatRepo.getMessages(session.id);
      await ref
          .read(chatProvider.notifier)
          .deleteSession(session.id);
      if (!mounted) return;
      // Optimistic: remove from local list immediately.
      setState(() {
        _sessions.removeWhere((s) => s.id == session.id);
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${session.title}" deleted'),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await chatRepo.restoreSession(
                  session, messages);
              _refreshSessions();
            },
          ),
        ),
      );
    }
  }
}

// ── Deleted snapshot for undo ──────────────────────────────

class _DeletedSnapshot {
  final ChatSession session;
  final List<Map<String, dynamic>> messages;
  const _DeletedSnapshot(
      {required this.session, required this.messages});
}

// ── Filter chip widget ────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color:
                selected ? cs.onPrimary : cs.onSurface,
          ),
        ),
      ),
    );
  }
}
