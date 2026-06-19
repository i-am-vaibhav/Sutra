import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:sutra/core/logging/log.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';
import 'package:sutra/runtime/search/search_agent.dart';
import 'package:sutra/runtime/search/search_result.dart';

/// State of the web search feature.
class WebSearchState {
  /// Whether web search is enabled for the next message.
  final bool enabled;

  /// Current status of the agent.
  final SearchAgentStatus status;

  /// Status label shown to the user.
  final String statusLabel;

  /// Search results found by the agent.
  final List<SearchResult> searchResults;

  /// Citations for the current response.
  final List<Citation> citations;

  /// The accumulated answer text.
  final String answer;

  /// Error message if the agent failed.
  final String? error;

  const WebSearchState({
    this.enabled = false,
    this.status = SearchAgentStatus.idle,
    this.statusLabel = '',
    this.searchResults = const [],
    this.citations = const [],
    this.answer = '',
    this.error,
  });

  bool get isIdle => status == SearchAgentStatus.idle;
  bool get isBusy =>
      status != SearchAgentStatus.idle &&
      status != SearchAgentStatus.complete &&
      status != SearchAgentStatus.error;

  WebSearchState copyWith({
    bool? enabled,
    SearchAgentStatus? status,
    String? statusLabel,
    List<SearchResult>? searchResults,
    List<Citation>? citations,
    String? answer,
    String? error,
    bool clearError = false,
  }) {
    return WebSearchState(
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      searchResults: searchResults ?? this.searchResults,
      citations: citations ?? this.citations,
      answer: answer ?? this.answer,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Manages the web search agent lifecycle and state.
class WebSearchNotifier extends StateNotifier<WebSearchState> {
  final Ref ref;

  WebSearchNotifier(this.ref) : super(const WebSearchState());

  StreamSubscription<SearchAgentEvent>? _subscription;
  bool _cancelRequested = false;

  /// Whether a cancel has been requested (checked by the agent loop).
  bool get isCancelRequested => _cancelRequested;

  /// Toggle web search on/off for the next message.
  void toggle() {
    state = state.copyWith(enabled: !state.enabled);
  }

  /// Cancel the in-progress search.
  ///
  /// Only sets the flag and updates state — the subscription is NOT
  /// cancelled here so the completer in [runSearch] can complete
  /// naturally when the agent's isCancelled checks bail out.
  void cancelSearch() {
    Log.d('[WebSearch] Cancel requested');
    _cancelRequested = true;
    state = state.copyWith(
      status: SearchAgentStatus.error,
      error: 'Search cancelled.',
    );
  }

  /// Reset state after a search completes or is cancelled.
  void reset() {
    _cancelRequested = false;
    _subscription?.cancel();
    state = const WebSearchState();
  }

  /// Run the search agent on a query, streaming results back.
  ///
  /// Returns the final [SearchAgentResult] when complete.
  Future<SearchAgentResult?> runSearch(String query) async {
    Log.d('[WebSearch] runSearch called: "$query"');
    if (state.isBusy) {
      Log.w('[WebSearch] Already busy, skipping');
      return null;
    }

    state = state.copyWith(
      status: SearchAgentStatus.analyzing,
      statusLabel: 'Analyzing query...',
      enabled: false,
      clearError: true,
    );

    try {
      // Get the runtime manager for LLM inference.
      Log.d('[WebSearch] Waiting for runtime...');
      final runtimeManager = await ref.read(runtimeProvider.future);
      Log.d('[WebSearch] Runtime ready: isReady=${runtimeManager.isReady}');

      if (!runtimeManager.isReady) {
        Log.w('[WebSearch] Runtime not ready, aborting');
        state = state.copyWith(
          status: SearchAgentStatus.error,
          error: 'Model is not loaded. Please wait for model initialization.',
        );
        return null;
      }

      final agent = SearchAgent(
        llmStream: (prompt) {
          return runtimeManager.generateStream(prompt);
        },
      );

      SearchAgentResult? finalResult;

      // Listen to agent events and update state accordingly.
      final controller = StreamController<SearchAgentEvent>();

      // Run agent in background and pipe events to controller.
      agent.process(query, isCancelled: () => _cancelRequested).listen(
        controller.add,
        onDone: () => controller.close(),
        onError: (e) => controller.add(SearchAgentEvent.error(e.toString())),
      );

      final completer = Completer<void>();

      _subscription = controller.stream.listen(
        (event) {
          if (!mounted) return;

          switch (event) {
            case StatusChangedEvent(:final status):
              state = state.copyWith(
                status: status,
                statusLabel: _statusLabel(status),
              );
            case TokenEvent(:final token):
              state = state.copyWith(answer: state.answer + token);
            case SearchResultsEvent(:final results):
              state = state.copyWith(searchResults: results);
            case CompleteEvent(:final result):
              finalResult = result;
              state = state.copyWith(
                status: SearchAgentStatus.complete,
                citations: result.citations,
                answer: result.answer,
              );
            case ErrorEvent(:final message):
              state = state.copyWith(
                status: SearchAgentStatus.error,
                error: message,
              );
          }
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (e) {
          if (!completer.isCompleted) completer.complete();
        },
      );

      // Wait for the subscription to complete.
      await completer.future;
      await _subscription?.cancel();
      agent.dispose();

      return finalResult;
    } catch (e) {
      Log.e('[WebSearch] Agent failed: $e');
      state = state.copyWith(
        status: SearchAgentStatus.error,
        error: 'Search failed: $e',
      );
      return null;
    }
  }

  String _statusLabel(SearchAgentStatus status) {
    switch (status) {
      case SearchAgentStatus.idle:
        return '';
      case SearchAgentStatus.analyzing:
        return 'Analyzing your question...';
      case SearchAgentStatus.searching:
        return 'Searching the web...';
      case SearchAgentStatus.fetching:
        return 'Reading web pages...';
      case SearchAgentStatus.extracting:
        return 'Extracting content...';
      case SearchAgentStatus.reranking:
        return 'Ranking sources...';
      case SearchAgentStatus.generating:
        return 'Generating answer...';
      case SearchAgentStatus.complete:
        return '';
      case SearchAgentStatus.error:
        return '';
    }
  }
}

final webSearchProvider =
    StateNotifierProvider<WebSearchNotifier, WebSearchState>((ref) {
  return WebSearchNotifier(ref);
});
