import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';
import '../models/conversation_summary.dart';
import '../services/messaging_service.dart';

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
  }) : _service = service ?? MessagingService();

  final ChatThreadKind kind;

  /// `conversation_id` or `channel_id` depending on [kind].
  final String threadId;

  final String userId;

  final MessagingService _service;
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _realtime;
  bool _disposed = false;

  List<ChatMessage> _messages = const [];
  Map<String, ConversationParticipant> _senders = const {};
  bool _loading = true;
  bool _failed = false;
  bool _sending = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get failed => _failed;
  bool get sending => _sending;
  bool get isChannel => kind == ChatThreadKind.channel;

  /// Sender profiles, populated for channel threads only — a 1:1 thread
  /// already knows who the other party is.
  ConversationParticipant? senderFor(String senderId) => _senders[senderId];

  Future<void> load() async {
    _subscribe();
    await _fetch();
    // Opening a thread clears its unread rows, matching both ChatModal.tsx
    // and ChannelChat.tsx.
    await _markRead();
  }

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    _loading = _messages.isEmpty;
    _failed = false;
    _safeNotify();

    try {
      final loaded = isChannel
          ? await _service.listChannelMessages(threadId)
          : await _service.listMessages(threadId);

      _messages = loaded;

      // Channel bubbles are attributed to a sender; resolve any we don't have.
      if (isChannel) {
        final missing = loaded
            .map((m) => m.senderId)
            .where((id) => id.isNotEmpty && !_senders.containsKey(id))
            .toSet();
        if (missing.isNotEmpty) {
          final fetched = await _service.fetchSenderProfiles(missing);
          _senders = {..._senders, ...fetched};
        }
      }
    } catch (e) {
      debugPrint('ChatThreadProvider._fetch failed: $e');
      _failed = true;
    } finally {
      _loading = false;
      _safeNotify();
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

  /// Sends [text]. Returns null on success, or an error message for the caller
  /// to surface in a snackbar (blueprint §12).
  Future<String?> send(String text) async {
    final body = text.trim();
    if (body.isEmpty || _sending) return null;

    _sending = true;
    _safeNotify();

    try {
      if (isChannel) {
        await _service.sendChannelMessage(
          channelId: threadId,
          senderId: userId,
          content: body,
        );
      } else {
        await _service.sendMessage(
          conversationId: threadId,
          senderId: userId,
          content: body,
        );
      }
      // React refetches after sending rather than appending optimistically;
      // the Realtime callback will also fire, and _fetch is idempotent.
      await _fetch();
      return null;
    } catch (e) {
      debugPrint('ChatThreadProvider.send failed: $e');
      return 'Message not sent. Check your connection and try again.';
    } finally {
      _sending = false;
      _safeNotify();
    }
  }

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
      ..subscribe();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    final channel = _realtime;
    if (channel != null) {
      _realtime = null;
      _supabase.removeChannel(channel);
    }
    super.dispose();
  }
}
