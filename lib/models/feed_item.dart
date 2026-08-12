// models/feed_item.dart
//
// One entry in the "Feed" screen — a client-side merge of `properties`,
// `builder_projects` and `influencer_videos`, mirroring the portal's
// `CombinedFeed.tsx` (propcid/src/features/content/CombinedFeed.tsx). The
// portal has no single `posts` table; neither does this model invent one —
// it just carries whichever of the three rows produced it, plus the poster's
// profile fields needed to render a card and to run the role filter below.

import '../models/property_model.dart' show PropertyModel;

enum FeedItemType { property, project, video }

/// The four filter chips the Feed screen shows, in the portal's own order
/// and copy (`CombinedFeed.tsx`'s `filters` array — "All", "Brokers",
/// "Builders", "Influencers"). The portal also has a fifth, broker/admin-only
/// "Exclusive" tab backed by `builder_project_offers`; that tab is out of
/// scope for this fix (a separate, considerably larger data source) and is
/// deliberately not reproduced here.
enum FeedRoleFilter {
  all('All'),
  broker('Brokers'),
  builder('Builders'),
  influencer('Influencers');

  const FeedRoleFilter(this.label);

  final String label;
}

class FeedItem {
  final FeedItemType type;
  final String id;
  final DateTime? createdAt;
  final String title;
  final String subtitle;
  final String? imageUrl;
  final String? videoUrl;
  final int views;
  final int likes;

  final String? posterUserId;
  final String posterName;
  final String? posterAvatarUrl;

  /// `profiles.user_type` of the poster — drives both the role pill and the
  /// filter predicate below.
  final String? posterUserType;

  const FeedItem({
    required this.type,
    required this.id,
    required this.createdAt,
    required this.title,
    required this.subtitle,
    required this.views,
    required this.likes,
    required this.posterName,
    this.imageUrl,
    this.videoUrl,
    this.posterUserId,
    this.posterAvatarUrl,
    this.posterUserType,
  });

  /// Mirrors `CombinedFeed.tsx`'s per-filter predicate exactly (including its
  /// quirks — "Brokers" also matches `individual`, and "Builders" excludes
  /// the viewer's own posts), so a filter changes the *data*, not just the
  /// chip's selected style.
  bool matchesFilter(FeedRoleFilter filter, String? currentUserId) {
    switch (filter) {
      case FeedRoleFilter.all:
        return true;
      case FeedRoleFilter.broker:
        return posterUserType == 'broker' ||
            posterUserType == 'professional_broker' ||
            posterUserType == 'individual';
      case FeedRoleFilter.builder:
        return posterUserType == 'builder' &&
            (type == FeedItemType.project || type == FeedItemType.property) &&
            posterUserId != currentUserId;
      case FeedRoleFilter.influencer:
        return type == FeedItemType.video || posterUserType == 'influencer';
    }
  }

  factory FeedItem.fromProperty(
    Map<String, dynamic> json,
    Map<String, dynamic>? profile,
  ) {
    final images = List<String>.from(json['media_urls'] as List? ?? const []);
    return FeedItem(
      type: FeedItemType.property,
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      subtitle: PropertyModel.formatIndianPrice(json['price']),
      imageUrl: images.isNotEmpty ? images.first : null,
      views: _int(json['views']),
      likes: _int(json['likes']),
      posterUserId: json['user_id']?.toString(),
      posterName: profile?['display_name']?.toString() ?? 'User',
      posterAvatarUrl: profile?['avatar_url']?.toString(),
      posterUserType: profile?['user_type']?.toString(),
    );
  }

  factory FeedItem.fromProject(
    Map<String, dynamic> json,
    Map<String, dynamic>? profile,
  ) {
    final images = List<String>.from(json['media_urls'] as List? ?? const []);
    return FeedItem(
      type: FeedItemType.project,
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      subtitle: json['location']?.toString() ?? '',
      imageUrl: images.isNotEmpty ? images.first : null,
      views: _int(json['views']),
      likes: _int(json['likes']),
      posterUserId: json['builder_id']?.toString(),
      posterName: profile?['display_name']?.toString() ?? 'User',
      posterAvatarUrl: profile?['avatar_url']?.toString(),
      posterUserType: profile?['user_type']?.toString(),
    );
  }

  factory FeedItem.fromVideo(
    Map<String, dynamic> json,
    Map<String, dynamic>? profile,
  ) {
    return FeedItem(
      type: FeedItemType.video,
      id: json['id']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      title: json['title']?.toString() ?? '',
      subtitle: 'Video',
      imageUrl: json['thumbnail_url']?.toString(),
      videoUrl: json['video_url']?.toString(),
      views: _int(json['views']),
      likes: _int(json['likes']),
      posterUserId: json['user_id']?.toString(),
      posterName: profile?['display_name']?.toString() ?? 'User',
      posterAvatarUrl: profile?['avatar_url']?.toString(),
      posterUserType: profile?['user_type']?.toString(),
    );
  }

  static int _int(Object? value) => switch (value) {
        final int v => v,
        final num v => v.toInt(),
        final String v => int.tryParse(v) ?? 0,
        _ => 0,
      };
}
