/// One message, from either `messages` (1:1) or `channel_messages` (group).
///
/// The two tables share every column this model reads; `channel_messages`
/// additionally carries `media_urls`, which is optional here. Modelling them
/// together lets the 1:1 thread and the channel thread share one bubble list
/// (blueprint §16.8).
class ChatMessage {
  final String id;
  final String senderId;
  final String content;

  /// `text`, `property_share`, `image`, … — the schema is open-ended, so this
  /// is kept as a raw string rather than an enum that could reject a value the
  /// backend already stores.
  final String messageType;

  /// Set on `property_share` messages.
  final String? propertyId;

  final List<String> mediaUrls;
  final bool isRead;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.content,
    required this.messageType,
    this.propertyId,
    this.mediaUrls = const [],
    this.isRead = false,
    this.createdAt,
  });

  factory ChatMessage.fromSupabase(Map<String, dynamic> json) {
    final created = json['created_at'] as String?;
    final media = json['media_urls'];

    return ChatMessage(
      id: json['id'].toString(),
      senderId: json['sender_id']?.toString() ?? '',
      content: (json['content'] as String?) ?? '',
      messageType: (json['message_type'] as String?) ?? 'text',
      propertyId: json['property_id']?.toString(),
      mediaUrls: media is List
          ? media.map((e) => e.toString()).toList()
          : const <String>[],
      isRead: (json['is_read'] as bool?) ?? false,
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }

  bool get isPropertyShare => messageType == 'property_share';
  bool get isImage => messageType == 'image';

  /// What to render in a bubble when the type is not plain text.
  ///
  /// `property_share` and `image` are already stored with a human-readable
  /// `content` string by the web app (e.g. "Shared property: <title>"), so the
  /// fallback is only reached for a type that arrives with an empty body —
  /// blueprint §16.7 requires those degrade gracefully rather than rendering
  /// a blank bubble.
  String get displayContent {
    if (content.trim().isNotEmpty) return content;
    if (isPropertyShare) return 'Shared a property';
    if (isImage) return 'Sent an image';
    return 'Unsupported message';
  }
}
