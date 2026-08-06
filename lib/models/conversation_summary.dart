/// The other person in a 1:1 conversation.
///
/// Resolved from the `profiles_public` view, which is what
/// features/messaging/ChatModal.tsx reads — not the `profiles` table.
class ConversationParticipant {
  final String userId;
  final String displayName;
  final String? avatarUrl;

  const ConversationParticipant({
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  /// Single-letter avatar fallback, matching how the rest of the app derives
  /// initials.
  String get initial =>
      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
}

/// One row in the Messages → Chats list.
class ConversationSummary {
  final String id;
  final DateTime? lastMessageAt;

  /// Null when the other participant's profile could not be resolved — React
  /// leaves `other_participant` undefined in that case rather than inventing
  /// a name.
  final ConversationParticipant? otherParticipant;

  /// Body of the most recent message, or empty when the conversation has none.
  final String lastMessage;

  final int unreadCount;

  const ConversationSummary({
    required this.id,
    this.lastMessageAt,
    this.otherParticipant,
    this.lastMessage = '',
    this.unreadCount = 0,
  });

  String get title => otherParticipant?.displayName ?? 'Unknown';

  ConversationSummary copyWith({int? unreadCount}) {
    return ConversationSummary(
      id: id,
      lastMessageAt: lastMessageAt,
      otherParticipant: otherParticipant,
      lastMessage: lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}
