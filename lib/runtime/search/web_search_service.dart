import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/search/search_result.dart';

/// Searches the web using DuckDuckGo's HTML interface.
///
/// Uses `html.duckduckgo.com/html/` which returns plain HTML without
/// JavaScript — ideal for scraping from a mobile app.
/// No API key required.
class WebSearchService {
  final Dio _dio;

  static const _baseUrl = 'https://html.duckduckgo.com/html/';
  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  WebSearchService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 15),
              headers: {'User-Agent': _userAgent},
            ));

  /// Search DuckDuckGo and return up to [maxResults] results.
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    try {
      Log.d('[WebSearch] Searching: "$query"');

      // DuckDuckGo HTML endpoint accepts POST with a 'q' field.
      final response = await _dio.post(
        _baseUrl,
        data: 'q=${Uri.encodeComponent(query)}',
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {'User-Agent': _userAgent},
        ),
      );

      if (response.statusCode != 200) {
        Log.w('[WebSearch] HTTP ${response.statusCode}');
        return _fallbackSearch(query, maxResults: maxResults);
      }

      return _parseResults(response.data.toString(), maxResults: maxResults);
    } catch (e) {
      Log.w('[WebSearchService] DuckDuckGo search failed: $e, trying fallback');
      return _fallbackSearch(query, maxResults: maxResults);
    }
  }

  /// Fallback: try GET request if POST fails.
  Future<List<SearchResult>> _fallbackSearch(String query,
      {int maxResults = 5}) async {
    try {
      final response = await _dio.get(
        '$_baseUrl?q=${Uri.encodeComponent(query)}',
        options: Options(headers: {'User-Agent': _userAgent}),
      );

      if (response.statusCode == 200) {
        return _parseResults(response.data.toString(), maxResults: maxResults);
      }
    } catch (e) {
      Log.w('[WebSearch] Fallback search also failed: $e');
    }
    return [];
  }

  /// Parse DuckDuckGo HTML results page into [SearchResult] objects.
  List<SearchResult> _parseResults(String html, {int maxResults = 5}) {
    final document = html_parser.parse(html);
    final results = <SearchResult>[];

    // DuckDuckGo HTML results are in <div class="result"> containers.
    final resultElements = document.querySelectorAll('.result');

    for (final el in resultElements) {
      if (results.length >= maxResults) break;

      // Extract title and URL from the <a> tag inside .result__body.
      final linkEl = el.querySelector('a.result__a');
      if (linkEl == null) continue;

      final title = linkEl.text.trim();
      var url = linkEl.attributes['href'] ?? '';

      // DuckDuckGo wraps URLs in a redirect; extract the actual URL.
      if (url.contains('uddg=')) {
        try {
          final uri = Uri.parse(url);
          url = Uri.decodeComponent(uri.queryParameters['uddg'] ?? url);
        } catch (_) {
          // Use the raw URL if parsing fails.
        }
      }

      if (title.isEmpty || url.isEmpty) continue;

      // Extract snippet.
      final snippetEl = el.querySelector('.result__snippet');
      final snippet = snippetEl?.text.trim() ?? '';

      results.add(SearchResult(
        title: title,
        url: url,
        snippet: snippet,
      ));
    }

    Log.d('[WebSearch] Parsed ${results.length} results');
    return results;
  }

  /// Dispose the Dio client.
  void dispose() {
    _dio.close();
  }
}
