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

  // ── User Profile Fields ─────────────────────────────────

  final String userName;
  final String userProfession;
  final String userInterests;
  final String userExtraInfo;

  const ContextSettings({
    this.userProfileEnabled = false,
    this.conversationMemoryEnabled = true,
    this.userName = '',
    this.userProfession = '',
    this.userInterests = '',
    this.userExtraInfo = '',
  });

  ContextSettings copyWith({
    bool? userProfileEnabled,
    bool? conversationMemoryEnabled,
    String? userName,
    String? userProfession,
    String? userInterests,
    String? userExtraInfo,
  }) {
    return ContextSettings(
      userProfileEnabled: userProfileEnabled ?? this.userProfileEnabled,
      conversationMemoryEnabled:
          conversationMemoryEnabled ?? this.conversationMemoryEnabled,
      userName: userName ?? this.userName,
      userProfession: userProfession ?? this.userProfession,
      userInterests: userInterests ?? this.userInterests,
      userExtraInfo: userExtraInfo ?? this.userExtraInfo,
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
}
