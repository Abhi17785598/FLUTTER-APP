import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/channel_summary.dart';
import '../models/chat_message.dart';
import '../models/conversation_summary.dart';

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
          .select('id, last_message_at')
          .order('last_message_at', ascending: false);

      final conversations = List<Map<String, dynamic>>.from(convRows as List);
      if (conversations.isEmpty) return const [];

      final ids = conversations.map((c) => c['id'].toString()).toList();

      final participantRows = await _supabase
          .from('conversation_participants')
          .select('conversation_id, user_id')
          .inFilter('conversation_id', ids);

      // conversation_id -> the *other* participant's user id
      final otherIdByConversation = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(
        participantRows as List,
      )) {
        final convId = row['conversation_id'].toString();
        final memberId = row['user_id'].toString();
        if (memberId != userId) otherIdByConversation[convId] = memberId;
      }

      final profilesById = await _fetchPublicProfiles(
        otherIdByConversation.values.toSet(),
      );

      // Newest-first across all conversations; the first row seen per
      // conversation is therefore its latest message.
      final messageRows = await _supabase
          .from('messages')
          .select('conversation_id, content, created_at')
          .inFilter('conversation_id', ids)
          .order('created_at', ascending: false);

      final lastMessageByConversation = <String, String>{};
      for (final row in List<Map<String, dynamic>>.from(messageRows as List)) {
        final convId = row['conversation_id'].toString();
        lastMessageByConversation.putIfAbsent(
          convId,
          () => (row['content'] as String?) ?? '',
        );
      }

      final unread = await unreadCountsByConversation(userId);

      return conversations.map((conv) {
        final id = conv['id'].toString();
        final otherId = otherIdByConversation[id];
        final createdRaw = conv['last_message_at'] as String?;

        return ConversationSummary(
          id: id,
          lastMessageAt:
              createdRaw == null ? null : DateTime.tryParse(createdRaw),
          otherParticipant: otherId == null ? null : profilesById[otherId],
          lastMessage: lastMessageByConversation[id] ?? '',
          unreadCount: unread[id] ?? 0,
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
        .select('user_id, display_name, avatar_url')
        .inFilter('user_id', userIds.toList());

    return {
      for (final row in List<Map<String, dynamic>>.from(rows as List))
        row['user_id'].toString(): ConversationParticipant(
          userId: row['user_id'].toString(),
          displayName: (row['display_name'] as String?) ?? 'Unknown',
          avatarUrl: row['avatar_url'] as String?,
        ),
    };
  }

  /// Full history for one conversation, oldest first.
  ///
  /// Mirrors `fetchMessages` in ChatModal.tsx.
  Future<List<ChatMessage>> listMessages(String conversationId) async {
    try {
      final rows = await _supabase
          .from('messages')
          .select(
            'id, content, sender_id, message_type, property_id, created_at, '
            'is_read',
          )
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(rows as List)
          .map(ChatMessage.fromSupabase)
          .toList();
    } catch (e) {
      debugPrint('MessagingService.listMessages failed: $e');
      rethrow;
    }
  }

  /// Sends a plain-text message.
  ///
  /// Mirrors `sendMessage` in ChatModal.tsx — same four columns, nothing else.
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': senderId,
        'content': content.trim(),
        'message_type': 'text',
      });
    } catch (e) {
      debugPrint('MessagingService.sendMessage failed: $e');
      rethrow;
    }
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
        final id = row['conversation_id'].toString();
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('MessagingService.unreadCountsByConversation failed: $e');
      return const {};
    }
  }

  /// Marks everything the other party sent as read.
  ///
  /// Mirrors `markConversationAsRead` in useConversationUnreadCounts.ts.
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
    }
  }

  // ── Starting a new conversation ───────────────────────────────────────────

  /// Minimum characters before the recipient search runs, matching
  /// NewChatModal.tsx's `term.trim().length < 2` guard.
  static const int recipientSearchMinLength = 2;

  /// Candidate recipients matching [term].
  ///
  /// Mirrors `handleSearch` in features/messaging/NewChatModal.tsx — same
  /// table, same columns, same filters (case-insensitive name match, excluding
  /// self, approved and not blocked) and the same 10-row limit.
  Future<List<ConversationParticipant>> searchRecipients({
    required String term,
    required String currentUserId,
  }) async {
    final query = term.trim();
    if (query.length < recipientSearchMinLength) return const [];

    try {
      final rows = await _supabase
          .from('profiles')
          .select('user_id, display_name, avatar_url, user_type')
          .ilike('display_name', '%$query%')
          .neq('user_id', currentUserId)
          .eq('approval_status', 'approved')
          .eq('is_blocked', false)
          .limit(10);

      return List<Map<String, dynamic>>.from(rows as List)
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
  Future<String> startConversation(String withUserId) async {
    try {
      final result = await _supabase.rpc(
        'start_conversation',
        params: {'with_user_id': withUserId},
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
          .select('channel_id, role')
          .eq('user_id', userId);

      final memberships =
          List<Map<String, dynamic>>.from(membershipRows as List);
      if (memberships.isEmpty) return const [];

      final channelIds =
          memberships.map((m) => m['channel_id'].toString()).toList();
      final roleByChannel = {
        for (final m in memberships)
          m['channel_id'].toString(): m['role'] as String?,
      };

      final channelRows = await _supabase
          .from('channels')
          .select('id, name, description, created_at, created_by, '
              'max_participants')
          .inFilter('id', channelIds);

      final allParticipants = await _supabase
          .from('channel_participants')
          .select('channel_id')
          .inFilter('channel_id', channelIds);

      final participantCounts = <String, int>{};
      for (final row in List<Map<String, dynamic>>.from(
        allParticipants as List,
      )) {
        final id = row['channel_id'].toString();
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
        final id = row['channel_id'].toString();
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

      final channels = List<Map<String, dynamic>>.from(channelRows as List)
          .map((row) {
            final id = row['id'].toString();
            return ChannelSummary.fromSupabase(
              row,
              myRole: roleByChannel[id],
              participantCount: participantCounts[id] ?? 0,
              lastMessageAt: lastMessageAt[id],
              unreadCount: unread[id] ?? 0,
            );
          })
          .toList()
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

  /// Full history for one channel, oldest first.
  ///
  /// Mirrors `fetchMessages` in features/messaging/ChannelChat.tsx.
  Future<List<ChatMessage>> listChannelMessages(String channelId) async {
    try {
      final rows = await _supabase
          .from('channel_messages')
          .select(
            'id, content, sender_id, message_type, property_id, media_urls, '
            'created_at, is_read',
          )
          .eq('channel_id', channelId)
          .order('created_at', ascending: true);

      return List<Map<String, dynamic>>.from(rows as List)
          .map(ChatMessage.fromSupabase)
          .toList();
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
  ) =>
      _fetchPublicProfiles(senderIds);

  /// Mirrors `sendMessage` in ChannelChat.tsx.
  Future<void> sendChannelMessage({
    required String channelId,
    required String senderId,
    required String content,
  }) async {
    try {
      await _supabase.from('channel_messages').insert({
        'channel_id': channelId,
        'sender_id': senderId,
        'content': content.trim(),
        'message_type': 'text',
      });
    } catch (e) {
      debugPrint('MessagingService.sendChannelMessage failed: $e');
      rethrow;
    }
  }

  /// Mirrors `markMessagesAsRead` in ChannelChat.tsx.
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
    }
  }
}
