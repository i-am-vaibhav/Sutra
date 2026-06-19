import 'package:flutter/material.dart';
import 'package:sutra/runtime/search/search_agent.dart';
import 'package:sutra/runtime/search/search_result.dart';

/// An expandable card displayed in the chat message list while a web search
/// is in progress or after it completes.
///
/// Shows:
/// - An animated status row (icon + label + progress) — always visible
/// - A collapsible "Sources" section with links to found web pages
class SearchStatusCard extends StatefulWidget {
  final SearchAgentStatus status;
  final String statusLabel;
  final List<SearchResult> searchResults;
  final List<Citation> citations;

  const SearchStatusCard({
    super.key,
    required this.status,
    required this.statusLabel,
    this.searchResults = const [],
    this.citations = const [],
  });

  @override
  State<SearchStatusCard> createState() => _SearchStatusCardState();
}

class _SearchStatusCardState extends State<SearchStatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _iconController;
  bool _sourcesExpanded = false;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.status != SearchAgentStatus.complete &&
        widget.status != SearchAgentStatus.error &&
        widget.status != SearchAgentStatus.idle) {
      _iconController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant SearchStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status != oldWidget.status) {
      if (widget.status != SearchAgentStatus.complete &&
          widget.status != SearchAgentStatus.error &&
          widget.status != SearchAgentStatus.idle) {
        if (!_iconController.isAnimating) _iconController.repeat();
      } else {
        _iconController.stop();
      }
    }
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  bool get _isBusy =>
      widget.status != SearchAgentStatus.idle &&
      widget.status != SearchAgentStatus.complete &&
      widget.status != SearchAgentStatus.error;

  bool get _hasSources => widget.searchResults.isNotEmpty || widget.citations.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final icon = _iconForStatus(widget.status);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status row ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Animated icon
                RotationTransition(
                  turns: _iconController,
                  child: Icon(icon, size: 16, color: colorScheme.primary),
                ),
                const SizedBox(width: 10),
                // Status label
                Expanded(
                  child: Text(
                    widget.statusLabel.isNotEmpty ? widget.statusLabel : _labelForStatus(widget.status),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Source count badge
                if (_hasSources && !_isBusy)
                  _SourceBadge(count: widget.searchResults.isNotEmpty ? widget.searchResults.length : widget.citations.length, colorScheme: colorScheme),
              ],
            ),
          ),
          // ── Collapsible sources section ──
          if (_hasSources && !_isBusy) ...[
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => setState(() => _sourcesExpanded = !_sourcesExpanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Row(
                    children: [
                      Icon(
                        _sourcesExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.searchResults.isNotEmpty ? widget.searchResults.length : widget.citations.length} sources found',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Expanded sources list
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildSourcesList(colorScheme),
              crossFadeState: _sourcesExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ],
          // ── Error state ──
          if (widget.status == SearchAgentStatus.error)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 14, color: colorScheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.statusLabel.isNotEmpty ? widget.statusLabel : 'Search failed',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSourcesList(ColorScheme colorScheme) {
    // Merge search results and citations, preferring search results for detail.
    final sources = widget.searchResults.isNotEmpty
        ? widget.searchResults
        : widget.citations.map((c) => SearchResult(title: c.title, url: c.url, snippet: '')).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: sources.take(5).map((source) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link, size: 14, color: colorScheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        source.title.isNotEmpty ? source.title : source.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (source.snippet.isNotEmpty)
                        Text(
                          source.snippet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  IconData _iconForStatus(SearchAgentStatus status) {
    return switch (status) {
      SearchAgentStatus.analyzing => Icons.hub,
      SearchAgentStatus.searching => Icons.search,
      SearchAgentStatus.fetching => Icons.download,
      SearchAgentStatus.extracting => Icons.content_cut,
      SearchAgentStatus.reranking => Icons.sort,
      SearchAgentStatus.generating => Icons.auto_awesome,
      SearchAgentStatus.complete => Icons.check_circle_outline,
      SearchAgentStatus.error => Icons.error_outline,
      SearchAgentStatus.idle => Icons.hourglass_top_rounded,
    };
  }

  String _labelForStatus(SearchAgentStatus status) {
    return switch (status) {
      SearchAgentStatus.idle => 'Idle',
      SearchAgentStatus.analyzing => 'Analyzing query...',
      SearchAgentStatus.searching => 'Searching the web...',
      SearchAgentStatus.fetching => 'Reading pages...',
      SearchAgentStatus.extracting => 'Extracting content...',
      SearchAgentStatus.reranking => 'Ranking sources...',
      SearchAgentStatus.generating => 'Generating answer...',
      SearchAgentStatus.complete => 'Done',
      SearchAgentStatus.error => 'Error',
    };
  }
}

/// Small pill badge showing the number of sources found.
class _SourceBadge extends StatelessWidget {
  final int count;
  final ColorScheme colorScheme;

  const _SourceBadge({required this.count, required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
