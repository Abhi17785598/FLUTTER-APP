// services/influencer_video_service.dart
//
// Read and write access to `influencer_videos` for the influencer content flow.
//
// WHY A COMPANION SERVICE RATHER THAN NEW METHODS ON InfluencerCampaignService
// ---------------------------------------------------------------------------
// `InfluencerCampaignService.getVideos` returns `InfluencerCampaignModel`, which
// carries 8 of the table's 16 columns and cannot round-trip a row (no
// `video_type`, which is NOT NULL and CHECK-constrained). Appending writes there
// would mean either widening that model — changing what the dashboard's existing
// "Recent Videos" strip receives — or having one service speak two models. It also
// swallows every error and returns `[]`, which is defensible for a decorative strip
// and wrong for an editor, where "no videos" and "the fetch failed" must not look
// alike.
//
// So: new file, new model, and `InfluencerCampaignService` /
// `InfluencerCampaignModel` / `InfluencerRecentCampaignsWidget` are untouched.
//
// DELETE IS SOFT, WHICH IS A CHOICE BETWEEN TWO PORTAL BEHAVIOURS
// --------------------------------------------------------------
// The portal deletes videos two different ways:
//
//   SellerWall.tsx:302                  softDeleteContent('influencer_videos', id)
//   InfluencerContentManager.tsx:76-80  .from('influencer_videos').delete()
//
// The second was never migrated. `src/lib/softDelete.ts` explains why the first
// exists: a hard delete runs the table's ON DELETE CASCADE immediately, and gives
// no undo. The `soft_delete_content` RPC it calls is live — it is in
// `supabase/migrations/`, not the unapplied `migration2/` set — is SECURITY
// INVOKER, so the existing RLS UPDATE policy still decides who may touch the row,
// and is granted to `authenticated`
// (20270318040000_soft_delete_content.sql:73-116). A RESTRICTIVE SELECT policy
// hides soft-deleted rows from every client read, and `purge_soft_deleted()`
// hard-deletes them after 30 days, which is when the cascades finally run.
//
// This service follows SellerWall. Copying the un-migrated path would mean
// deliberately choosing the version the portal's own comments describe as the bug.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/influencer_video_options.dart';
import '../models/influencer_video_model.dart';

/// Raised when a write is refused before it is attempted.
class InfluencerVideoException implements Exception {
  const InfluencerVideoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The form's contents, ready to become a payload.
///
/// Mirrors `InfluencerVideoModal`'s `formData` plus the two resolved media URLs.
class InfluencerVideoDraft {
  const InfluencerVideoDraft({
    required this.title,
    required this.videoType,
    required this.videoUrl,
    this.description = '',
    this.thumbnailUrl,
    this.hashtags = const [],
  });

  final String title;
  final String description;
  final String videoType;
  final String videoUrl;
  final String? thumbnailUrl;
  final List<String> hashtags;

  /// The columns both the insert and the update write.
  ///
  /// `approval_status: 'pending'` is on **both** paths, exactly as the portal has
  /// it (InfluencerVideoModal.tsx:170 and :189) — editing a video re-queues it for
  /// review. `status` is written by neither, so the column default (`active`) holds
  /// on create and the stored value survives an edit. `property_id` is likewise
  /// absent: the portal's modal never sets it, and writing null would erase a link
  /// some other flow established.
  Map<String, dynamic> toPayload() => <String, dynamic>{
    'title': title,
    'description': description,
    'video_url': videoUrl,
    'thumbnail_url': thumbnailUrl,
    'video_type': videoType,
    'hashtags': hashtags,
    'approval_status': 'pending',
  };
}

class InfluencerVideoService {
  InfluencerVideoService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const String table = 'influencer_videos';

  /// This influencer's videos, newest first.
  ///
  /// The portal's fetch, filter for filter: `.eq('user_id', user.id)
  /// .order('created_at', { ascending: false })`
  /// (InfluencerContentManager.tsx:55-59). No `deleted_at` predicate is needed —
  /// the RESTRICTIVE policy from 20270318040000 already hides those rows from every
  /// client read.
  ///
  /// Errors propagate, unlike `InfluencerCampaignService.getVideos`: the content
  /// library has to tell "you have no videos" apart from "the fetch failed".
  Future<List<InfluencerVideoModel>> listMine(String userId) async {
    final rows = await _supabase
        .from(table)
        .select(InfluencerVideoModel.columns)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(
      rows,
    ).map(InfluencerVideoModel.fromSupabase).toList();
  }

  /// One video by id, or null when it is not visible to the caller.
  Future<InfluencerVideoModel?> fetchById(String videoId) async {
    final row = await _supabase
        .from(table)
        .select(InfluencerVideoModel.columns)
        .eq('id', videoId)
        .maybeSingle();

    if (row == null) return null;
    return InfluencerVideoModel.fromSupabase(row);
  }

  /// Inserts a video and returns its id.
  ///
  /// `user_id` is set from [userId] — the only column the insert carries that the
  /// update does not (InfluencerVideoModal.tsx:183).
  Future<String> create(InfluencerVideoDraft draft, String userId) async {
    _validate(draft);

    final result = await _supabase
        .from(table)
        .insert(<String, dynamic>{'user_id': userId, ...draft.toPayload()})
        .select('id')
        .single();

    return result['id'].toString();
  }

  /// Updates an existing video, re-queueing it for review.
  Future<void> update(String videoId, InfluencerVideoDraft draft) async {
    _validate(draft);

    await _supabase.from(table).update(draft.toPayload()).eq('id', videoId);
  }

  /// Retires a video via `soft_delete_content`.
  ///
  /// Returns true when a row was retired, false when it was already soft-deleted or
  /// RLS matched nothing — the same contract as the portal's `softDeleteContent`,
  /// which distinguishes the two so an RLS denial cannot read as success.
  Future<bool> softDelete(String videoId) async {
    final result = await _supabase.rpc(
      'soft_delete_content',
      params: <String, dynamic>{'p_table': table, 'p_id': videoId},
    );
    return result == true;
  }

  /// Undoes a soft delete. Unused by the current UI; present because
  /// `restore_content` is granted to `authenticated` and a delete this service can
  /// perform should be one it can also reverse.
  @visibleForTesting
  Future<bool> restore(String videoId) async {
    final result = await _supabase.rpc(
      'restore_content',
      params: <String, dynamic>{'p_table': table, 'p_id': videoId},
    );
    return result == true;
  }

  /// Refuses a payload the database would reject anyway.
  ///
  /// The three NOT NULL columns and the one CHECK constraint, in that order. The
  /// portal validates title and video_type in the modal
  /// (InfluencerVideoModal.tsx:115-118) and relies on the upload having produced a
  /// URL; this repeats those checks at the service boundary so a caller cannot
  /// bypass the form and get a `23502` or `23514` instead of a sentence.
  void _validate(InfluencerVideoDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw const InfluencerVideoException('A title is required.');
    }
    if (draft.videoUrl.trim().isEmpty) {
      throw const InfluencerVideoException('A video is required.');
    }
    if (!isValidInfluencerVideoType(draft.videoType)) {
      throw const InfluencerVideoException('Choose a video type.');
    }
  }
}
