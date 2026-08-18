import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/conversation_summary.dart';
import '../models/message_reaction.dart';
import '../services/chat_media_service.dart';
import '../services/messaging_exceptions.dart';
import '../services/messaging_service.dart';
import '../services/presence_service.dart';

/// Which backing table a thread reads and writes.
enum ChatThreadKind {
  /// 1:1 — `messages`, scoped by `conversation_id`.
  conversation,

  /// Group — `channel_messages`, scoped by `channel_id`.
  channel,
}

/// State for a single open thread, 1:1 or channel.
///
/// Kept separate from [MessagingProvider] deliberately. Blueprint §16.7 lists
/// one provider for both, but the list and the thread are independent routes:
/// a thread opened directly (or after the list is disposed) still needs its
/// own state, and threading one provider through `Navigator.push` would make
/// the thread unusable on its own. Both share the same [MessagingService], so
/// there is no duplicated query logic.
///
/// §16.8 notes the channel thread "can share most structure" with the 1:1 one
/// — [kind] is that seam.
class ChatThreadProvider extends ChangeNotifier {
  ChatThreadProvider({
    required this.kind,
    required this.threadId,
    required this.userId,
    MessagingService? service,
    ChatMediaService? mediaService,
  })  : _service = service ?? MessagingService(),
        _mediaService = mediaService ?? ChatMediaService();

  final ChatThreadKind kind;

  /// `conversation_id` or `channel_id` depending on [kind].
  final String threadId;

  final String userId;

  final MessagingService _service;
  final ChatMediaService _mediaService;
  final SupabaseClient _supabase = Supabase.instance.client;
  final PresenceService _presence = PresenceService();

  RealtimeChannel? _realtime;
  RealtimeChannel? _typingChannel;
  Timer? _typingClearTimer;
  DateTime _lastTypingSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _disposed = false;

  /// Discards a slow response if a newer request has since started —
  /// otherwise a realtime-triggered refetch racing with `send()`'s own
  /// refetch (or a pull-to-refresh) can clobber a more recent result with a
  /// stale one.
  int _fetchRequestId = 0;

  List<ChatMessage> _messages = const [];
  Map<String, ConversationParticipant> _senders = const {};
  Map<String, List<MessageReaction>> _reactions = const {};
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;
  bool _hasMoreOlder = true;
  bool _loadingMore = false;
  bool _otherTyping = false;
  ChatMessage? _replyingTo;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get failed => _failed;
  bool get sending => _sending;
  bool get hasMoreOlder => _hasMoreOlder;
  bool get loadingMore => _loadingMore;
  bool get otherTyping => _otherTyping;
  ChatMessage? get replyingTo => _replyingTo;
  bool get isChannel => kind == ChatThreadKind.channel;

  /// `'dm'` or `'channel'` — the literal string every reaction/edit/delete
  /// RPC expects.
  String get _surface => isChannel ? 'channel' : 'dm';

  /// Sender profiles, populated for channel threads only — a 1:1 thread
  /// already knows who the other party is.
  ConversationParticipant? senderFor(String senderId) => _senders[senderId];

  List<MessageReaction> reactionsFor(String messageId) =>
      _reactions[messageId] ?? const [];

  /// The message a reply/quote strip is pointing at, resolved from the
  /// already-loaded thread — no separate fetch, matching the portal.
  ChatMessage? repliedMessage(String? replyToId) {
    if (replyToId == null) return null;
    for (final m in _messages) {
      if (m.id == replyToId) return m;
    }
    return null;
  }

  Future<void> load() async {
    _presence.attach();
    _subscribe();
    _subscribeTyping();
    await _fetch();
    // Opening a thread clears its unread rows, matching both ChatModal.tsx
    // and ChannelChat.tsx. A failure here must not become an unhandled
    // future error — mark-as-read failing silently just means the badge
    // reconciles a little later (MessagingProvider.refresh on thread close).
    try {
      await _markRead();
    } catch (e) {
      debugPrint('ChatThreadProvider._markRead failed: $e');
    }
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final requestId = ++_fetchRequestId;
    _loading = _messages.isEmpty;
    _failed = false;
    _safeNotify();

    try {
      final loaded = isChannel
          ? await _service.listChannelMessages(threadId)
          : await _service.listMessages(threadId);

      if (requestId != _fetchRequestId) return; // superseded by a newer call

      _messages = loaded;
      _hasMoreOlder = loaded.length >= MessagingService.messagePageSize;

      // Channel bubbles are attributed to a sender; resolve any we don't have.
      if (isChannel) {
        final missing = loaded
            .map((m) => m.senderId)
            .where((id) => id.isNotEmpty && !_senders.containsKey(id))
            .toSet();
        if (missing.isNotEmpty) {
          final fetched = await _service.fetchSenderProfiles(missing);
          if (requestId != _fetchRequestId) return;
          _senders = {..._senders, ...fetched};
        }
      }

      await _refreshReactions(loaded.map((m) => m.id).toList());
      if (requestId != _fetchRequestId) return;
    } catch (e) {
      if (requestId != _fetchRequestId) return;
      debugPrint('ChatThreadProvider._fetch failed: $e');
      _failed = true;
    } finally {
      if (requestId == _fetchRequestId) {
        _loading = false;
        _safeNotify();
      }
    }
  }

  /// Loads the page immediately older than the earliest currently-loaded
  /// message and prepends it. A deliberate divergence from the portal (which
  /// loads a thread's entire history unbounded) — see MessagingService docs.
  Future<void> loadMore() async {
    if (_loadingMore || !_hasMoreOlder || _messages.isEmpty) return;
    _loadingMore = true;
    _safeNotify();

    try {
      final oldest = _messages.first.createdAt;
      final older = oldest == null
          ? const <ChatMessage>[]
          : isChannel
              ? await _service.listChannelMessages(threadId, before: oldest)
              : await _service.listMessages(threadId, before: oldest);

      _hasMoreOlder = older.length >= MessagingService.messagePageSize;
      if (older.isNotEmpty) {
        _messages = [...older, ..._messages];
        await _refreshReactions(older.map((m) => m.id).toList());
      }
    } catch (e) {
      debugPrint('ChatThreadProvider.loadMore failed: $e');
    } finally {
      _loadingMore = false;
      _safeNotify();
    }
  }

  Future<void> _refreshReactions(List<String> messageIds) async {
    if (messageIds.isEmpty) return;
    try {
      final fetched = await _service.fetchReactions(
        messageIds: messageIds,
        surface: _surface,
      );
      _reactions = {..._reactions, ...fetched};
    } catch (e) {
      debugPrint('ChatThreadProvider._refreshReactions failed: $e');
    }
  }

  Future<void> _markRead() async {
    if (isChannel) {
      await _service.markChannelAsRead(channelId: threadId, userId: userId);
    } else {
      await _service.markConversationAsRead(
        conversationId: threadId,
        userId: userId,
      );
    }
  }

  void setReplyTo(ChatMessage? message) {
    _replyingTo = message;
    _safeNotify();
  }

  /// Sends [text]. Returns null on success, or an error message for the caller
  /// to surface in a snackbar (blueprint §12).
  Future<String?> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return null;

    _sending = true;
    _safeNotify();

    final replyToId = _replyingTo?.id;

    try {
      if (isChannel) {
        await _service.sendChannelMessage(
          channelId: threadId,
          senderId: userId,
          content: body,
          replyToId: replyToId,
        );
      } else {
        await _service.sendMessage(
          conversationId: threadId,
          senderId: userId,
          content: body,
          replyToId: replyToId,
        );
      }
      _replyingTo = null;
      // React refetches after sending rather than appending optimistically;
      // the Realtime callback will also fire, and _fetch is idempotent.
      await _fetch();
      return null;
    } on MessageModerationError catch (e) {
      return e.message;
    } on MessageSendDeniedError catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('ChatThreadProvider.send failed: $e');
      return 'Message not sent. Check your connection and try again.';
    } finally {
      _sending = false;
      _safeNotify();
    }
  }

  bool _uploadingMedia = false;
  bool get uploadingMedia => _uploadingMedia;

  /// Uploads and sends an image message via the same private `chat-media`
  /// bucket + `moderate-media` pipeline the portal uses — see
  /// [ChatMediaService.sendImage]. Video is deliberately not accepted from a
  /// 1:1 thread, matching the portal's own DM-vs-channel restriction.
  Future<String?> sendImage(Uint8List bytes, String extension) async {
    if (_uploadingMedia) return null;
    _uploadingMedia = true;
    _safeNotify();
    try {
      await _mediaService.sendImage(
        bytes: bytes,
        extension: extension,
        surface: _surface,
        threadId: threadId,
        senderId: userId,
      );
      await _fetch();
      return null;
    } on ChatMediaValidationError catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('ChatThreadProvider.sendImage failed: $e');
      return "Couldn't send the image. Check your connection and try again.";
    } finally {
      _uploadingMedia = false;
      _safeNotify();
    }
  }

  Future<String?> sendVoiceNote(
    Uint8List bytes,
    String extension,
    Duration duration,
  ) async {
    if (_uploadingMedia) return null;
    _uploadingMedia = true;
    _safeNotify();
    try {
      await _mediaService.sendVoiceNote(
        bytes: bytes,
        extension: extension,
        duration: duration,
        surface: _surface,
        threadId: threadId,
        senderId: userId,
      );
      await _fetch();
      return null;
    } on ChatMediaValidationError catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('ChatThreadProvider.sendVoiceNote failed: $e');
      return "Couldn't send the voice message. Check your connection and try again.";
    } finally {
      _uploadingMedia = false;
      _safeNotify();
    }
  }

  Future<String?> toggleReaction(String messageId, String emoji) async {
    try {
      await _service.toggleReaction(
        messageId: messageId,
        surface: _surface,
        emoji: emoji,
      );
      await _refreshReactions([messageId]);
      _safeNotify();
      return null;
    } catch (e) {
      debugPrint('ChatThreadProvider.toggleReaction failed: $e');
      return "Couldn't react to that message.";
    }
  }

  /// Sender-only, text-only, within the RPC's 15-minute window — this is a
  /// client-side hint; the server enforces the real cutoff and rejects late
  /// edits with its own error message.
  Future<String?> editMessage(String messageId, String newContent) async {
    try {
      await _service.editMessage(
        messageId: messageId,
        surface: _surface,
        newContent: newContent,
      );
      await _fetch();
      return null;
    } catch (e) {
      debugPrint('ChatThreadProvider.editMessage failed: $e');
      return 'Failed to edit message.';
    }
  }

  Future<String?> deleteForMe(String messageId) async {
    try {
      await _service.deleteMessageForMe(messageId: messageId, surface: _surface);
      _messages = _messages.where((m) => m.id != messageId).toList();
      _safeNotify();
      return null;
    } catch (e) {
      debugPrint('ChatThreadProvider.deleteForMe failed: $e');
      return 'Failed to delete message.';
    }
  }

  Future<String?> deleteForEveryone(String messageId) async {
    try {
      await _service.deleteMessageForEveryone(
        messageId: messageId,
        surface: _surface,
      );
      await _fetch();
      return null;
    } catch (e) {
      debugPrint('ChatThreadProvider.deleteForEveryone failed: $e');
      return 'Failed to delete message.';
    }
  }

  // ── Typing indicator (Realtime broadcast, not persisted to the DB) ──────
  //
  // Exact match to the portal's Chat.tsx: 2s send throttle, 3s auto-clear on
  // the receiving side, cleared on thread switch/dispose.

  void _subscribeTyping() {
    if (isChannel) return; // portal has no typing indicator for channels
    _typingChannel = _supabase.channel('conversation:$threadId')
      ..onBroadcast(
        event: 'typing',
        callback: (payload) {
          if (payload['userId'] == userId) return;
          _otherTyping = true;
          _safeNotify();
          _typingClearTimer?.cancel();
          _typingClearTimer = Timer(const Duration(seconds: 3), () {
            _otherTyping = false;
            _safeNotify();
          });
        },
      )
      ..subscribe();
  }

  void notifyTyping() {
    if (isChannel) return;
    final channel = _typingChannel;
    if (channel == null) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingSentAt) < const Duration(seconds: 2)) return;
    _lastTypingSentAt = now;
    channel.sendBroadcastMessage(
      event: 'typing',
      payload: {'userId': userId},
    );
  }

  // ── Realtime (messages + reactions) ──────────────────────────────────────

  void _subscribe() {
    if (_realtime != null) return;

    final table = isChannel ? 'channel_messages' : 'messages';
    final column = isChannel ? 'channel_id' : 'conversation_id';
    final suffix = DateTime.now().microsecondsSinceEpoch;

    _realtime = _supabase.channel('thread-$threadId-$suffix')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: column,
          value: threadId,
        ),
        callback: (_) => _fetch(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'message_reactions',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'surface',
          value: _surface,
        ),
        callback: (_) => _refreshReactions(_messages.map((m) => m.id).toList())
            .then((_) => _safeNotify()),
      )
      ..subscribe();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _presence.detach();
    _typingClearTimer?.cancel();
    final channel = _realtime;
    if (channel != null) {
      _realtime = null;
      _supabase.removeChannel(channel);
    }
    final typing = _typingChannel;
    if (typing != null) {
      _typingChannel = null;
      _supabase.removeChannel(typing);
    }
    super.dispose();
  }
}
