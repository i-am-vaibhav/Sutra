import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/search/searxng_search_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a SearXNG-style JSON response body.
Map<String, dynamic> _searxngBody(List<Map<String, dynamic>> items) => {
      'results': items,
    };

/// Builds a single result item for the `results` array.
Map<String, dynamic> _resultItem({
  required String title,
  required String url,
  String content = '',
  String? publishedDate,
}) =>
    {
      'title': title,
      'url': url,
      'content': content,
      if (publishedDate case final date?) 'publishedDate': date,
    };

/// Encodes [body] as UTF-8 bytes for use in a [ResponseBody].
Uint8List _encodeJson(Map<String, dynamic> body) =>
    Uint8List.fromList(utf8.encode(json.encode(body)));

/// Creates a [ResponseBody] with the given [statusCode] and JSON [body].
ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) =>
    ResponseBody.fromBytes(
      _encodeJson(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

/// Creates a [ResponseBody] with a raw string body.
ResponseBody _textResponse(int statusCode, String text) =>
    ResponseBody.fromBytes(
      Uint8List.fromList(utf8.encode(text)),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );

// ---------------------------------------------------------------------------
// Mock HttpClientAdapter
// ---------------------------------------------------------------------------

/// A simple stub entry: URL pattern + response factory.
class _Stub {
  final String pattern;
  final ResponseBody Function(RequestOptions) factory;
  const _Stub(this.pattern, this.factory);
}

/// A configurable mock of Dio's [HttpClientAdapter].
///
/// Register responses per URL pattern. The first matching pattern wins.
class MockHttpClientAdapter implements HttpClientAdapter {
  final List<_Stub> _stubs = [];

  /// URLs that were actually requested, in order.
  final List<String> requestLog = [];

  /// Registers a successful JSON response for URLs containing [pattern].
  void whenGetJson(String pattern, int statusCode, Map<String, dynamic> body) {
    _stubs.add(_Stub(pattern, (options) => _jsonResponse(statusCode, body)));
  }

  /// Registers a raw text response for URLs containing [pattern].
  void whenGetText(String pattern, int statusCode, String text) {
    _stubs.add(_Stub(pattern, (options) => _textResponse(statusCode, text)));
  }

  /// Registers an error for URLs containing [pattern].
  void whenGetError(String pattern, Exception exception) {
    _stubs.add(_Stub(pattern, (options) {
      // ignore: only_throw_errors
      throw exception;
    }));
  }

  /// Clear all registered stubs.
  void clearStubs() => _stubs.clear();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    requestLog.add(options.uri.toString());

    for (final stub in _stubs) {
      if (options.uri.toString().contains(stub.pattern)) {
        return stub.factory(options);
      }
    }

    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'No mock registered for ${options.uri}',
    );
  }

  @override
  void close({bool force = false}) {}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SearxngSearchService', () {
    late MockHttpClientAdapter mockAdapter;
    late Dio dio;
    late SearxngSearchService service;

    setUp(() {
      mockAdapter = MockHttpClientAdapter();
      dio = Dio();
      dio.httpClientAdapter = mockAdapter;
      service = SearxngSearchService(dio: dio);
    });

    tearDown(() {
      service.dispose();
    });

    // ── JSON parsing ──────────────────────────────────────────────────────

    group('JSON parsing', () {
      test('parses valid results with all fields', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          _searxngBody([
            _resultItem(
              title: 'Flutter Docs',
              url: 'https://flutter.dev',
              content: 'Build apps for any screen',
              publishedDate: '2025-01-15T10:30:00Z',
            ),
            _resultItem(
              title: 'Dart Lang',
              url: 'https://dart.dev',
              content: 'The Dart programming language',
            ),
          ]),
        );

        final results = await service.search('flutter');

        expect(results, hasLength(2));
        expect(results[0].title, 'Flutter Docs');
        expect(results[0].url, 'https://flutter.dev');
        expect(results[0].snippet, 'Build apps for any screen');
        expect(results[0].publishedDate, isNotNull);

        expect(results[1].title, 'Dart Lang');
        expect(results[1].url, 'https://dart.dev');
        expect(results[1].snippet, 'The Dart programming language');
        expect(results[1].publishedDate, isNull);
      });

      test('skips items missing title or url', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          _searxngBody([
            _resultItem(title: 'Good', url: 'https://good.com'),
            {'title': '', 'url': 'https://empty.com', 'content': ''},
            {'title': 'No URL', 'content': 'missing url field'},
            _resultItem(title: 'Also Good', url: 'https://good2.com'),
          ]),
        );

        final results = await service.search('test');

        expect(results, hasLength(2));
        expect(results[0].title, 'Good');
        expect(results[1].title, 'Also Good');
      });

      test('handles missing results key gracefully', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          <String, dynamic>{},
        );

        final results = await service.search('test');

        expect(results, isEmpty);
      });

      test('handles empty results array', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          _searxngBody([]),
        );

        final results = await service.search('test');

        expect(results, isEmpty);
      });

      test('handles non-Map response body', () async {
        mockAdapter.whenGetText('search.sapti.me', 200, 'not a map');

        final results = await service.search('test');

        expect(results, isEmpty);
      });

      test('handles null content field', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          _searxngBody([
            {
              'title': 'No Content',
              'url': 'https://example.com',
            },
          ]),
        );

        final results = await service.search('test');

        expect(results, hasLength(1));
        expect(results[0].snippet, '');
      });

      test('respects maxResults limit', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          _searxngBody([
            _resultItem(title: 'R1', url: 'https://1.com'),
            _resultItem(title: 'R2', url: 'https://2.com'),
            _resultItem(title: 'R3', url: 'https://3.com'),
            _resultItem(title: 'R4', url: 'https://4.com'),
            _resultItem(title: 'R5', url: 'https://5.com'),
            _resultItem(title: 'R6', url: 'https://6.com'),
          ]),
        );

        final results = await service.search('test', maxResults: 3);

        expect(results, hasLength(3));
        expect(results[2].title, 'R3');
      });

      test('parses invalid publishedDate without crashing', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          _searxngBody([
            _resultItem(
              title: 'Bad Date',
              url: 'https://example.com',
              publishedDate: 'not-a-date',
            ),
          ]),
        );

        final results = await service.search('test');

        expect(results, hasLength(1));
        expect(results[0].publishedDate, isNull);
      });

      test('skips non-Map items in results array', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          {
            'results': [
              'not a map',
              42,
              null,
              _resultItem(title: 'Valid', url: 'https://valid.com'),
            ],
          },
        );

        final results = await service.search('test');

        expect(results, hasLength(1));
        expect(results[0].title, 'Valid');
      });
    });

    // ── HTTP errors ───────────────────────────────────────────────────────

    group('HTTP errors', () {
      test('non-200 status throws and falls through to next instance',
          () async {
        mockAdapter.whenGetJson('search.sapti.me', 500, <String, dynamic>{});
        mockAdapter.whenGetJson(
          'searx.tiekoetter.com',
          200,
          _searxngBody([
            _resultItem(title: 'OK', url: 'https://ok.com'),
          ]),
        );

        final results = await service.search('test');

        expect(results, hasLength(1));
        expect(results[0].title, 'OK');
      });
    });

    // ── Instance failover ─────────────────────────────────────────────────

    group('instance failover', () {
      test('tries next instance when first throws DioException', () async {
        mockAdapter.whenGetError(
          'search.sapti.me',
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
            message: 'timeout',
          ),
        );
        mockAdapter.whenGetJson(
          'searx.tiekoetter.com',
          200,
          _searxngBody([
            _resultItem(title: 'Fallback', url: 'https://fallback.com'),
          ]),
        );

        final results = await service.search('test');

        expect(results, hasLength(1));
        expect(results[0].title, 'Fallback');
        // Parallel failover fires top 3 instances simultaneously.
        expect(mockAdapter.requestLog, hasLength(3));
        expect(mockAdapter.requestLog.any((u) => u.contains('tiekoetter')),
            isTrue);
      });

      test('tries next instance when first returns empty results', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          _searxngBody([]),
        );
        mockAdapter.whenGetJson(
          'searx.tiekoetter.com',
          200,
          _searxngBody([
            _resultItem(title: 'Second', url: 'https://second.com'),
          ]),
        );

        final results = await service.search('test');

        expect(results, hasLength(1));
        expect(results[0].title, 'Second');
      });

      test('returns empty list when all instances fail', () async {
        for (final instance in [
          'search.sapti.me',
          'searx.tiekoetter.com',
          'search.bus-hit.me',
          'searx.work',
          'search.ononoki.org',
          'searxng.ch',
          'search.projectsegfau.lt',
        ]) {
          mockAdapter.whenGetError(
            instance,
            DioException(
              requestOptions: RequestOptions(path: ''),
              type: DioExceptionType.connectionError,
              message: 'down',
            ),
          );
        }

        final results = await service.search('test');

        expect(results, isEmpty);
        expect(mockAdapter.requestLog, hasLength(7));
      });

      test('moves successful instance to front of working list', () async {
        // First instance times out.
        mockAdapter.whenGetError(
          'search.sapti.me',
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionTimeout,
          ),
        );
        // Second instance works.
        mockAdapter.whenGetJson(
          'searx.tiekoetter.com',
          200,
          _searxngBody([
            _resultItem(title: 'OK', url: 'https://ok.com'),
          ]),
        );

        await service.search('test');

        // Second search: tiekoetter should be tried first (promoted to front).
        mockAdapter.requestLog.clear();
        mockAdapter.clearStubs();
        mockAdapter.whenGetJson(
          'searx.tiekoetter.com',
          200,
          _searxngBody([
            _resultItem(title: 'OK2', url: 'https://ok2.com'),
          ]),
        );

        final results2 = await service.search('test again');

        expect(results2, hasLength(1));
        expect(
            mockAdapter.requestLog.first, contains('searx.tiekoetter.com'));
      });

      test('removes failed instance from working list', () async {
        // First instance throws DioException → removed from working list.
        mockAdapter.whenGetError(
          'search.sapti.me',
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionError,
            message: 'down',
          ),
        );
        // Second instance works.
        mockAdapter.whenGetJson(
          'searx.tiekoetter.com',
          200,
          _searxngBody([
            _resultItem(title: 'OK', url: 'https://ok.com'),
          ]),
        );

        final results = await service.search('test');
        expect(results, hasLength(1));
        // Parallel failover fires top 3 instances simultaneously.
        expect(mockAdapter.requestLog, hasLength(3));

        // Second search: sapti.me should NOT be tried at all.
        mockAdapter.clearStubs();
        mockAdapter.whenGetJson(
          'searx.tiekoetter.com',
          200,
          _searxngBody([
            _resultItem(title: 'OK2', url: 'https://ok2.com'),
          ]),
        );
        mockAdapter.requestLog.clear();
        await service.search('test2');

        // Parallel failover fires top 3 from working list (tiekoetter + 2 others).
        // sapti.me is NOT in any of those requests.
        expect(mockAdapter.requestLog.length, greaterThanOrEqualTo(1));
        expect(
            mockAdapter.requestLog.any((u) => u.contains('tiekoetter')),
            isTrue);
        expect(
            mockAdapter.requestLog.every((u) => !u.contains('sapti.me')),
            isTrue, reason: 'sapti.me should have been removed');
      });

      test('skips non-200 status and tries next instance', () async {
        mockAdapter.whenGetJson('search.sapti.me', 403, <String, dynamic>{});
        mockAdapter.whenGetJson(
          'searx.tiekoetter.com',
          200,
          _searxngBody([
            _resultItem(title: 'Allowed', url: 'https://allowed.com'),
          ]),
        );

        final results = await service.search('test');

        expect(results, hasLength(1));
        expect(results[0].title, 'Allowed');
      });
    });

    // ── Request format ────────────────────────────────────────────────────

    group('request format', () {
      test('sends /search path with correct query parameters', () async {
        mockAdapter.whenGetJson(
          'search.sapti.me',
          200,
          _searxngBody([]),
        );

        await service.search('my query');

        final uri = Uri.parse(mockAdapter.requestLog.first);
        expect(uri.path, '/search');
        expect(uri.queryParameters['q'], 'my query');
        expect(uri.queryParameters['format'], 'json');
        expect(uri.queryParameters['language'], 'en');
        expect(uri.queryParameters['safesearch'], '0');
      });
    });
  });
}
