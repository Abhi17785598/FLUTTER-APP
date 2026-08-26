import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/channel_summary.dart';
import '../models/chat_message.dart';
import '../models/conversation_summary.dart';
import '../models/message_reaction.dart';
import '../models/shared_property_preview.dart';
import 'messaging_exceptions.dart';

/// Direct (1:1) and channel messaging.
///
/// Every query below mirrors its counterpart in the React portal — see
/// blueprint §9. Two behaviours are deliberately *not* implemented client-side
/// because the database already owns them:
///
///  * `trigger_notify_new_message` / `notify_channel_message_trigger` create
///    the recipient's notification. ChatModal.tsx calls this out explicitly:
///    inserting a notification here as well would deliver it twice.
///  * `update_conversation_last_message_trigger` maintains
///    `conversations.last_message_at`. Sending a message must not write it.
class MessagingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Conversations (1:1) ───────────────────────────────────────────────────

  /// The signed-in user's conversations, newest activity first.
  ///
  /// Mirrors `fetchConversations` in features/messaging/ChatModal.tsx. The
  /// `conversations` select carries no user filter there either — RLS scopes
  /// the rows to the caller's own conversations.
  ///
  /// React resolves participants, profiles and last messages with a
  /// per-conversation loop (three round-trips each). This batches those into
  /// one query apiece via `.inFilter`, producing identical results without an
  /// N+1 — the same "resolve in one extra round-trip" pattern
  /// hooks/useProfileViews.ts already uses for its viewer profiles.
  Future<List<ConversationSummary>> listConversations(String userId) async {
    try {
      final convRows = await _supabase
          .from('conversations')
          .select('id, last_message_at, collaboration_id')
          .order('last_message_at', ascending: false);

      final conversations = List<Map<String, dynamic>>.from(convRows as List);
      if (conversations.isEmpty) return const [];

      final ids = conversations
          .map((c) => c['id']?.toString())
          .whereType<String>()
          .toList();

      final participantRows = await _supabase
          .from('conversation_participants')
          .select('conversation_id, user_id, request_status, muted_at')
          .inFilter('conversation_id', ids);

      // conversation_id -> the *other* participant's user id, and the
      // caller's own request_status/mute state for that conversation. A row
      // with a null conversation_id/user_id is skipped rather than
      // `.toString()`'d into the literal `"null"`, which would otherwise
      // silently pollute the batched profile lookup below with a bogus id.
      final otherIdByConversation = <String, String>{};
      final selfStatusByConversation =
          <String, ({String requestStatus, bool isMuted})>{};
      for (final row in List<Map<String, dynamic>>.from(
        participantRows as List,
      )) {
        final convId = row['conversation_id']?.toString();
        final memberId = row['user_id']?.toString();
        if (convId == null || memberId == null) {
          debugPrint(
            'MessagingService.listConversations: skipping participant row '
            'with null id(s): $row',
          );
          continue;
        }
        if (memberId == userId) {
          selfStatusByConversation[convId] = (
            requestStatus: (row['request_status'] as String?) ?? 'accepted',
            isMuted: row['muted_at'] != null,
          );
        } else {
          otherIdByConversation[convId] = memberId;
        }
      }

      final profilesById = await _fetchPublicProfiles(
        otherIdByConversation.values.toSet(),
      );

      // Batched "last non-deleted-for-me message per conversation" — reuses
      // the portal's own perf RPC instead of scanning every message row for
      // every conversation.
      final lastMessageByConversation = <String, String>{};
      try {
        final previewRows = await _supabase.rpc(
          'get_conversation_message_previews',
          params: {'p_conversation_ids': ids, 'p_user_id': userId},
        );
        for (final row in List<Map<String, dynamic>>.from(
          previewRows as List,
        )) {
          final convId = row['conversation_id']?.toString();
          if (convId == null) continue;
          final deletedAt = row['deleted_at'];
          lastMessageByConversation[convId] = deletedAt != null
              ? 'This message was deleted'
              : (row['content'] as String?) ?? '';
        }
      } catch (e) {
        debugPrint(
          'MessagingService.listConversations: message previews '
          'unavailable: $e',
        );
      }

      Map<String, int> unread;
      try {
        unread = await unreadCountsByConversation(userId);
      } catch (e) {
        // A failed unread-count lookup must not be indistinguishable from
        // "genuinely zero unread" — fall back to showing no badges rather
        // than silently lying about them, but don't fail the whole list.
        debugPrint(
          'MessagingService.listConversations: unread counts unavailable: $e',
        );
        unread = const {};
      }

      return conversations.where((c) => c['id'] != null).map((conv) {
        final id = conv['id'].toString();
        final otherId = otherIdByConversation[id];
        final createdRaw = conv['last_message_at'] as String?;
        final selfStatus = selfStatusByConversation[id];

        return ConversationSummary(
          id: id,
          lastMessageAt: createdRaw == null
              ? null
              : DateTime.tryParse(createdRaw),
          otherParticipant: otherId == null ? null : profilesById[otherId],
          lastMessage: lastMessageByConversation[id] ?? '',
          unreadCount: unread[id] ?? 0,
          requestStatus: selfStatus?.requestStatus ?? 'accepted',
          isMuted: selfStatus?.isMuted ?? false,
          collaborationId: conv['collaboration_id']?.toString(),
        );
      }).toList();
    } catch (e) {
      debugPrint('MessagingService.listConversations failed: $e');
      rethrow;
    }
  }

  /// Resolves display names and avatars from the `profiles_public` view —
  /// the same view ChatModal.tsx reads, not the `profiles` table.
  Future<Map<String, ConversationParticipant>> _fetchPublicProfiles(
    Set<String> userIds,
  ) async {
    if (userIds.isEmpty) return const {};

    final rows = await _supabase
        .from('profiles_public')
        .select('user_id, display_name, avatar_url, is_online, last_seen_at')
        .inFilter('user_id', userIds.toList());

    final result = <String, ConversationParticipant>{};
    for (final row in List<Map<String, dynamic>>.from(rows as List)) {
      final id = row['user_id']?.toString();
      if (id == null) continue;
      final lastSeenRaw = row['last_seen_at'] as String?;
      result[id] = ConversationParticipant(
        userId: id,
        displayName: (row['display_name'] as String?) ?? 'Unknown',
        avatarUrl: row['avatar_url'] as String?,
        isOnline: (row['is_online'] as bool?) ?? false,
        lastSeenAt: lastSeenRaw == null ? null : DateTime.tryParse(lastSeenRaw),
      );
    }
    return result;
  }

  /// Columns shared by every `messages`/`channel_messages` select — kept in
  /// one place so a new column (e.g. a future `forwarded_from_id`) only needs
  /// updating here.
  static const String _messageColumns =
      'id, content, sender_id, message_type, property_id, media_urls, '
      'media_status, created_at, is_read, reply_to_id, edited_at, '
      'deleted_at, deleted_for';

  /// `messages` only — `channel_messages` has no `collab_asset_id` column
  /// (the collaboration marketplace is 1:1-only), so this must never be used
  /// for a channel select.
  static const String _dmMessageColumns = '$_messageColumns, collab_asset_id';

  /// Searches an entire thread's history server-side — not just what's
  /// currently paged into memory. Mobile paginates (50/page) while the
  /// portal loads a thread's full history and filters it client-side; a
  /// client-side-only search here would silently miss anything not yet
  /// scrolled into view, so this queries the same table/RLS directly instead
  /// (just a different `WHERE`, no new backend contract).
  Future<List<ChatMessage>> searchMessagesInThread({
    required String threadId,
    required bool isChannel,
    required String term,
  }) async {
    final query = term.trim();
    if (query.isEmpty) return const [];

    try {
      final table = isChannel ? 'channel_messages' : 'messages';
      final column = isChannel ? 'channel_id' : 'conversation_id';

      final rows = await _supabase
          .from(table)
          .select(isChannel ? _messageColumns : _dmMessageColumns)
          .eq(column, threadId)
          .ilike('content', '%$query%')
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(
        rows as List,
      ).map(ChatMessage.fromSupabase).toList();
    } catch (e) {
      debugPrint('MessagingService.searchMessagesInThread failed: $e');
      rethrow;
    }
  }

  /// Most recent page of a conversation, newest-first on the wire (reversed
  /// to oldest-first for display). Mirrors `fetchMessages` in ChatModal.tsx,
  /// with pagination added on top — see [messagePageSize].
  ///
  /// Pass [before] (an already-loaded message's `createdAt`) to load the page
  /// immediately older than it, for "load more" on scroll-to-top. Pass
  /// [after] instead to load everything newer than an already-loaded
  /// message, ascending — the merge-fetch fallback a realtime handler uses
  /// when it can't merge a single payload row directly; this never touches
  /// older history the way a bare re-fetch of "latest N" would.
  Future<List<ChatMessage>> listMessages(
    String conversationId, {
    DateTime? before,
    DateTime? after,
  }) async {
    try {
      var query = _supabase
          .from('messages')
          .select(_dmMessageColumns)
          .eq('conversation_id', conversationId);

      if (before != null) {
        query = query.lt('created_at', before.toUtc().toIso8601String());
      }
      if (after != null) {
        query = query.gt('created_at', after.toUtc().toIso8601String());
      }

      if (after != null) {
        final rows = await query
            .order('created_at', ascending: true)
            .limit(mergeFetchCap);
        return List<Map<String, dynamic>>.from(
          rows as List,
        ).map(ChatMessage.fromSupabase).toList();
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(messagePageSize);

      return List<Map<String, dynamic>>.from(
        rows as List,
      ).map(ChatMessage.fromSupabase).toList().reversed.toList();
    } catch (e) {
      debugPrint('MessagingService.listMessages failed: $e');
      rethrow;
    }
  }

  /// Safety cap on an [after]-cursor merge-fetch — this path only runs when a
  /// realtime payload couldn't be merged directly, which should be rare, but
  /// an unbounded query after a long realtime outage would be a real cost.
  static const int mergeFetchCap = 200;

  /// Messages per page — the portal itself loads a thread's entire history
  /// unbounded (see docs/messaging audit), which doesn't scale on mobile
  /// data/battery. Paginating is a deliberate, flagged divergence.
  static const int messagePageSize = 50;

  /// Sends a plain-text message.
  ///
  /// Mirrors `sendTextMessage` in useDmMessaging.ts: moderates the text
  /// first (fails open — a moderation-service outage must never block a
  /// legitimate send), then inserts. Errors from the insert itself (rate
  /// limit, RLS block) are mapped to the portal's exact user-facing copy.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? replyToId,
  }) async {
    final trimmed = content.trim();
    await moderateText(trimmed);

    try {
      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': trimmed,
        'message_type': 'text',
        if (replyToId != null) 'reply_to_id': replyToId,
      });
    } catch (e) {
      debugPrint('MessagingService.sendMessage failed: $e');
      throw mapSendError(e);
    }
  }

  /// Shares a property into a conversation. There is no dedicated RPC for
  /// this on the portal either — `sendPropertyShare` in useDmMessaging.ts is
  /// also a raw insert.
  /// [surface] is `'dm'` or `'channel'` — same convention as the reaction/
  /// edit/delete RPCs, so this one method covers both instead of a second
  /// `sendChannelPropertyShare` twin (there had been zero callers of this
  /// method at all before this repair pass, so nothing depends on the old
  /// DM-only signature).
  Future<void> sendPropertyShare({
    required String threadId,
    required String senderId,
    required String propertyId,
    required String content,
    String surface = 'dm',
  }) async {
    final table = surface == 'channel' ? 'channel_messages' : 'messages';
    final idColumn = surface == 'channel' ? 'channel_id' : 'conversation_id';
    try {
      await _supabase.from(table).insert({
        idColumn: threadId,
        'sender_id': senderId,
        'content': content,
        'message_type': 'property_share',
        'property_id': propertyId,
      });
    } catch (e) {
      debugPrint('MessagingService.sendPropertyShare failed: $e');
      throw mapSendError(e);
    }
  }

  /// Properties matching [term], sourced from `properties_public` — the
  /// exact same view+shape the portal's `SharePropertyModal.tsx` queries
  /// (`select id, title, price, location, media_urls`, `ilike title`,
  /// newest first, capped at 15).
  Future<List<SharedPropertyPreview>> searchProperties(String term) async {
    final query = term.trim();
    if (query.length < 2) return const [];

    try {
      final rows = await _supabase
          .from('properties_public')
          .select('id, title, price, location, media_urls')
          .ilike('title', '%$query%')
          .order('created_at', ascending: false)
          .limit(15);

      return List<Map<String, dynamic>>.from(rows as List)
          .where((row) => row['id'] != null)
          .map(SharedPropertyPreview.fromSupabase)
          .toList();
    } catch (e) {
      debugPrint('MessagingService.searchProperties failed: $e');
      rethrow;
    }
  }

  /// Batch-resolves every distinct `property_id` visible in a page of
  /// messages in one query — avoids an N+1 property lookup per
  /// `property_share` bubble, same `inFilter('id', ids)` pattern already
  /// used throughout this file (e.g. [listChannels]).
  Future<Map<String, SharedPropertyPreview>> fetchSharedProperties(
    Set<String> propertyIds,
  ) async {
    if (propertyIds.isEmpty) return const {};
    try {
      final rows = await _supabase
          .from('properties_public')
          .select('id, title, price, location, media_urls')
          .inFilter('id', propertyIds.toList());

      final result = <String, SharedPropertyPreview>{};
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final id = row['id']?.toString();
        if (id == null) continue;
        result[id] = SharedPropertyPreview.fromSupabase(row);
      }
      return result;
    } catch (e) {
      debugPrint('MessagingService.fetchSharedProperties failed: $e');
      return const {};
    }
  }

  /// Forwards a message into a *different* DM conversation — a brand-new
  /// message row copying the content, exactly like the portal's
  /// `ForwardMessageModal.tsx` (no `forwarded_from` reference/pointer column
  /// exists, so this can't and shouldn't invent one). Matches the portal's
  /// own scope exactly: DM target only, and only `text`/`property_share`
  /// source messages — image/voice forwarding is out of scope there too,
  /// since `get-chat-media-url`'s lookup assumes one message row per storage
  /// path, which a copied row would violate.
  Future<void> forwardMessage({
    required String targetConversationId,
    required String senderId,
    required ChatMessage message,
  }) async {
    if (message.isPropertyShare && message.propertyId != null) {
      await sendPropertyShare(
        threadId: targetConversationId,
        senderId: senderId,
        propertyId: message.propertyId!,
        content: message.content,
      );
      return;
    }
    await sendMessage(
      conversationId: targetConversationId,
      senderId: senderId,
      content: message.content,
    );
  }

  /// Unread count per conversation.
  ///
  /// Mirrors `useConversationUnreadCounts` — unread rows not sent by the
  /// caller, grouped client-side. RLS keeps the result to the caller's own
  /// conversations, which is why React issues no participant filter either.
  Future<Map<String, int>> unreadCountsByConversation(String userId) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select('conversation_id')
          .eq('is_read', false)
          .neq('sender_id', userId);

      final counts = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final id = row['conversation_id']?.toString();
        if (id == null) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('MessagingService.unreadCountsByConversation failed: $e');
      rethrow;
    }
  }

  /// Marks everything the other party sent as read.
  ///
  /// Mirrors `markConversationAsRead` in useConversationUnreadCounts.ts.
  /// Rethrows on failure so callers (the badge-clear reconciliation in
  /// [MessagingProvider]) can tell "marked read" apart from "silently
  /// failed" instead of the update vanishing without a trace.
  Future<void> markConversationAsRead({
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('MessagingService.markConversationAsRead failed: $e');
      rethrow;
    }
  }

  // ── Starting a new conversation ───────────────────────────────────────────

  /// Minimum characters before the recipient search runs, matching
  /// NewChatModal.tsx's `term.trim().length < 2` guard.
  static const int recipientSearchMinLength = 2;

  /// Candidate recipients matching [term].
  ///
  /// Mirrors `handleSearch` in features/messaging/NewChatModal.tsx — same
  /// table, same columns, same moderation filters (case-insensitive name
  /// match, excluding self, approved and not admin-blocked) and the same
  /// 10-row limit. On top of that — `profiles.is_blocked` is an admin
  /// moderation flag, not the caller's personal block list — this also
  /// excludes anyone the *caller* has personally blocked via `user_blocks`,
  /// which the original implementation confused with the moderation flag and
  /// never actually excluded.
  Future<List<ConversationParticipant>> searchRecipients({
    required String term,
    required String currentUserId,
  }) async {
    final query = term.trim();
    if (query.length < recipientSearchMinLength) return const [];

    try {
      final blockedIds = await myBlockedUserIds(currentUserId);

      final rows = await _supabase
          .from('profiles')
          .select('user_id, display_name, avatar_url, user_type')
          .ilike('display_name', '%$query%')
          .neq('user_id', currentUserId)
          .eq('approval_status', 'approved')
          .eq('is_blocked', false)
          .limit(10);

      return List<Map<String, dynamic>>.from(rows as List)
          .where((row) => row['user_id'] != null)
          .where((row) => !blockedIds.contains(row['user_id'].toString()))
          .map(
            (row) => ConversationParticipant(
              userId: row['user_id'].toString(),
              displayName: (row['display_name'] as String?) ?? 'Unknown',
              avatarUrl: row['avatar_url'] as String?,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint('MessagingService.searchRecipients failed: $e');
      rethrow;
    }
  }

  /// The caller's own personal block list — ids in `user_blocks` where
  /// `blocker_id = currentUserId`. Deliberately one-directional (never "who
  /// has blocked me"): the portal doesn't expose that to the blocked party
  /// either, so mobile doesn't infer or surface it.
  Future<Set<String>> myBlockedUserIds(String currentUserId) async {
    try {
      final rows = await _supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUserId);
      return List<Map<String, dynamic>>.from(
        rows as List,
      ).map((r) => r['blocked_id']?.toString()).whereType<String>().toSet();
    } catch (e) {
      debugPrint('MessagingService.myBlockedUserIds failed: $e');
      return const {};
    }
  }

  /// Whether the caller has personally blocked [otherUserId] — the one
  /// direction that's ever surfaced in the UI (see [myBlockedUserIds]).
  Future<bool> haveIBlocked(String currentUserId, String otherUserId) async {
    try {
      final rows = await _supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', otherUserId)
          .limit(1);
      return List.from(rows as List).isNotEmpty;
    } catch (e) {
      debugPrint('MessagingService.haveIBlocked failed: $e');
      return false;
    }
  }

  /// Profiles the caller has personally blocked, for the "Blocked Users"
  /// management screen.
  Future<List<ConversationParticipant>> fetchBlockedUsers(
    String currentUserId,
  ) async {
    try {
      final ids = await myBlockedUserIds(currentUserId);
      if (ids.isEmpty) return const [];
      final profiles = await _fetchPublicProfiles(ids);
      return profiles.values.toList();
    } catch (e) {
      debugPrint('MessagingService.fetchBlockedUsers failed: $e');
      rethrow;
    }
  }

  /// Starts (or reuses) a conversation and immediately hides it for the
  /// caller — used to "decline" a message request, mirroring the portal's
  /// `hideConversation` being reused for the decline action.
  Future<void> hideConversation(String conversationId) async {
    try {
      await _supabase.rpc(
        'hide_conversation',
        params: {'p_conversation_id': conversationId},
      );
    } catch (e) {
      debugPrint('MessagingService.hideConversation failed: $e');
      rethrow;
    }
  }

  /// Accepts a pending message request — flips the caller's own
  /// `request_status` to `'accepted'` so they can now reply.
  Future<void> acceptConversationRequest(String conversationId) async {
    try {
      await _supabase.rpc(
        'accept_conversation_request',
        params: {'p_conversation_id': conversationId},
      );
    } catch (e) {
      debugPrint('MessagingService.acceptConversationRequest failed: $e');
      rethrow;
    }
  }

  Future<void> setConversationMuted(String conversationId, bool muted) async {
    try {
      await _supabase.rpc(
        'set_conversation_muted',
        params: {'p_conversation_id': conversationId, 'p_muted': muted},
      );
    } catch (e) {
      debugPrint('MessagingService.setConversationMuted failed: $e');
      rethrow;
    }
  }

  Future<void> setChannelMuted(String channelId, bool muted) async {
    try {
      await _supabase.rpc(
        'set_channel_muted',
        params: {'p_channel_id': channelId, 'p_muted': muted},
      );
    } catch (e) {
      debugPrint('MessagingService.setChannelMuted failed: $e');
      rethrow;
    }
  }

  /// Returns the conversation id shared with [withUserId], creating it if there
  /// isn't one yet.
  ///
  /// Delegates to the existing `start_conversation(with_user_id uuid)` RPC —
  /// the same call `Chat.tsx` and `ChatModal.tsx` make. The function is
  /// SECURITY DEFINER and idempotent: it looks for an existing conversation
  /// between the two users first and only inserts when none exists, adding
  /// both participant rows itself. Doing this client-side instead would mean
  /// writing `conversations` and `conversation_participants` directly, which
  /// the RLS policies deliberately do not allow.
  ///
  /// [skipRequestGate] mirrors the portal's `p_skip_request_gate`: pass
  /// `true` only for a conversation started from a genuine property/lead
  /// context (the sender explicitly shares a listing) — every other caller
  /// must pass `false` so the recipient's row starts `pending` and has to be
  /// accepted before the sender's replies land. The default here is `false`
  /// (the *safer*, more-gated choice, deliberately the opposite of the RPC's
  /// own `p_skip_request_gate default true`) so a future call site that
  /// forgets to specify it fails safe into "gated" rather than silently
  /// bypassing the request flow — this default was the exact bug fixed in
  /// this repair pass (every existing caller now passes the flag explicitly
  /// regardless).
  Future<String> startConversation(
    String withUserId, {
    bool skipRequestGate = false,
  }) async {
    try {
      final result = await _supabase.rpc(
        'start_conversation',
        params: {
          'with_user_id': withUserId,
          'p_skip_request_gate': skipRequestGate,
        },
      );

      final conversationId = result?.toString();
      if (conversationId == null || conversationId.isEmpty) {
        throw StateError('start_conversation returned no conversation id');
      }
      return conversationId;
    } catch (e) {
      debugPrint('MessagingService.startConversation failed: $e');
      rethrow;
    }
  }

  /// Whether the caller and [otherUserId] have blocked each other, in either
  /// direction. Never raises — returns `false` if unauthenticated.
  Future<bool> isBlockedWith(String otherUserId) async {
    try {
      final result = await _supabase.rpc(
        'is_blocked_with',
        params: {'p_other_user_id': otherUserId},
      );
      return result == true;
    } catch (e) {
      debugPrint('MessagingService.isBlockedWith failed: $e');
      return false;
    }
  }

  // ── Channels (group) ──────────────────────────────────────────────────────

  /// Channels the user has joined.
  ///
  /// Mirrors `fetchChannels` in features/messaging/ChannelsList.tsx: the
  /// caller's memberships first, then the channel rows, then a participant
  /// count and last-message timestamp per channel. The per-channel counts are
  /// batched here for the same reason as [listConversations].
  Future<List<ChannelSummary>> listChannels(String userId) async {
    try {
      final membershipRows = await _supabase
          .from('channel_participants')
          .select('channel_id, role, muted_at')
          .eq('user_id', userId);

      final memberships = List<Map<String, dynamic>>.from(
        membershipRows as List,
      ).where((m) => m['channel_id'] != null).toList();
      if (memberships.isEmpty) return const [];

      final channelIds = memberships
          .map((m) => m['channel_id'].toString())
          .toList();
      final roleByChannel = {
        for (final m in memberships)
          m['channel_id'].toString(): m['role'] as String?,
      };
      final mutedByChannel = {
        for (final m in memberships)
          m['channel_id'].toString(): m['muted_at'] != null,
      };

      final channelRows = await _supabase
          .from('channels')
          .select(
            'id, name, description, created_at, created_by, '
            'max_participants',
          )
          .inFilter('id', channelIds);

      final allParticipants = await _supabase
          .from('channel_participants')
          .select('channel_id')
          .inFilter('channel_id', channelIds);

      final participantCounts = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(
        allParticipants as List,
      )) {
        final id = row['channel_id']?.toString();
        if (id == null) continue;
        participantCounts[id] = (participantCounts[id] ?? 0) + 1;
      }

      final messageRows = await _supabase
          .from('channel_messages')
          .select('channel_id, created_at, sender_id, is_read')
          .inFilter('channel_id', channelIds)
          .order('created_at', ascending: false);

      final lastMessageAt = <String, DateTime>{};
      final unread = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(messageRows as List)) {
        final id = row['channel_id']?.toString();
        if (id == null) continue;
        final created = row['created_at'] as String?;
        final parsed = created == null ? null : DateTime.tryParse(created);
        if (parsed != null && !lastMessageAt.containsKey(id)) {
          lastMessageAt[id] = parsed;
        }
        // Same rule the unread hooks apply: not mine and not yet read.
        if (row['is_read'] != true && row['sender_id']?.toString() != userId) {
          unread[id] = (unread[id] ?? 0) + 1;
        }
      }

      final channels =
          List<Map<String, dynamic>>.from(
              channelRows as List,
            ).where((row) => row['id'] != null).map((row) {
              final id = row['id'].toString();
              return ChannelSummary.fromSupabase(
                row,
                myRole: roleByChannel[id],
                participantCount: participantCounts[id] ?? 0,
                lastMessageAt: lastMessageAt[id],
                unreadCount: unread[id] ?? 0,
                isMuted: mutedByChannel[id] ?? false,
              );
            }).toList()
            ..sort((a, b) {
              final at = a.lastMessageAt;
              final bt = b.lastMessageAt;
              if (at == null && bt == null) return a.name.compareTo(b.name);
              if (at == null) return 1;
              if (bt == null) return -1;
              return bt.compareTo(at);
            });

      return channels;
    } catch (e) {
      debugPrint('MessagingService.listChannels failed: $e');
      rethrow;
    }
  }

  /// Most recent page of a channel, oldest-first for display. Mirrors
  /// `fetchMessages` in features/messaging/ChannelChat.tsx, paginated the
  /// same way as [listMessages].
  Future<List<ChatMessage>> listChannelMessages(
    String channelId, {
    DateTime? before,
    DateTime? after,
  }) async {
    try {
      var query = _supabase
          .from('channel_messages')
          .select(_messageColumns)
          .eq('channel_id', channelId);

      if (before != null) {
        query = query.lt('created_at', before.toUtc().toIso8601String());
      }
      if (after != null) {
        query = query.gt('created_at', after.toUtc().toIso8601String());
      }

      if (after != null) {
        final rows = await query
            .order('created_at', ascending: true)
            .limit(mergeFetchCap);
        return List<Map<String, dynamic>>.from(
          rows as List,
        ).map(ChatMessage.fromSupabase).toList();
      }

      final rows = await query
          .order('created_at', ascending: false)
          .limit(messagePageSize);

      return List<Map<String, dynamic>>.from(
        rows as List,
      ).map(ChatMessage.fromSupabase).toList().reversed.toList();
    } catch (e) {
      debugPrint('MessagingService.listChannelMessages failed: $e');
      rethrow;
    }
  }

  /// Display names/avatars for a set of channel senders.
  ///
  /// A channel thread shows who sent each message, which the 1:1 thread does
  /// not need. Resolved in one batched round-trip.
  Future<Map<String, ConversationParticipant>> fetchSenderProfiles(
    Set<String> senderIds,
  ) => _fetchPublicProfiles(senderIds);

  /// Mirrors `sendMessage` in ChannelChat.tsx: moderate first (fail-open),
  /// then insert, mapping rate-limit/RLS errors to the portal's exact copy.
  Future<void> sendChannelMessage({
    required String channelId,
    required String senderId,
    required String content,
    String? replyToId,
  }) async {
    final trimmed = content.trim();
    await moderateText(trimmed);

    try {
      await _supabase.from('channel_messages').insert({
        'channel_id': channelId,
        'sender_id': senderId,
        'content': trimmed,
        'message_type': 'text',
        if (replyToId != null) 'reply_to_id': replyToId,
      });
    } catch (e) {
      debugPrint('MessagingService.sendChannelMessage failed: $e');
      throw mapSendError(e);
    }
  }

  /// Mirrors `markMessagesAsRead` in ChannelChat.tsx. Rethrows on failure —
  /// see [markConversationAsRead].
  Future<void> markChannelAsRead({
    required String channelId,
    required String userId,
  }) async {
    try {
      await _supabase
          .from('channel_messages')
          .update({
            'is_read': true,
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('channel_id', channelId)
          .neq('sender_id', userId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('MessagingService.markChannelAsRead failed: $e');
      rethrow;
    }
  }

  // ── Message actions (reply/react/edit/delete) — shared by DM & channel ────
  //
  // `surface` is always the literal string 'dm' or 'channel', matching the
  // portal's features/messaging/lib/messageActions.ts.

  Future<String> toggleReaction({
    required String messageId,
    required String surface,
    required String emoji,
  }) async {
    try {
      final result = await _supabase.rpc(
        'toggle_reaction',
        params: {
          'p_message_id': messageId,
          'p_surface': surface,
          'p_emoji': emoji,
        },
      );
      return result as String? ?? 'added';
    } catch (e) {
      debugPrint('MessagingService.toggleReaction failed: $e');
      rethrow;
    }
  }

  /// Reactions for a batch of messages on one surface, grouped by message id
  /// then by emoji.
  Future<Map<String, List<MessageReaction>>> fetchReactions({
    required List<String> messageIds,
    required String surface,
  }) async {
    if (messageIds.isEmpty) return const {};
    try {
      final rows = await _supabase
          .from('message_reactions')
          .select('message_id, emoji, user_id')
          .eq('surface', surface)
          .inFilter('message_id', messageIds);

      final byMessage = <String, List<Map<String, dynamic>>>{};
      for (final row in List<Map<String, dynamic>>.from(rows as List)) {
        final id = row['message_id']?.toString();
        if (id == null) continue;
        (byMessage[id] ??= []).add(row);
      }
      return {
        for (final entry in byMessage.entries)
          entry.key: MessageReaction.groupByEmoji(entry.value),
      };
    } catch (e) {
      debugPrint('MessagingService.fetchReactions failed: $e');
      rethrow;
    }
  }

  Future<void> editMessage({
    required String messageId,
    required String surface,
    required String newContent,
  }) async {
    try {
      await _supabase.rpc(
        'edit_message',
        params: {
          'p_message_id': messageId,
          'p_surface': surface,
          'p_new_content': newContent.trim(),
        },
      );
    } catch (e) {
      debugPrint('MessagingService.editMessage failed: $e');
      rethrow;
    }
  }

  Future<void> deleteMessageForMe({
    required String messageId,
    required String surface,
  }) async {
    try {
      await _supabase.rpc(
        'delete_message_for_me',
        params: {'p_message_id': messageId, 'p_surface': surface},
      );
    } catch (e) {
      debugPrint('MessagingService.deleteMessageForMe failed: $e');
      rethrow;
    }
  }

  Future<void> deleteMessageForEveryone({
    required String messageId,
    required String surface,
  }) async {
    try {
      await _supabase.rpc(
        'delete_message_for_everyone',
        params: {'p_message_id': messageId, 'p_surface': surface},
      );
    } catch (e) {
      debugPrint('MessagingService.deleteMessageForEveryone failed: $e');
      rethrow;
    }
  }

  // ── Moderation & presence ──────────────────────────────────────────────

  /// Calls the `moderate-comment` edge function before a text send. Fails
  /// open on any transport/parsing error (matching the portal exactly) —
  /// only an explicit `isAllowed: false` blocks the send.
  Future<void> moderateText(String text) async {
    if (text.isEmpty) return;
    try {
      final response = await _supabase.functions.invoke(
        'moderate-comment',
        body: {'comment': text},
      );
      final data = response.data;
      if (data is Map && data['isAllowed'] == false) {
        throw MessageModerationError(
          (data['reason'] as String?) ?? "This message isn't allowed.",
        );
      }
    } on MessageModerationError {
      rethrow;
    } catch (e) {
      debugPrint('MessagingService.moderateText failed open: $e');
    }
  }

  /// Heartbeat — the only legal way to write `profiles.is_online`/
  /// `last_seen_at`; a raw `.update()` on `profiles` is silently stripped of
  /// those two columns by a DB trigger for any non-service-role caller.
  Future<void> updateOwnPresence(bool isOnline) async {
    try {
      await _supabase.rpc(
        'update_own_presence',
        params: {'p_is_online': isOnline},
      );
    } catch (e) {
      debugPrint('MessagingService.updateOwnPresence failed: $e');
    }
  }

  // ── Blocking & reporting ───────────────────────────────────────────────

  /// Idempotent: blocking someone who is already blocked is treated as
  /// success (the desired end state — "this person is blocked" — already
  /// holds), rather than surfacing the `user_blocks_pkey` unique-constraint
  /// violation a plain insert would throw on a repeat call.
  Future<void> blockUser(String userId) async {
    try {
      final me = _supabase.auth.currentUser?.id;
      if (me == null) throw StateError('Not authenticated');
      await _supabase.from('user_blocks').insert({
        'blocker_id': me,
        'blocked_id': userId,
      });
    } catch (e) {
      if (postgrestErrorCode(e) == '23505') {
        debugPrint(
          'MessagingService.blockUser: already blocked, treating as success',
        );
        return;
      }
      debugPrint('MessagingService.blockUser failed: $e');
      rethrow;
    }
  }

  Future<void> unblockUser(String userId) async {
    try {
      final me = _supabase.auth.currentUser?.id;
      if (me == null) throw StateError('Not authenticated');
      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', me)
          .eq('blocked_id', userId);
    } catch (e) {
      debugPrint('MessagingService.unblockUser failed: $e');
      rethrow;
    }
  }

  // ── Channel administration ─────────────────────────────────────────────
  //
  // `channels` INSERT is self-service for any authenticated user
  // (`created_by = auth.uid()`); adding participants requires being the
  // creator or an existing admin/moderator — see
  // 20250823170108_..._fix_channel_rls.sql. Creating a channel does not
  // auto-add the creator as a participant, so that's a second insert here,
  // which the same RLS policy explicitly allows for the creator.

  Future<String> createChannel({
    required String name,
    String? description,
  }) async {
    try {
      final me = _supabase.auth.currentUser?.id;
      if (me == null) throw StateError('Not authenticated');

      final inserted = await _supabase
          .from('channels')
          .insert({
            'name': name.trim(),
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            'created_by': me,
          })
          .select('id')
          .single();

      final channelId = inserted['id']?.toString();
      if (channelId == null) {
        throw StateError('Channel insert returned no id');
      }

      await _supabase.from('channel_participants').insert({
        'channel_id': channelId,
        'user_id': me,
        'role': 'admin',
      });

      return channelId;
    } catch (e) {
      debugPrint('MessagingService.createChannel failed: $e');
      rethrow;
    }
  }

  /// Participants of a channel, with their public profile resolved — for the
  /// channel settings screen.
  Future<List<({ConversationParticipant profile, String role})>>
  fetchChannelParticipants(String channelId) async {
    try {
      final rows = await _supabase
          .from('channel_participants')
          .select('user_id, role')
          .eq('channel_id', channelId);

      final list = List<Map<String, dynamic>>.from(
        rows as List,
      ).where((r) => r['user_id'] != null).toList();
      final ids = list.map((r) => r['user_id'].toString()).toSet();
      final profiles = await _fetchPublicProfiles(ids);

      return list.map((r) {
        final id = r['user_id'].toString();
        final profile =
            profiles[id] ??
            ConversationParticipant(userId: id, displayName: 'Unknown');
        return (profile: profile, role: (r['role'] as String?) ?? 'member');
      }).toList();
    } catch (e) {
      debugPrint('MessagingService.fetchChannelParticipants failed: $e');
      rethrow;
    }
  }

  /// Admin/moderator only (server-enforced by RLS) — promotes or demotes a
  /// participant.
  Future<void> setChannelParticipantRole({
    required String channelId,
    required String userId,
    required String role,
  }) async {
    try {
      await _supabase
          .from('channel_participants')
          .update({'role': role})
          .eq('channel_id', channelId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('MessagingService.setChannelParticipantRole failed: $e');
      rethrow;
    }
  }

  /// Adds an existing user to a channel — admin/moderator/creator only,
  /// server-enforced.
  Future<void> addChannelParticipant({
    required String channelId,
    required String userId,
  }) async {
    try {
      await _supabase.from('channel_participants').insert({
        'channel_id': channelId,
        'user_id': userId,
        'role': 'member',
      });
    } catch (e) {
      debugPrint('MessagingService.addChannelParticipant failed: $e');
      rethrow;
    }
  }

  /// Leaves (or removes) a participant — the RLS delete policy only allows
  /// `user_id = auth.uid()`, so this is "leave", not "remove someone else".
  Future<void> leaveChannel(String channelId, String userId) async {
    try {
      await _supabase
          .from('channel_participants')
          .delete()
          .eq('channel_id', channelId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('MessagingService.leaveChannel failed: $e');
      rethrow;
    }
  }

  Future<void> reportMessage({
    required String messageId,
    required String surface,
    required String reportedUserId,
    required String reason,
    String? details,
  }) async {
    try {
      final me = _supabase.auth.currentUser?.id;
      if (me == null) throw StateError('Not authenticated');
      await _supabase.from('message_reports').insert({
        'reporter_id': me,
        'reported_user_id': reportedUserId,
        'message_id': messageId,
        'surface': surface,
        'reason': reason,
        if (details != null) 'details': details,
      });
    } catch (e) {
      debugPrint('MessagingService.reportMessage failed: $e');
      rethrow;
    }
  }
}
