import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sutra/core/storage/chat_repository.dart';
import 'package:sutra/features/chat/chat_message.dart';
import 'package:sutra/features/chat/chat_provider.dart';
import 'package:sutra/runtime/llm/llm_runtime.dart';
import 'package:sutra/runtime/pipeline/runtime_manager.dart';
import 'package:sutra/runtime/pipeline/runtime_provider.dart';
import 'package:sutra/runtime/search/search_agent.dart';
import 'package:sutra/runtime/search/search_result.dart';
import 'package:sutra/runtime/search/web_search_provider.dart';

/// A mock [LlmRuntime] that returns controlled token streams.
class MockLlmRuntime extends LlmRuntime {
  final bool _isReady;
  final List<Stream<String> Function(String)> _streamBuilders;

  MockLlmRuntime({
    bool isReady = true,
    List<Stream<String> Function(String)> streamBuilders = const [],
  })  : _isReady = isReady,
        _streamBuilders = streamBuilders;

  int _callIndex = 0;

  @override
  bool get isReady => _isReady;

  @override
  Stream<String> generateStream(String prompt) {
    if (_callIndex < _streamBuilders.length) {
      final builder = _streamBuilders[_callIndex];
      _callIndex++;
      return builder(prompt);
    }
    return Stream.value('');
  }
}

/// A fake [ChatRepository] that stores messages in memory.
class FakeChatRepository extends ChatRepository {
  final Map<String, List<Map<String, dynamic>>> _messages = {};
  final Map<String, Map<String, dynamic>> _sessions = {};
  int _sessionCounter = 0;

  @override
  Future<ChatSession> createSession({String? title}) async {
    final now = DateTime.now();
    final id = 'session_${_sessionCounter++}';
    _sessions[id] = {
      'id': id,
      'title': title ?? 'New conversation',
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
    };
    _messages[id] = [];
    return ChatSession(
      id: id,
      title: title ?? 'New conversation',
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<List<ChatSession>> getSessions({bool includeArchived = false}) async {
    return _sessions.values
        .map((s) => ChatSession(
              id: s['id'] as String,
              title: s['title'] as String,
              createdAt: DateTime.fromMillisecondsSinceEpoch(s['createdAt'] as int),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(s['updatedAt'] as int),
            ))
        .toList();
  }

  @override
  Future<void> saveMessage(Map<String, dynamic> msg) async {
    final sessionId = msg['sessionId'] as String?;
    if (sessionId != null) {
      _messages[sessionId] ??= [];
      _messages[sessionId]!.add(msg);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMessages(String sessionId) async {
    return _messages[sessionId] ?? [];
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagesPaginated(String sessionId, {int limit = 50}) async {
    final messages = _messages[sessionId] ?? [];
    return messages.take(limit).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getMessagesBefore(String sessionId, {required int beforeTimestamp, int limit = 50}) async {
    final messages = _messages[sessionId] ?? [];
    return messages.where((m) => (m['createdAt'] as int) < beforeTimestamp).take(limit).toList();
  }

  @override
  Future<int> countMessages(String sessionId) async {
    return (_messages[sessionId] ?? []).length;
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    for (final messages in _messages.values) {
      messages.removeWhere((m) => m['id'] == messageId);
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    _messages.remove(sessionId);
    _sessions.remove(sessionId);
  }

  @override
  Future<void> clearSession(String sessionId) async {
    _messages.remove(sessionId);
  }

  @override
  Future<void> archiveSession(String sessionId) async {}

  @override
  Future<void> unarchiveSession(String sessionId) async {}

  @override
  Future<void> updateSessionTitle(String sessionId, String title) async {}

  @override
  Future<void> restoreSession(ChatSession session, List<Map<String, dynamic>> messages) async {}

  @override
  Future<void> touchSession(String sessionId) async {}
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('WebSearchNotifier.runSearch', () {
    late ProviderContainer container;
    late MockLlmRuntime mockRuntime;
    late FakeChatRepository fakeRepo;

    setUp(() {
      mockRuntime = MockLlmRuntime();
      fakeRepo = FakeChatRepository();
    });

    tearDown(() {
      container.dispose();
    });

    test('successful search flow emits status updates and result', () async {
      mockRuntime = MockLlmRuntime(
        streamBuilders: [
          // First call: query analysis — returns two valid queries
          (prompt) => Stream.fromIterable(['weather London\n', 'latest forecast']),
          // Second call: answer generation
          (prompt) => Stream.fromIterable(['Sunny', ' with', ' clouds']),
        ],
      );

      container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            AsyncValue.data(RuntimeManager(mockRuntime)),
          ),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(webSearchProvider.notifier);
      final result = await notifier.runSearch('What is the weather in London?');

      expect(notifier.state.status, SearchAgentStatus.complete);
      expect(result, isNotNull);
      expect(result!.answer, contains('Sunny'));
    });

    test('returns null when already busy', () async {
      mockRuntime = MockLlmRuntime(
        streamBuilders: [
          (prompt) => Stream.fromIterable(['query one\n', 'query two']),
          (prompt) => Stream.value('answer'),
          // Third call for second search attempt (should not happen)
          (prompt) => Stream.value('second answer'),
        ],
      );

      container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            AsyncValue.data(RuntimeManager(mockRuntime)),
          ),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(webSearchProvider.notifier);

      // Start first search
      final firstSearch = notifier.runSearch('First query');

      // Try to start second search while first is in progress
      final secondResult = await notifier.runSearch('Second query');

      expect(secondResult, isNull);

      await firstSearch;
    });

    test('sets error state when runtime is not ready', () async {
      mockRuntime = MockLlmRuntime(isReady: false);

      container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            AsyncValue.data(RuntimeManager(mockRuntime)),
          ),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(webSearchProvider.notifier);
      final result = await notifier.runSearch('Test query');

      expect(result, isNull);
      expect(notifier.state.status, SearchAgentStatus.error);
      expect(notifier.state.error, contains('not loaded'));
    });

    test('cancelSearch sets error state', () async {
      mockRuntime = MockLlmRuntime(
        streamBuilders: [
          (prompt) => Stream.fromIterable(['query']),
          (prompt) => Stream.value('answer'),
        ],
      );

      container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            AsyncValue.data(RuntimeManager(mockRuntime)),
          ),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(webSearchProvider.notifier);

      // Start search
      final searchFuture = notifier.runSearch('Test query');

      // Cancel immediately
      notifier.cancelSearch();

      await searchFuture;

      expect(notifier.state.status, SearchAgentStatus.error);
      expect(notifier.state.error, 'Search cancelled.');
    });

    test('reset clears all state', () async {
      mockRuntime = MockLlmRuntime(
        streamBuilders: [
          (prompt) => Stream.fromIterable(['query']),
          (prompt) => Stream.value('answer'),
        ],
      );

      container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            AsyncValue.data(RuntimeManager(mockRuntime)),
          ),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(webSearchProvider.notifier);
      await notifier.runSearch('Test query');

      expect(notifier.state.status, SearchAgentStatus.complete);

      notifier.reset();

      expect(notifier.state.status, SearchAgentStatus.idle);
      expect(notifier.state.answer, isEmpty);
      expect(notifier.state.searchResults, isEmpty);
    });
  });

  group('WebSearchNotifier.runSearchAndReply', () {
    late ProviderContainer container;
    late MockLlmRuntime mockRuntime;
    late FakeChatRepository fakeRepo;

    setUp(() {
      mockRuntime = MockLlmRuntime();
      fakeRepo = FakeChatRepository();
    });

    tearDown(() {
      container.dispose();
    });

    test('creates session and adds messages to chat', () async {
      mockRuntime = MockLlmRuntime(
        streamBuilders: [
          (prompt) => Stream.fromIterable(['weather forecast']),
          (prompt) => Stream.fromIterable(['Sunny', ' today']),
        ],
      );

      container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            AsyncValue.data(RuntimeManager(mockRuntime)),
          ),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(webSearchProvider.notifier);

      await notifier.runSearchAndReply('What is the weather?');

      // Should have created a session
      final chatState = container.read(chatProvider);
      expect(chatState.activeSessionId, isNotNull);

      // Should have added user message and assistant response
      final messages = chatState.messages;
      expect(messages.length, greaterThanOrEqualTo(2));

      // First message should be the user query
      expect(messages.first.role, ChatRole.user);
      expect(messages.first.text, 'What is the weather?');
      expect(messages.first.isWebSearch, isTrue);

      // Last message should be the assistant response
      final lastMsg = messages.last;
      expect(lastMsg.role, ChatRole.assistant);
      expect(lastMsg.text, contains('Sunny'));
    });

    test('handles search cancellation gracefully', () async {
      mockRuntime = MockLlmRuntime(
        streamBuilders: [
          (prompt) => Stream.fromIterable(['query']),
          (prompt) => Stream.value('answer'),
        ],
      );

      container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            AsyncValue.data(RuntimeManager(mockRuntime)),
          ),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(webSearchProvider.notifier);

      // Start search
      final searchFuture = notifier.runSearchAndReply('Test query');

      // Cancel immediately
      notifier.cancelSearch();

      await searchFuture;

      // Should have added cancellation message to chat
      final chatState = container.read(chatProvider);
      final messages = chatState.messages;
      final cancelMsg = messages.firstWhere(
        (m) => m.text.contains('cancelled'),
        orElse: () => ChatMessage(
          id: '',
          sessionId: '',
          text: '',
          role: ChatRole.assistant,
          createdAt: DateTime(2024),
        ),
      );
      expect(cancelMsg.text, contains('cancelled'));
    });

    test('handles search error gracefully', () async {
      mockRuntime = MockLlmRuntime(
        streamBuilders: [
          // Query analysis succeeds
          (prompt) => Stream.fromIterable(['query']),
          // Answer generation fails
          (prompt) => Stream.error(Exception('LLM failed')),
        ],
      );

      container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            AsyncValue.data(RuntimeManager(mockRuntime)),
          ),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final notifier = container.read(webSearchProvider.notifier);
      await notifier.runSearchAndReply('Test query');

      // Should have added error message to chat
      final chatState = container.read(chatProvider);
      final messages = chatState.messages;
      final errorMsg = messages.firstWhere(
        (m) => m.text.contains('failed'),
        orElse: () => ChatMessage(
          id: '',
          sessionId: '',
          text: '',
          role: ChatRole.assistant,
          createdAt: DateTime(2024),
        ),
      );
      expect(errorMsg.text, contains('failed'));
    });

    test('uses existing session if one is active', () async {
      mockRuntime = MockLlmRuntime(
        streamBuilders: [
          (prompt) => Stream.fromIterable(['query']),
          (prompt) => Stream.value('answer'),
        ],
      );

      container = ProviderContainer(
        overrides: [
          runtimeProvider.overrideWithValue(
            AsyncValue.data(RuntimeManager(mockRuntime)),
          ),
          chatRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );

      final chatNotifier = container.read(chatProvider.notifier);

      // Create a session first
      await chatNotifier.newSession(title: 'Existing Session');
      final initialSessionId = container.read(chatProvider).activeSessionId;

      // Run search
      final notifier = container.read(webSearchProvider.notifier);
      await notifier.runSearchAndReply('Test query');

      // Should have used the existing session
      final chatState = container.read(chatProvider);
      expect(chatState.activeSessionId, initialSessionId);
    });
  });

  group('WebSearchState', () {
    test('isIdle returns true for idle status', () {
      const state = WebSearchState();
      expect(state.isIdle, isTrue);
    });

    test('isBusy returns true for active statuses', () {
      expect(
        const WebSearchState(status: SearchAgentStatus.analyzing).isBusy,
        isTrue,
      );
      expect(
        const WebSearchState(status: SearchAgentStatus.searching).isBusy,
        isTrue,
      );
      expect(
        const WebSearchState(status: SearchAgentStatus.fetching).isBusy,
        isTrue,
      );
      expect(
        const WebSearchState(status: SearchAgentStatus.extracting).isBusy,
        isTrue,
      );
      expect(
        const WebSearchState(status: SearchAgentStatus.reranking).isBusy,
        isTrue,
      );
      expect(
        const WebSearchState(status: SearchAgentStatus.generating).isBusy,
        isTrue,
      );
    });

    test('isBusy returns false for terminal statuses', () {
      expect(
        const WebSearchState(status: SearchAgentStatus.idle).isBusy,
        isFalse,
      );
      expect(
        const WebSearchState(status: SearchAgentStatus.complete).isBusy,
        isFalse,
      );
      expect(
        const WebSearchState(status: SearchAgentStatus.error).isBusy,
        isFalse,
      );
    });

    test('copyWith preserves existing values', () {
      const state = WebSearchState(
        enabled: true,
        status: SearchAgentStatus.analyzing,
        statusLabel: 'Analyzing...',
        answer: 'partial answer',
      );

      final updated = state.copyWith(
        status: SearchAgentStatus.searching,
        statusLabel: 'Searching...',
      );

      expect(updated.enabled, isTrue);
      expect(updated.status, SearchAgentStatus.searching);
      expect(updated.statusLabel, 'Searching...');
      expect(updated.answer, 'partial answer');
    });

    test('copyWith clearError removes error', () {
      const state = WebSearchState(
        status: SearchAgentStatus.error,
        error: 'Something went wrong',
      );

      final cleared = state.copyWith(clearError: true);

      expect(cleared.error, isNull);
    });
  });
}
