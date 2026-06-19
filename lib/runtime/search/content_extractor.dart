import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import 'package:sutra/core/logging/log.dart';

/// Extracted content from a web page after readability-style processing.
class ExtractedContent {
  final String title;
  final String mainContent;
  final List<String> headings;
  final String url;

  const ExtractedContent({
    required this.title,
    required this.mainContent,
    required this.headings,
    required this.url,
  });

  /// Truncated content suitable for LLM context.
  String toContextString({int maxChars = 3000}) {
    final buffer = StringBuffer();
    buffer.writeln('Source: $url');
    if (title.isNotEmpty) buffer.writeln('Title: $title');
    if (headings.isNotEmpty) {
      buffer.writeln('Sections: ${headings.take(5).join(" | ")}');
    }
    buffer.writeln();
    if (mainContent.length > maxChars) {
      buffer.writeln('${mainContent.substring(0, maxChars)}...');
    } else {
      buffer.writeln(mainContent);
    }
    return buffer.toString();
  }
}

/// Extracts readable content from HTML pages using readability-style heuristics.
///
/// Strips ads, navigation, sidebars, cookie banners, scripts, and styles.
/// Identifies the main content container by looking for `<article>`, `<main>`,
/// or the element with the highest text density.
class ContentExtractor {
  /// Tags and selectors that are always noise.
  static const _noiseSelectors = [
    'script',
    'style',
    'noscript',
    'iframe',
    'svg',
    'nav',
    'footer',
    'header',
    'aside',
    '.ad',
    '.ads',
    '.ad-unit',
    '.advertisement',
    '.sidebar',
    '.cookie-banner',
    '.cookie-consent',
    '.popup',
    '.modal',
    '.overlay',
    '.comment',
    '.comments',
    '#comments',
    '.social-share',
    '.share-buttons',
    '.related-posts',
    '.recommended',
    '[role="navigation"]',
    '[role="banner"]',
    '[role="complementary"]',
    '.menu',
    '.navigation',
    '.breadcrumb',
  ];

  /// Extract readable content from raw HTML.
  ExtractedContent extract(String html, String url) {
    final document = html_parser.parse(html);

    // Extract title.
    final title = _extractTitle(document);

    // Remove all noise elements.
    _removeNoise(document);

    // Find the main content container.
    final contentEl = _findMainContent(document);

    // Extract headings from main content.
    final headings = contentEl != null
        ? contentEl
            .querySelectorAll('h1, h2, h3')
            .map((h) => h.text.trim())
            .where((t) => t.isNotEmpty)
            .toList()
        : <String>[];

    // Extract text from main content.
    final content = contentEl != null
        ? _extractText(contentEl)
        : _extractText(document.body ?? document.documentElement);

    Log.d('[ContentExtractor] Extracted ${content.length} chars from $url');

    return ExtractedContent(
      title: title,
      mainContent: content,
      headings: headings,
      url: url,
    );
  }

  /// Extract the page title.
  String _extractTitle(Document document) {
    // Try <title> tag first.
    final titleEl = document.querySelector('title');
    if (titleEl != null) {
      final t = titleEl.text.trim();
      if (t.isNotEmpty) return t;
    }

    // Try <h1> tag.
    final h1 = document.querySelector('h1');
    if (h1 != null) {
      final t = h1.text.trim();
      if (t.isNotEmpty) return t;
    }

    // Try og:title meta tag.
    final ogTitle =
        document.querySelector('meta[property="og:title"]');
    if (ogTitle != null) {
      return ogTitle.attributes['content'] ?? '';
    }

    return '';
  }

  /// Remove noise elements from the document.
  void _removeNoise(Document document) {
    for (final selector in _noiseSelectors) {
      try {
        document.querySelectorAll(selector).forEach((el) => el.remove());
      } catch (_) {
        // Invalid selector — skip silently.
      }
    }
  }

  /// Find the main content container using heuristics.
  Element? _findMainContent(Document document) {
    // Strategy 1: Look for <article> or <main> tag.
    final article = document.querySelector('article');
    if (article != null && article.text.trim().length > 200) {
      return article;
    }

    final main = document.querySelector('main');
    if (main != null && main.text.trim().length > 200) {
      return main;
    }

    // Strategy 2: Look for common content IDs.
    const contentIds = ['content', 'article', 'post', 'entry', 'main-content'];
    for (final id in contentIds) {
      final el = document.querySelector('#$id');
      if (el != null && el.text.trim().length > 200) {
        return el;
      }
    }

    // Strategy 3: Find the element with highest text density.
    return _findHighestDensityElement(document);
  }

  /// Find the element with the highest text-to-link ratio.
  Element? _findHighestDensityElement(Document document) {
    Element? best;
    int bestScore = 0;

    // Check body's direct children and common containers.
    final candidates = <Element>[
      ...document.body?.children ?? [],
    ];

    // Also check divs with class names that suggest content.
    for (final cls in ['article', 'content', 'post', 'entry', 'text']) {
      candidates.addAll(document.querySelectorAll('div.$cls'));
    }

    for (final el in candidates) {
      final text = el.text.trim();
      final textLen = text.length;

      if (textLen < 200) continue;

      // Count link characters (nav/link noise).
      final linkChars =
          el.querySelectorAll('a').fold<int>(0, (sum, a) => sum + a.text.length);

      // Score = text chars - link chars (higher = more content, less nav).
      final score = textLen - linkChars;
      if (score > bestScore) {
        bestScore = score;
        best = el;
      }
    }

    return best;
  }

  /// Extract clean text from an element, preserving paragraph structure.
  String _extractText(Element? element) {
    if (element == null) return '';

    final buffer = StringBuffer();
    _extractTextRecursive(element, buffer);

    // Clean up: collapse multiple newlines, trim.
    return buffer
        .toString()
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Recursively extract text, preserving paragraph breaks.
  void _extractTextRecursive(Element element, StringBuffer buffer) {
    for (final child in element.nodes) {
      if (child is Element) {
        final tag = child.localName;
        if (tag == 'p' || tag == 'div' || tag == 'br') {
          buffer.writeln();
        }
        if (tag == 'h1' || tag == 'h2' || tag == 'h3' || tag == 'h4') {
          buffer.writeln();
          buffer.writeln('## ');
        }
        if (tag == 'li') {
          buffer.writeln('- ');
        }
        _extractTextRecursive(child, buffer);
        if (tag == 'p' || tag == 'div') {
          buffer.writeln();
        }
      } else {
        final text = child.text?.trim() ?? '';
        if (text.isNotEmpty) {
          buffer.write(text);
          buffer.write(' ');
        }
      }
    }
  }

  /// Chunk content into overlapping segments for reranking.
  List<String> chunkContent(String text, {int chunkSize = 500, int overlap = 100}) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];

    for (var i = 0; i < words.length; i += (chunkSize - overlap)) {
      final end = (i + chunkSize).clamp(0, words.length);
      final chunk = words.sublist(i, end).join(' ');
      if (chunk.trim().isNotEmpty) {
        chunks.add(chunk.trim());
      }
    }

    return chunks;
  }

  /// Simple keyword-based reranking: score each chunk by keyword overlap
  /// with the search query. Returns chunks sorted by relevance.
  List<String> rerankChunks(List<String> chunks, String query) {
    final keywords = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toSet();

    if (keywords.isEmpty) return chunks;

    final scored = chunks.map((chunk) {
      final lower = chunk.toLowerCase();
      var score = 0;
      for (final kw in keywords) {
        // Count occurrences of keyword.
        var idx = 0;
        while ((idx = lower.indexOf(kw, idx)) != -1) {
          score++;
          idx += kw.length;
        }
      }
      return MapEntry(chunk, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }
}
