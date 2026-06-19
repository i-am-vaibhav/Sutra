import 'package:dio/dio.dart';
import 'package:sutra/core/logging/log.dart';

/// Fetches web pages and returns their HTML content.
///
/// Handles redirects, timeouts, and user-agent spoofing to get
/// readable content from most websites.
class PageFetcher {
  final Dio _dio;

  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  PageFetcher({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 20),
              headers: {
                'User-Agent': _userAgent,
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                'Accept-Language': 'en-US,en;q=0.5',
              },
              // Follow redirects automatically.
              followRedirects: true,
              maxRedirects: 5,
            ));

  /// Fetch a page and return its HTML content.
  ///
  /// Returns null if the request fails or the response is not HTML.
  Future<String?> fetch(String url) async {
    try {
      // Basic URL validation.
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (!uri.scheme.startsWith('http'))) {
        Log.w('[PageFetcher] Invalid URL: $url');
        return null;
      }

      Log.d('[PageFetcher] Fetching: $url');
      final response = await _dio.get(url);

      if (response.statusCode != 200) {
        Log.w('[PageFetcher] HTTP ${response.statusCode} for $url');
        return null;
      }

      final contentType = response.headers.value('content-type') ?? '';
      // Only process HTML responses.
      if (!contentType.contains('text/html') &&
          !contentType.contains('application/xhtml')) {
        Log.d('[PageFetcher] Non-HTML content type: $contentType');
        // Still try — some servers return wrong content-type.
      }

      final html = response.data.toString();
      Log.d('[PageFetcher] Fetched ${html.length} chars from $url');
      return html;
    } on DioException catch (e) {
      Log.w('[PageFetcher] Dio error for $url: ${e.message}');
      return null;
    } catch (e) {
      Log.w('[PageFetcher] Error fetching $url: $e');
      return null;
    }
  }

  /// Fetch multiple pages in parallel, returning at most [maxPages] results.
  /// Pages that fail are silently omitted.
  /// Fetch multiple pages in parallel, returning at most [maxPages] results.
  /// Pages that fail are silently omitted.
  ///
  /// Returns a list of (url, html) records.
  Future<List<({String url, String html})>> fetchMultiple(
    List<String> urls, {
    int maxPages = 3,
  }) async {
    final limited = urls.take(maxPages).toList();
    Log.d('[PageFetcher] fetchMultiple: ${limited.length} URLs in parallel');
    final futures = limited.map((url) async {
      final html = await fetch(url);
      if (html == null) return null;
      return (url: url, html: html);
    });

    final results = await Future.wait(futures);
    final fetched = results.whereType<({String url, String html})>().toList();
    Log.d('[PageFetcher] fetchMultiple: ${fetched.length}/${limited.length} succeeded');
    return fetched;
  }

  void dispose() {
    _dio.close();
  }
}
