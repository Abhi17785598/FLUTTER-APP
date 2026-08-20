import 'package:supabase_flutter/supabase_flutter.dart';

class ReelsService {
  final _supabase = Supabase.instance.client;

  /// Fetches active, approved reels ordered newest-first, and merges in the
  /// two things `influencer_videos` itself does NOT store:
  ///
  ///   1. Builder/uploader identity — comes from `profiles` (keyed by
  ///      `user_id`), fetched as a separate query and merged client-side.
  ///      This mirrors the website's own `InfluencerVideoFeed.tsx`, which
  ///      does the exact same two-query merge (there's no FK from
  ///      `influencer_videos` to `profiles` for Postgrest to embed).
  ///
  ///   2. Linked property specs (price/location/beds/baths/parking/area/
  ///      amenities) — only present when a reel has a non-null
  ///      `property_id`. Fetched from `properties` (+ its
  ///      `properties_residential` / `properties_commercial` subtype rows,
  ///      the same embed already used by [PropertyService.getProperties]),
  ///      filtered to just the ids this batch of reels actually needs.
  ///
  /// Reels with no linked property, or whose uploader has a thin profile,
  /// simply get `null` for those nested keys — [ReelModel.fromSupabase]
  /// handles that gracefully.
  Future<List<Map<String, dynamic>>> getReels() async {
    final videos = await _supabase
        .from('influencer_videos')
        .select('*')
        .eq('status', 'active')
        .eq('approval_status', 'approved')
        .order('created_at', ascending: false);

    final videoRows = List<Map<String, dynamic>>.from(videos);
    if (videoRows.isEmpty) return videoRows;

    // ── Builder identity (profiles, keyed by user_id) ──────────────────
    final userIds = videoRows
        .map((v) => v['user_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> profilesByUserId = {};
    if (userIds.isNotEmpty) {
      final profiles = await _supabase
          .from('profiles')
          .select(
            'user_id,display_name,avatar_url,phone,verification_status,user_type,company_name,company_logo_url,comments_enabled',
          )
          .inFilter('user_id', userIds);

      for (final p in List<Map<String, dynamic>>.from(profiles)) {
        profilesByUserId[p['user_id'] as String] = p;
      }
    }

    // ── Linked property specs (properties + residential/commercial) ────
    final propertyIds = videoRows
        .map((v) => v['property_id'])
        .whereType<String>()
        .toSet()
        .toList();

    final Map<String, Map<String, dynamic>> propertiesById = {};
    if (propertyIds.isNotEmpty) {
      final properties = await _supabase
          .from('properties')
          .select('*,properties_residential(*),properties_commercial(*)')
          .inFilter('id', propertyIds);

      for (final p in List<Map<String, dynamic>>.from(properties)) {
        propertiesById[p['id'] as String] = p;
      }
    }

    // Merge onto each video row under underscore-prefixed keys so they can
    // never collide with a real `influencer_videos` column name.
    for (final v in videoRows) {
      final userId = v['user_id'] as String?;
      final propertyId = v['property_id'] as String?;
      if (userId != null) v['_profile'] = profilesByUserId[userId];
      if (propertyId != null) v['_property'] = propertiesById[propertyId];
    }

    return videoRows;
  }
}
