/// Toggleable context features that feed additional information to the model.
///
/// Each feature can be enabled/disabled independently. Disabled features
/// are excluded from the prompt to save context window space and reduce
/// latency.
class ContextSettings {
  /// Whether to include the user profile in the system prompt.
  final bool userProfileEnabled;

  /// Whether to include extracted memory from past conversations.
  final bool conversationMemoryEnabled;

  /// Whether to include indexed documentation as context.
  final bool documentIndexEnabled;

  // ── User Profile Fields ─────────────────────────────────

  final String userName;
  final String userProfession;
  final String userInterests;
  final String userExtraInfo;

  // ── Document Index ──────────────────────────────────────

  /// URLs or text snippets the user has added for context.
  final List<DocumentEntry> documents;

  const ContextSettings({
    this.userProfileEnabled = false,
    this.conversationMemoryEnabled = true,
    this.documentIndexEnabled = false,
    this.userName = '',
    this.userProfession = '',
    this.userInterests = '',
    this.userExtraInfo = '',
    this.documents = const [],
  });

  ContextSettings copyWith({
    bool? userProfileEnabled,
    bool? conversationMemoryEnabled,
    bool? documentIndexEnabled,
    String? userName,
    String? userProfession,
    String? userInterests,
    String? userExtraInfo,
    List<DocumentEntry>? documents,
  }) {
    return ContextSettings(
      userProfileEnabled: userProfileEnabled ?? this.userProfileEnabled,
      conversationMemoryEnabled:
          conversationMemoryEnabled ?? this.conversationMemoryEnabled,
      documentIndexEnabled: documentIndexEnabled ?? this.documentIndexEnabled,
      userName: userName ?? this.userName,
      userProfession: userProfession ?? this.userProfession,
      userInterests: userInterests ?? this.userInterests,
      userExtraInfo: userExtraInfo ?? this.userExtraInfo,
      documents: documents ?? this.documents,
    );
  }

  /// Build the user profile section for the system prompt.
  String buildUserProfilePrompt() {
    if (!userProfileEnabled) return '';
    final parts = <String>[];
    if (userName.isNotEmpty) parts.add('Name: $userName');
    if (userProfession.isNotEmpty) {
      parts.add('Profession: $userProfession');
    }
    if (userInterests.isNotEmpty) {
      parts.add('Interests: $userInterests');
    }
    if (userExtraInfo.isNotEmpty) parts.add(userExtraInfo);
    if (parts.isEmpty) return '';
    return 'About the user:\n${parts.join('\n')}';
  }

  /// Build the document context section for the system prompt.
  String buildDocumentContext() {
    if (!documentIndexEnabled || documents.isEmpty) return '';
    final buf = StringBuffer('Reference documents:\n');
    for (final doc in documents) {
      buf.write('\n--- ${doc.title} ---\n');
      buf.write(doc.content);
      buf.write('\n');
    }
    return buf.toString();
  }
}

/// A single document or URL snippet used as context.
class DocumentEntry {
  final String id;
  final String title;
  final String content;
  final String? url;
  final DateTime createdAt;

  const DocumentEntry({
    required this.id,
    required this.title,
    required this.content,
    this.url,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'url': url,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory DocumentEntry.fromJson(Map<String, dynamic> json) {
    return DocumentEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      url: json['url'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    );
  }
}
