import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/search/content_extractor.dart';
import 'package:sutra/runtime/search/page_fetcher.dart';
import 'package:sutra/runtime/search/search_agent.dart';
import 'package:sutra/runtime/search/web_search_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _ddgHtml(List<({String title, String url, String snippet})> items) {
  final buffer = StringBuffer('<html><body>');
  for (final item in items) {
    buffer.writeln('''
<div class="result">
  <div class="result__body">
    <a class="result__a" href="https://duckduckgo.com/?q=test&amp;uddg=${Uri.encodeComponent(item.url)}">${item.title}</a>
    <div class="result__snippet">${item.snippet}</div>
  </div>
</div>''');
  }
  buffer.writeln('</body></html>');
  return buffer.toString();
}

String _pageHtml(String title, String bodyText) => '''
<!DOCTYPE html>
<html>
<head><title>$title</title></head>
<body>
  <article>
    <h1>$title</h1>
    <p>$bodyText</p>
    <p>Additional context and details about the topic. This paragraph provides more information that should be extracted by the ContentExtractor.</p>
    <p>Final paragraph with specific facts, dates, and names relevant to the search query for testing purposes.</p>
  </article>
</body>
</html>''';

Uint8List _encodeText(String text) => Uint8List.fromList(utf8.encode(text));

ResponseBody _htmlResponse(int statusCode, String html) =>
    ResponseBody.fromBytes(
      _encodeText(html),
      statusCode,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );

// ---------------------------------------------------------------------------
// Mock HttpClientAdapter
// ---------------------------------------------------------------------------

class MockHttpClientAdapter implements HttpClientAdapter {
  final List<_Stub> _stubs = [];
  final List<String> requestLog = [];

  void whenGetHtml(String pattern, int statusCode, String html) {
    _stubs.add(_Stub(pattern, (options) => _htmlResponse(statusCode, html)));
  }

  void whenRequest(
      String pattern, int statusCode, ResponseBody Function() response) {
    _stubs.add(_Stub(pattern, (options) => response()));
  }

  void whenGetError(String pattern, Exception exception) {
    _stubs.add(_Stub(pattern, (options) {
      throw exception;
    }));
  }

  void clearStubs() => _stubs.clear();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requestLog.add(url);

    for (final stub in _stubs) {
      if (url.contains(stub.pattern)) {
        return stub.factory(options);
      }
    }

    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      message: 'No mock registered for $url',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Stub {
  final String pattern;
  final ResponseBody Function(RequestOptions) factory;
  const _Stub(this.pattern, this.factory);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SearchAgent integration', () {
    late MockHttpClientAdapter mockAdapter;
    late Dio ddgDio;
    late Dio pageDio;
    late WebSearchService searchService;
    late PageFetcher fetcher;
    late ContentExtractor extractor;

    setUp(() {
      mockAdapter = MockHttpClientAdapter();
      ddgDio = Dio()..httpClientAdapter = mockAdapter;
      pageDio = Dio()..httpClientAdapter = mockAdapter;
      searchService = WebSearchService(dio: ddgDio);
      fetcher = PageFetcher(dio: pageDio);
      extractor = ContentExtractor();
    });

    tearDown(() {
      searchService.dispose();
      fetcher.dispose();
    });

    test('full pipeline: search → fetch → generate answer', () async {
      // Mock DuckDuckGo HTML response.
      mockAdapter.whenRequest(
        'html.duckduckgo.com',
        200,
        () => _htmlResponse(
          200,
          _ddgHtml([
            (
              title: 'Flutter documentation',
              url: 'https://docs.flutter.dev',
              snippet: 'Flutter docs for building apps'
            ),
            (
              title: 'Dart programming language',
              url: 'https://dart.dev',
              snippet: 'Dart is a client-optimized language'
            ),
          ]),
        ),
      );

      // Mock page fetch responses (500+ words each for multiple chunks).
      final longContent = List.generate(600, (j) => 'word$j').join(' ');
      mockAdapter.whenGetHtml(
        'docs.flutter.dev', 200,
        _pageHtml('Flutter Documentation', longContent),
      );
      mockAdapter.whenGetHtml(
        'dart.dev', 200,
        _pageHtml('Dart Programming Language', longContent),
      );

      final agent = SearchAgent(
        searchService: searchService,
        fetcher: fetcher,
        extractor: extractor,
        llmStream: (String prompt) async* {
          yield 'Sutra is an on-device AI assistant that runs language models '
              'locally on your phone.';
        },
      );

      final events = await agent.process('What is Sutra?').toList();

      expect(events, isNotEmpty);

      // Should have status changes through the pipeline.
      final statuses = events
          .whereType<StatusChangedEvent>()
          .map((e) => e.status)
          .toList();
      expect(statuses, contains(SearchAgentStatus.analyzing));
      expect(statuses, contains(SearchAgentStatus.searching));
      expect(statuses, contains(SearchAgentStatus.fetching));
      expect(statuses, contains(SearchAgentStatus.generating));

      // Should have token events (streaming answer).
      final tokenEvents = events.whereType<TokenEvent>().toList();
      expect(tokenEvents, isNotEmpty);
      final fullAnswer = tokenEvents.map((e) => e.token).join();
      expect(fullAnswer, contains('Sutra'));

      // Should have a complete event with result.
      final completeEvents = events.whereType<CompleteEvent>().toList();
      expect(completeEvents, hasLength(1));
      final result = completeEvents.first.result;
      expect(result.answer, contains('Sutra'));
      expect(result.searchUsed, isTrue);
      expect(result.status, SearchAgentStatus.complete);
      expect(result.citations, isNotEmpty);

      // Verify HTTP requests were made.
      expect(mockAdapter.requestLog, isNotEmpty);
      expect(
        mockAdapter.requestLog.any((u) => u.contains('duckduckgo.com')),
        isTrue,
      );
      expect(
        mockAdapter.requestLog.any((u) => u.contains('docs.flutter.dev')),
        isTrue,
      );
    });

    test('pipeline with no results falls back to LLM-only answer', () async {
      mockAdapter.whenRequest(
        'html.duckduckgo.com',
        200,
        () => _htmlResponse(200, '<html><body></body></html>'),
      );

      final agent = SearchAgent(
        searchService: searchService,
        fetcher: fetcher,
        extractor: extractor,
        llmStream: (String prompt) async* {
          yield 'I can answer this from my training data.';
        },
      );

      final events = await agent.process('What is 2+2?').toList();

      final completeEvents = events.whereType<CompleteEvent>().toList();
      expect(completeEvents, hasLength(1));

      final result = completeEvents.first.result;
      expect(result.answer, contains('training data'));
      expect(result.searchUsed, isFalse,
          reason: 'No search results found, falls back to LLM');
    });

    test('pipeline handles DuckDuckGo failure gracefully', () async {
      mockAdapter.whenGetError(
        'duckduckgo.com',
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
          message: 'DDG down',
        ),
      );

      final agent = SearchAgent(
        searchService: searchService,
        fetcher: fetcher,
        extractor: extractor,
        llmStream: (String prompt) async* {
          yield 'Flutter is Google\'s UI toolkit.';
        },
      );

      final events = await agent.process('Tell me about Flutter').toList();

      final completeEvents = events.whereType<CompleteEvent>().toList();
      expect(completeEvents, hasLength(1));
      expect(completeEvents.first.result.answer, contains('Flutter'));
      expect(completeEvents.first.result.searchUsed, isFalse);
    });

    test('pipeline with cancelled query yields error event', () async {
      mockAdapter.whenRequest(
        'html.duckduckgo.com',
        200,
        () => _htmlResponse(200, '<html><body></body></html>'),
      );

      final agent = SearchAgent(
        searchService: searchService,
        fetcher: fetcher,
        extractor: extractor,
        llmStream: (String prompt) async* {
          yield 'answer';
        },
      );

      var cancelCount = 0;
      final events = await agent
          .process(
            'Cancelled query',
            isCancelled: () => ++cancelCount > 1,
          )
          .toList();

      final errorEvents = events.whereType<ErrorEvent>().toList();
      expect(errorEvents, isNotEmpty);
      expect(errorEvents.first.message, contains('cancelled'));
    });
  });
}
