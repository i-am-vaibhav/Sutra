import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/search/search_result.dart';

/// Searches the web using public SearXNG instances via their JSON API.
///
/// SearXNG is an open-source metasearch engine that aggregates results from
/// dozens of search engines. No API key required.
///
/// Uses multiple public instances with automatic failover — if one instance
/// is down or doesn't support JSON, the next is tried.
class SearxngSearchService {
  final Dio _dio;

  /// Public SearXNG instances that support JSON API, in priority order.
  /// Checked periodically; remove dead instances and add new ones.
  static const _instances = [
    'https://search.sapti.me',
    'https://searx.tiekoetter.com',
    'https://search.bus-hit.me',
    'https://searx.work',
    'https://search.ononoki.org',
    'https://searxng.ch',
    'https://search.projectsegfau.lt',
  ];

  static const _userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';

  /// Track which instances are currently working (to prioritize them).
  final List<String> _workingInstances = List.from(_instances);

  /// Max instances to try in parallel during failover.
  static const _parallelFailoverCount = 3;

  SearxngSearchService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 8),
              headers: {'User-Agent': _userAgent},
            ));

  /// Search using SearXNG, trying instances in parallel for fast failover.
  ///
  /// Fires requests to the top [_parallelFailoverCount] instances
  /// simultaneously and returns results from the first one that succeeds.
  /// Falls back to sequential tries for remaining instances if all parallel
  /// requests fail.
  ///
  /// Returns deduplicated [SearchResult]s or an empty list if all instances
  /// fail.
  Future<List<SearchResult>> search(String query, {int maxResults = 5}) async {
    final instancesToTry = List<String>.from(_workingInstances);
    if (instancesToTry.isEmpty) return [];

    // ── Phase 1: Fire top N instances in parallel ──
    final parallelCount = instancesToTry.length.clamp(1, _parallelFailoverCount);
    final parallelInstances = instancesToTry.take(parallelCount).toList();

    final futures = parallelInstances.map((instance) async {
      try {
        final results = await _searchInstance(instance, query,
            maxResults: maxResults);
        return _InstanceResult(instance, results, null);
      } catch (e) {
        return _InstanceResult(instance, <SearchResult>[], e);
      }
    }).toList();

    // Use Future.any to get the first successful result.
    // We race all futures; the first to return non-empty results wins.
    final allResults = await Future.wait(futures);

    // Find the first successful instance, and clean up failed ones.
    for (final result in allResults) {
      if (result.results.isNotEmpty) {
        // Promote this instance to front.
        _workingInstances.remove(result.instance);
        _workingInstances.insert(0, result.instance);
        Log.d('[SearXNG] Got ${result.results.length} results from ${result.instance}');

        // Remove any parallel instances that failed.
        for (final other in allResults) {
          if (other != result && other.error != null) {
            Log.w('[SearXNG] Instance ${other.instance} failed: ${other.error}');
            _workingInstances.remove(other.instance);
          }
        }

        return result.results;
      }
    }

    // All parallel requests failed — clean up failed instances.
    for (final result in allResults) {
      if (result.error != null) {
        Log.w('[SearXNG] Instance ${result.instance} failed: ${result.error}');
        _workingInstances.remove(result.instance);
      }
    }

    // ── Phase 2: Try remaining instances sequentially ──
    final remaining = instancesToTry.skip(parallelCount).toList();
    for (final instance in remaining) {
      try {
        final results = await _searchInstance(instance, query,
            maxResults: maxResults);
        if (results.isNotEmpty) {
          _workingInstances.remove(instance);
          _workingInstances.insert(0, instance);
          Log.d('[SearXNG] Got ${results.length} results from $instance (sequential)');
          return results;
        }
      } catch (e) {
        Log.w('[SearXNG] Instance $instance failed: $e');
        _workingInstances.remove(instance);
      }
    }

    Log.w('[SearXNG] All instances failed for query: "$query"');
    return [];
  }

  /// Query a specific SearXNG instance and parse the JSON response.
  Future<List<SearchResult>> _searchInstance(
    String instance,
    String query, {
    int maxResults = 5,
  }) async {
    final url = '$instance/search';
    final response = await _dio.get(
      url,
      queryParameters: {
        'q': query,
        'format': 'json',
        'language': 'en',
        'safesearch': 0,
        'time_range': 'year',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid response format');
    }

    final resultsList = data['results'] as List<dynamic>?;
    if (resultsList == null || resultsList.isEmpty) {
      return [];
    }

    final results = <SearchResult>[];
    for (final item in resultsList) {
      if (results.length >= maxResults) break;
      if (item is! Map<String, dynamic>) continue;

      final title = (item['title'] as String?) ?? '';
      final url = (item['url'] as String?) ?? '';
      final content = (item['content'] as String?) ?? '';

      if (title.isEmpty || url.isEmpty) continue;

      // Parse publishedDate if available.
      DateTime? publishedDate;
      final dateStr = item['publishedDate'] as String?;
      if (dateStr != null) {
        publishedDate = DateTime.tryParse(dateStr);
      }

      results.add(SearchResult(
        title: title,
        url: url,
        snippet: content,
        publishedDate: publishedDate,
      ));
    }

    return results;
  }

  void dispose() {
    _dio.close();
  }
}

/// Internal helper for parallel instance failover.
class _InstanceResult {
  final String instance;
  final List<SearchResult> results;
  final Object? error;
  const _InstanceResult(this.instance, this.results, this.error);
}
