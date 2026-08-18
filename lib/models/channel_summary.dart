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

  /// The signed-in user's own `channel_participants.muted_at`.
  final bool isMuted;

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
    this.isMuted = false,
  });

  factory ChannelSummary.fromSupabase(
    Map<String, dynamic> json, {
    String? myRole,
    int participantCount = 0,
    DateTime? lastMessageAt,
    int unreadCount = 0,
    bool isMuted = false,
  }) {
    final id = json['id']?.toString();
    if (id == null) {
      throw ArgumentError('ChannelSummary.fromSupabase: row has no id');
    }
    return ChannelSummary(
      id: id,
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
      isMuted: isMuted,
    );
  }

  bool get isAdmin => myRole?.toLowerCase() == 'admin';
  bool get isModerator => myRole?.toLowerCase() == 'moderator';
  bool get canModerate => isAdmin || isModerator;

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
