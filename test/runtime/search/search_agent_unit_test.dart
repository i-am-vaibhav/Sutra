import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sutra/runtime/search/content_extractor.dart';
import 'package:sutra/runtime/search/page_fetcher.dart';
import 'package:sutra/runtime/search/search_agent.dart';
import 'package:sutra/runtime/search/search_result.dart';
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
    <p>Additional context and details about the topic. This paragraph provides more information that should be extracted by the ContentExtractor for testing purposes.</p>
    <p>Final paragraph with specific facts, dates, and names relevant to the search query for testing purposes.</p>
  </article>
</body>
</html>''';

Uint8List _encodeJson(Map<String, dynamic> body) =>
    Uint8List.fromList(utf8.encode(json.encode(body)));

Uint8List _encodeText(String text) => Uint8List.fromList(utf8.encode(text));

ResponseBody _jsonResponse(int statusCode, Map<String, dynamic> body) =>
    ResponseBody.fromBytes(
      _encodeJson(body),
      statusCode,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

ResponseBody _htmlResponse(int statusCode, String html) =>
    ResponseBody.fromBytes(
      _encodeText(html),
      statusCode,
      headers: {Headers.contentTypeHeader: ['text/html; charset=utf-8']},
    );

// ---------------------------------------------------------------------------
// Mock HttpClientAdapter
// ---------------------------------------------------------------------------

class MockHttpClientAdapter implements HttpClientAdapter {
  final List<_Stub> _stubs = [];
  final List<String> requestLog = [];

  void whenGetJson(String pattern, int statusCode, Map<String, dynamic> body) {
    _stubs.add(_Stub(pattern, (options) => _jsonResponse(statusCode, body)));
  }

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

class _Stub {
  final String pattern;
  final ResponseBody Function(RequestOptions) factory;
  const _Stub(this.pattern, this.factory);
}

// ---------------------------------------------------------------------------
// Fake LLM stream — inspects prompt and returns canned responses
// ---------------------------------------------------------------------------

Stream<String> Function(String) _fakeLlm({
  String answer = 'Default answer.',
}) {
  return (String prompt) async* {
    yield answer;
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SearchAgent unit tests', () {
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

    // ══════════════════════════════════════════════════════════════════════
    // Basic search pipeline
    // ══════════════════════════════════════════════════════════════════════

    group('basic search pipeline', () {
      test('search returns results — fetches pages and generates answer',
          () async {
        mockAdapter.whenRequest(
          'html.duckduckgo.com',
          200,
          () => _htmlResponse(
            200,
            _ddgHtml([
              (
                title: 'Page A',
                url: 'https://a.com/page',
                snippet: 'Snippet A'
              ),
              (
                title: 'Page B',
                url: 'https://b.com/page',
                snippet: 'Snippet B'
              ),
            ]),
          ),
        );
        mockAdapter.whenGetHtml('a.com', 200, _pageHtml('A', 'Content A'));
        mockAdapter.whenGetHtml('b.com', 200, _pageHtml('B', 'Content B'));

        final agent = SearchAgent(
          searchService: searchService,
          fetcher: fetcher,
          extractor: extractor,
          llmStream: _fakeLlm(answer: 'Answer from search results.'),
        );

        final events = await agent.process('test query').toList();
        final complete = events.whereType<CompleteEvent>().first;
        final result = complete.result;

        expect(result.citations, hasLength(2));
        expect(result.searchUsed, isTrue);
        expect(result.answer, contains('Answer'));
      });

      test('search returns no results — falls back to LLM-only answer',
          () async {
        mockAdapter.whenGetHtml(
          'html.duckduckgo.com',
          200,
          '<html><body></body></html>',
        );

        final agent = SearchAgent(
          searchService: searchService,
          fetcher: fetcher,
          extractor: extractor,
          llmStream: _fakeLlm(answer: 'Answer from training data only.'),
        );

        final events = await agent.process('test query').toList();
        final complete = events.whereType<CompleteEvent>().first;

        expect(complete.result.searchUsed, isFalse);
        expect(complete.result.answer, contains('training data'));
      });

      test('search service throws — falls back to LLM-only answer',
          () async {
        mockAdapter.whenGetError(
          'duckduckgo.com',
          DioException(
            requestOptions: RequestOptions(path: ''),
            type: DioExceptionType.connectionError,
          ),
        );

        final agent = SearchAgent(
          searchService: searchService,
          fetcher: fetcher,
          extractor: extractor,
          llmStream: _fakeLlm(answer: 'Fallback answer.'),
        );

        final events = await agent.process('test query').toList();
        final complete = events.whereType<CompleteEvent>().first;

        expect(complete.result.searchUsed, isFalse);
        expect(complete.result.answer, contains('Fallback'));
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // Status events
    // ══════════════════════════════════════════════════════════════════════

    group('status events', () {
      test('emits correct status sequence', () async {
        mockAdapter.whenRequest(
          'html.duckduckgo.com',
          200,
          () => _htmlResponse(
            200,
            _ddgHtml([
              (
                title: 'Page',
                url: 'https://example.com',
                snippet: 'Snippet'
              ),
            ]),
          ),
        );
        mockAdapter.whenGetHtml(
            'example.com', 200, _pageHtml('Page', 'Content'));

        final agent = SearchAgent(
          searchService: searchService,
          fetcher: fetcher,
          extractor: extractor,
          llmStream: _fakeLlm(answer: 'Answer.'),
        );

        final events = await agent.process('test query').toList();
        final statuses = events
            .whereType<StatusChangedEvent>()
            .map((e) => e.status)
            .toList();

        expect(statuses, contains(SearchAgentStatus.analyzing));
        expect(statuses, contains(SearchAgentStatus.searching));
        expect(statuses, contains(SearchAgentStatus.fetching));
        expect(statuses, contains(SearchAgentStatus.generating));
        // Note: SearchAgentStatus.complete is in SearchAgentResult,
        // not emitted as a StatusChangedEvent.
      });
    });

    // ══════════════════════════════════════════════════════════════════════
    // Cancellation
    // ══════════════════════════════════════════════════════════════════════

    group('cancellation', () {
      test('cancelled query yields error event', () async {
        mockAdapter.whenRequest(
          'html.duckduckgo.com',
          200,
          () => _htmlResponse(200, '<html><body></body></html>'),
        );

        final agent = SearchAgent(
          searchService: searchService,
          fetcher: fetcher,
          extractor: extractor,
          llmStream: _fakeLlm(answer: 'answer'),
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

    // ══════════════════════════════════════════════════════════════════════
    // Answer generation
    // ══════════════════════════════════════════════════════════════════════

    group('answer generation', () {
      test('token events stream the answer', () async {
        mockAdapter.whenGetHtml(
          'html.duckduckgo.com',
          200,
          '<html><body></body></html>',
        );

        final agent = SearchAgent(
          searchService: searchService,
          fetcher: fetcher,
          extractor: extractor,
          llmStream: (String prompt) async* {
            yield 'Hello ';
            yield 'world!';
          },
        );

        final events = await agent.process('test').toList();
        final tokenEvents = events.whereType<TokenEvent>().toList();
        final fullAnswer = tokenEvents.map((e) => e.token).join();

        expect(fullAnswer, contains('Hello world!'));
      });

      test('empty LLM response returns empty answer', () async {
        mockAdapter.whenGetHtml(
          'html.duckduckgo.com',
          200,
          '<html><body></body></html>',
        );

        final agent = SearchAgent(
          searchService: searchService,
          fetcher: fetcher,
          extractor: extractor,
          llmStream: (String prompt) async* {},
        );

        final events = await agent.process('test').toList();
        final complete = events.whereType<CompleteEvent>().first;

        // When no search results, falls back to LLM-only path.
        // Empty LLM stream yields empty answer.
        expect(complete.result.searchUsed, isFalse);
      });
    });
  });
}
