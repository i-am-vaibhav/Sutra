import 'package:sutra/runtime/search/search_agent.dart';
import 'package:sutra/runtime/search/search_result.dart';

enum ChatRole { user, assistant }

class ChatMessage {
  final String id;
  final String sessionId;
  final String text;
  final ChatRole role;
  final DateTime createdAt;
  final String? quotedText;
  final List<Citation>? citations;

  /// Search results attached to a search-status message.
  final List<SearchResult>? searchResults;

  /// Current search agent status (used for search-status messages).
  final SearchAgentStatus? searchStatus;

  /// Whether this message was sent via web search.
  final bool isWebSearch;

  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.role,
    required this.createdAt,
    this.quotedText,
    this.citations,
    this.searchResults,
    this.searchStatus,
    this.isWebSearch = false,
  });

  /// Whether this message is a search-status card.
  bool get isSearchStatus => searchStatus != null;
}
