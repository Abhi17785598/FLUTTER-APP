import 'amenity_model.dart';
import 'property_model.dart';

/// Reel model backed by the `influencer_videos` Supabase table.
///
/// ── What's real vs. derived ──────────────────────────────────────────────
/// Columns that actually exist on `influencer_videos` (see
/// `src/integrations/supabase/types.ts` in the website repo, which is the
/// generated source of truth for the schema):
///   id, user_id, title, description, video_url, thumbnail_url, video_type,
///   views, likes, hashtags, status, approval_status, property_id,
///   created_at, updated_at.
///
/// Everything else the premium reels UI shows (builder name/avatar/phone/
/// verified, price, location, beds/baths/parking, area, possession status,
/// featured flag, amenities) is **not** a column on this table. It's
/// resolved the same way the website's own `InfluencerVideoFeed.tsx` does
/// it: builder identity comes from a separate `profiles` lookup keyed by
/// `user_id`, and — when a reel has a non-null `property_id` — property
/// specs come from `properties` (+ its `properties_residential` /
/// `properties_commercial` subtype rows, the same shape
/// [PropertyModel.fromSupabase] already parses).
///
/// [ReelsService.getReels] does both lookups and merges the results onto
/// each video row under `_profile` / `_property` before this factory ever
/// sees it, so this file stays a pure "shape the JSON" concern.
class ReelModel {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final String videoType;
  final int views;
  final int likes;

  /// Real column — free-form hashtags the uploader attached to the reel
  /// (e.g. "#luxury", "#readytomove"). Shown as-is; not property amenities.
  final List<String> hashtags;

  // ── Builder identity — resolved from a joined `profiles` row ─────────
  final String? builderName;
  final String? builderAvatarUrl;
  final String? builderPhone;
  final bool isVerified;

  // ── Linked property (only present when property_id is set) ──────────
  final String? propertyId;
  final String? price;
  final String? location;
  final int? beds;
  final int? baths;
  final int? parking;
  final int? sqft;
  final String? possessionStatus;
  final bool isFeatured;
  final List<AmenityModel> amenities;

  /// No comment feature exists for reels anywhere in the product today
  /// (no `influencer_video_comments` table, no comment UI wired on the
  /// website's reel view beyond a decorative icon) — kept at 0 rather than
  /// removed so the action row doesn't need touching if that ever ships.
  final int commentCount;

  const ReelModel({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    this.thumbnailUrl = '',
    this.videoType = 'property_listing',
    this.views = 0,
    this.likes = 0,
    this.hashtags = const [],
    this.builderName,
    this.builderAvatarUrl,
    this.builderPhone,
    this.isVerified = false,
    this.propertyId,
    this.price,
    this.location,
    this.beds,
    this.baths,
    this.parking,
    this.sqft,
    this.possessionStatus,
    this.isFeatured = false,
    this.amenities = const [],
    this.commentCount = 0,
  });

  factory ReelModel.fromSupabase(Map<String, dynamic> json) {
    final Map<String, dynamic>? profile =
        json['_profile'] as Map<String, dynamic>?;
    final Map<String, dynamic>? property =
        json['_property'] as Map<String, dynamic>?;
    final Map<String, dynamic>? residential =
        property?['properties_residential'] as Map<String, dynamic>?;
    final Map<String, dynamic>? commercial =
        property?['properties_commercial'] as Map<String, dynamic>?;
    final Map<String, dynamic> metadata =
        (property?['metadata'] as Map<String, dynamic>?) ?? const {};

    int? beds;
    int? baths;
    int? parking;
    if (residential != null) {
      beds = (residential['bedrooms'] as num?)?.toInt();
      baths = (residential['bathrooms'] as num?)?.toInt();
      parking = (residential['parking_spaces'] as num?)?.toInt();
    } else if (commercial != null) {
      baths = (commercial['washrooms'] as num?)?.toInt();
      parking = (commercial['parking_spaces'] as num?)?.toInt();
    }

    // Same heuristic PropertyModel.fromSupabase uses — there's no dedicated
    // `is_featured` column on `properties` either.
    final int propertyViews = (property?['views'] as num?)?.toInt() ?? 0;

    return ReelModel(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      videoUrl: json['video_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      videoType: json['video_type'] ?? 'property_listing',
      views: (json['views'] as num?)?.toInt() ?? 0,
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      hashtags: (json['hashtags'] as List<dynamic>?)?.cast<String>() ?? const [],
      builderName: _str(profile?['display_name']) ?? _str(profile?['company_name']),
      builderAvatarUrl:
          _str(profile?['avatar_url']) ?? _str(profile?['company_logo_url']),
      builderPhone: _str(profile?['phone']),
      isVerified: profile?['verification_status'] == 'verified',
      propertyId: _str(json['property_id']),
      price: _str(property?['price']),
      location: _str(property?['location']),
      beds: beds,
      baths: baths,
      parking: parking,
      sqft: int.tryParse(property?['area']?.toString() ?? ''),
      possessionStatus: _str(metadata['propertyCondition']),
      isFeatured: propertyViews >= 1,
      amenities: PropertyModel.parseAmenities(property?['amenities']),
      commentCount: 0,
    );
  }

  bool get hasPrice => price != null && price!.trim().isNotEmpty;
  bool get hasLocation => location != null && location!.trim().isNotEmpty;
  bool get hasBuilder =>
      builderName != null && builderName!.trim().isNotEmpty;
  bool get hasPossessionStatus =>
      possessionStatus != null && possessionStatus!.trim().isNotEmpty;
  bool get hasSpecs =>
      beds != null || baths != null || parking != null || sqft != null;

  // ── Compatibility aliases for reel_property_card.dart ────────────────
  // That widget was written against an earlier draft of this model that
  // used different names for the same data (status/areaLabel/bedrooms/
  // etc.). Rather than rename the real fields above (which would ripple
  // into reel_action_row.dart, reels_screen.dart, and the service/provider
  // wiring), these getters just expose the same values under the names
  // the widget already expects. Purely additive — nothing above changed.

  /// Alias for [possessionStatus].
  String? get status => possessionStatus;

  /// Alias for [hasPossessionStatus].
  bool get hasStatus => hasPossessionStatus;

  /// Alias for [beds].
  int? get bedrooms => beds;

  /// Alias for [baths].
  int? get bathrooms => baths;

  /// Alias for [parking].
  int? get parkingSpots => parking;

  /// Alias for [sqft], as a string (the widget renders it directly as text).
  String? get areaLabel => sqft?.toString();

  /// Unit label to pair with [areaLabel]. No per-reel unit is stored
  /// anywhere in the schema, so this is a fixed display default.
  String get areaUnit => 'Sq.ft';

  /// Property highlights as plain labels for the card's highlight chips —
  /// derived from [amenities] (already parsed from the real `properties`
  /// data via [PropertyModel.parseAmenities]), not a separate data source.
  List<String> get highlights => amenities.map((a) => a.name).toList();

  /// Best-effort share message built from whatever property data exists.
  /// Falls back to the title + a generic call-to-action when metadata is thin.
  String get shareMessage {
    final buffer = StringBuffer();
    buffer.writeln('🏡 ${title.isNotEmpty ? title : 'Check out this property'}');

    if (hasPrice) buffer.writeln('💰 $price');
    if (hasLocation) buffer.writeln('📍 $location');
    if (hasBuilder) buffer.writeln('🏢 by $builderName');

    if (description.trim().isNotEmpty) {
      buffer.writeln();
      buffer.writeln(description.trim());
    }

    buffer.writeln();
    buffer.writeln('Discover more premium properties on PropCID.');

    return buffer.toString().trim();
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}