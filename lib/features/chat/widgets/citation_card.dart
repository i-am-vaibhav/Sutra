import 'package:flutter/material.dart';
import 'package:sutra/runtime/search/search_agent.dart';
import 'package:url_launcher/url_launcher.dart';

/// A compact card displaying a citation (source link) from the web search agent.
///
/// Designed to be rendered in a horizontal scrollable row below search answers.
class CitationCard extends StatelessWidget {
  final Citation citation;
  final int index;

  const CitationCard({
    super.key,
    required this.citation,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final host = Uri.tryParse(citation.url)?.host ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final uri = Uri.parse(citation.url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 220,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: colorScheme.outline),
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 11, color: colorScheme.outline),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                citation.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A horizontal scrollable row of citation cards.
class CitationBar extends StatelessWidget {
  final List<Citation> citations;

  const CitationBar({super.key, required this.citations});

  @override
  Widget build(BuildContext context) {
    if (citations.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 12, right: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              children: [
                Icon(Icons.link, size: 12, color: colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  '${citations.length} source${citations.length > 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 96,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: citations.length,
              itemBuilder: (context, index) => CitationCard(
                citation: citations[index],
                index: index,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
