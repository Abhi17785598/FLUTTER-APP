/// One row in the Messages → Channels list.
///
/// Mirrors what features/messaging/ChannelsList.tsx assembles: the channel
/// row, the caller's own participant role, the participant count and the
/// timestamp of the most recent message.
class ChannelSummary {
  final String id;
  final String name;
  final String? description;
  final String? createdBy;
  final int? maxParticipants;

  /// The signed-in user's role in this channel (`admin`, `moderator`,
  /// `member`, …) from `channel_participants.role`.
  final String? myRole;

  final int participantCount;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ChannelSummary({
    required this.id,
    required this.name,
    this.description,
    this.createdBy,
    this.maxParticipants,
    this.myRole,
    this.participantCount = 0,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory ChannelSummary.fromSupabase(
    Map<String, dynamic> json, {
    String? myRole,
    int participantCount = 0,
    DateTime? lastMessageAt,
    int unreadCount = 0,
  }) {
    return ChannelSummary(
      id: json['id'].toString(),
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name'] as String
          : 'Untitled channel',
      description: json['description'] as String?,
      createdBy: json['created_by']?.toString(),
      maxParticipants: (json['max_participants'] as num?)?.toInt(),
      myRole: myRole,
      participantCount: participantCount,
      lastMessageAt: lastMessageAt,
      unreadCount: unreadCount,
    );
  }

  bool get isAdmin => myRole?.toLowerCase() == 'admin';

  /// Two-letter avatar fallback from the channel name.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '#';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}
