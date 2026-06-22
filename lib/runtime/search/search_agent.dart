import 'dart:async';

import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/search/content_extractor.dart';
import 'package:sutra/runtime/search/page_fetcher.dart';
import 'package:sutra/runtime/search/search_result.dart';
import 'package:sutra/runtime/search/web_search_service.dart';

/// Status of the search agent as it progresses through its workflow.
enum SearchAgentStatus {
  idle,
  analyzing,
  searching,
  fetching,
  extracting,
  reranking,
  generating,
  complete,
  error,
}

/// A citation linking the answer back to its source.
class Citation {
  final String title;
  final String url;

  const Citation({required this.title, required this.url});

  Map<String, dynamic> toJson() => {'title': title, 'url': url};

  @override
  String toString() => 'Citation($title, $url)';
}

/// Result from the search agent workflow.
class SearchAgentResult {
  final String answer;
  final List<Citation> citations;
  final bool searchUsed;
  final SearchAgentStatus status;

  const SearchAgentResult({
    required this.answer,
    this.citations = const [],
    this.searchUsed = true,
    this.status = SearchAgentStatus.complete,
  });
}

/// A ReAct-style search agent that orchestrates the full search workflow:
///
/// 1. Analyze the user query
/// 2. Generate an optimized search query
/// 3. Search the web (DuckDuckGo)
/// 4. Fetch top pages
/// 5. Extract readable content
/// 6. Rerank by relevance
/// 7. Build context for the LLM
/// 8. Generate an answer with citations
///
/// Returns results via a stream for real-time UI updates.
class SearchAgent {
  final WebSearchService _searchService;
  final PageFetcher _fetcher;
  final ContentExtractor _extractor;
  final Stream<String> Function(String prompt) _llmStream;

  SearchAgent({
    WebSearchService? searchService,
    PageFetcher? fetcher,
    ContentExtractor? extractor,
    required Stream<String> Function(String prompt) llmStream,
  })  : _searchService = searchService ?? WebSearchService(),
        _fetcher = fetcher ?? PageFetcher(),
        _extractor = extractor ?? ContentExtractor(),
        _llmStream = llmStream;

  /// Process a user query through the full search-and-answer pipeline.
  ///
  /// Emits status updates and partial answer tokens through the stream.
  ///
  /// [isCancelled] is checked at each pipeline step; when it returns
  /// `true`, the agent yields an error event and returns early.
  Stream<SearchAgentEvent> process(
    String query, {
    bool Function()? isCancelled,
  }) async* {
    final cancelled = isCancelled ?? () => false;

    // 1. Analyze: decide if search is needed and generate search query.
    yield SearchAgentEvent.statusChanged(SearchAgentStatus.analyzing);
    if (cancelled()) { yield SearchAgentEvent.error('Search cancelled.'); return; }

    final searchQuery = _optimizeQuery(query);

    // 2. Search the web.
    yield SearchAgentEvent.statusChanged(SearchAgentStatus.searching);
    if (cancelled()) { yield SearchAgentEvent.error('Search cancelled.'); return; }
    final searchResults = await _searchService.search(searchQuery);

    if (cancelled()) { yield SearchAgentEvent.error('Search cancelled.'); return; }

    if (searchResults.isEmpty) {
      yield SearchAgentEvent.statusChanged(SearchAgentStatus.generating);

      final answerBuffer = StringBuffer();
      await for (final token in _llmStream(
        _buildNoSearchPrompt(query),
      ).timeout(const Duration(seconds: 120), onTimeout: (sink) { sink.close(); })) {
        if (cancelled()) break;
        answerBuffer.write(token);
        yield SearchAgentEvent.token(token);
      }

      yield SearchAgentEvent.complete(SearchAgentResult(
        answer: cancelled() ? '' : answerBuffer.toString(),
        searchUsed: false,
        status: SearchAgentStatus.complete,
      ));
      return;
    }

    yield SearchAgentEvent.searchResults(searchResults);

    // 3. Fetch the top pages.
    yield SearchAgentEvent.statusChanged(SearchAgentStatus.fetching);
    if (cancelled()) { yield SearchAgentEvent.error('Search cancelled.'); return; }
    final urls = searchResults.map((r) => r.url).toList();
    final pages = await _fetcher.fetchMultiple(urls, maxPages: 3);

    // 4. Extract and rerank content.
    yield SearchAgentEvent.statusChanged(SearchAgentStatus.extracting);
    if (cancelled()) { yield SearchAgentEvent.error('Search cancelled.'); return; }
    final extractedContents = <ExtractedContent>[];
    final citations = <Citation>[];

    for (int i = 0; i < pages.length; i++) {
      if (cancelled()) { yield SearchAgentEvent.error('Search cancelled.'); return; }
      final page = pages[i];
      final result = searchResults.firstWhere(
        (r) => r.url == page.url,
        orElse: () => searchResults[i],
      );

      final content = _extractor.extract(page.html, page.url);
      extractedContents.add(content);
      citations.add(Citation(
        title: result.title.isNotEmpty ? result.title : content.title,
        url: page.url,
      ));
    }

    // 5. Rerank chunks by relevance to the original query.
    yield SearchAgentEvent.statusChanged(SearchAgentStatus.reranking);
    if (cancelled()) { yield SearchAgentEvent.error('Search cancelled.'); return; }

    final allChunks = <String>[];
    for (final content in extractedContents) {
      final chunks = _extractor.chunkContent(content.mainContent);
      allChunks.addAll(chunks);
    }
    final rankedChunks = _extractor.rerankChunks(allChunks, query);

    // Keep top chunks but cap total context to ~3000 chars
    // to avoid exceeding small model context windows.
    final topChunks = <String>[];
    var totalLen = 0;
    for (final chunk in rankedChunks) {
      if (totalLen + chunk.length > 3000) break;
      topChunks.add(chunk);
      totalLen += chunk.length;
    }

    // 6. Build context and generate answer via LLM.
    yield SearchAgentEvent.statusChanged(SearchAgentStatus.generating);
    if (cancelled()) { yield SearchAgentEvent.error('Search cancelled.'); return; }

    final contextPrompt = _buildContextPrompt(query, topChunks, citations);
    final answerBuffer = StringBuffer();

    try {
      // Add a timeout so we don't hang forever if the model stalls.
      final streamFuture = _llmStream(contextPrompt).timeout(
        const Duration(seconds: 120),
        onTimeout: (sink) {
          Log.w('[SearchAgent] LLM stream timed out after 120s');
          sink.close();
        },
      );

      await for (final token in streamFuture) {
        if (cancelled()) break;
        answerBuffer.write(token);
        yield SearchAgentEvent.token(token);
      }
    } catch (e) {
      Log.e('[SearchAgent] LLM stream error: $e');
    }

    if (cancelled()) { yield SearchAgentEvent.error('Search cancelled.'); return; }

    final answer = answerBuffer.toString();
    if (answer.isEmpty) {
      yield SearchAgentEvent.complete(SearchAgentResult(
        answer: '⚠️ The model was unable to generate a response. The context may have been too large for the model.',
        citations: citations,
        searchUsed: true,
        status: SearchAgentStatus.complete,
      ));
      return;
    }

    yield SearchAgentEvent.complete(SearchAgentResult(
      answer: answer,
      citations: citations,
      searchUsed: true,
      status: SearchAgentStatus.complete,
    ));
  }

  /// Optimize the user query for web search.
  ///
  /// For now, uses the raw query. A more sophisticated version would
  /// use the LLM to rewrite the query for better search results.
  String _optimizeQuery(String query) {
    // Remove common conversational phrases that hurt search results.
    var optimized = query
        .replaceAll(RegExp(r'\b(can you|could you|please|tell me about|what is|what are|how do|how does|explain)\b', caseSensitive: false), '')
        .trim();

    // If the query became too short after stripping, use the original.
    if (optimized.split(' ').length < 2) {
      return query;
    }
    return optimized;
  }

  /// Build a prompt for when no search results are available.
  String _buildNoSearchPrompt(String query) {
    return 'Answer the following question based on your knowledge. '
        'Note: No web search results were available, so answer from '
        'your training data only. If you are not confident, say so.\n\n'
        'Question: $query\n\nAnswer:';
  }

  /// Build a context prompt with retrieved content and citations.
  String _buildContextPrompt(
    String query,
    List<String> chunks,
    List<Citation> citations,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('You are a helpful research assistant. Answer the user\'s '
        'question using ONLY the provided sources. Include citations as '
        '[1], [2], etc. referencing the source list below.');
    buffer.writeln();
    buffer.writeln('RULES:');
    buffer.writeln('- Use only the provided sources to answer.');
    buffer.writeln('- Distinguish facts from the sources vs. your inference.');
    buffer.writeln('- If evidence is insufficient, say so.');
    buffer.writeln('- Be concise and direct.');
    buffer.writeln();
    buffer.writeln('SOURCES:');
    for (int i = 0; i < citations.length; i++) {
      buffer.writeln('[${i + 1}] ${citations[i].title} — ${citations[i].url}');
    }
    buffer.writeln();
    buffer.writeln('RETRIEVED CONTENT:');
    for (final chunk in chunks) {
      buffer.writeln('---');
      buffer.writeln(chunk);
    }
    buffer.writeln();
    buffer.writeln('USER QUESTION: $query');
    buffer.writeln();
    buffer.writeln('ANSWER:');
    return buffer.toString();
  }

  void dispose() {
    _searchService.dispose();
    _fetcher.dispose();
  }
}

/// Events emitted by the search agent during processing.
sealed class SearchAgentEvent {
  const SearchAgentEvent();

  factory SearchAgentEvent.statusChanged(SearchAgentStatus status) =
      StatusChangedEvent;
  factory SearchAgentEvent.token(String token) = TokenEvent;
  factory SearchAgentEvent.searchResults(List<SearchResult> results) =
      SearchResultsEvent;
  factory SearchAgentEvent.complete(SearchAgentResult result) =
      CompleteEvent;
  factory SearchAgentEvent.error(String message) = ErrorEvent;
}

class StatusChangedEvent extends SearchAgentEvent {
  final SearchAgentStatus status;
  const StatusChangedEvent(this.status);
}

class TokenEvent extends SearchAgentEvent {
  final String token;
  const TokenEvent(this.token);
}

class SearchResultsEvent extends SearchAgentEvent {
  final List<SearchResult> results;
  const SearchResultsEvent(this.results);
}

class CompleteEvent extends SearchAgentEvent {
  final SearchAgentResult result;
  const CompleteEvent(this.result);
}

class ErrorEvent extends SearchAgentEvent {
  final String message;
  const ErrorEvent(this.message);
}
