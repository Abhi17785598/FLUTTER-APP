import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/channel_summary.dart';
import '../models/conversation_summary.dart';
import '../services/messaging_service.dart';
import '../services/presence_service.dart';

/// State for the Messages list — the Chats and Channels tabs.
///
/// Follows the shape of `IndividualDashboardProvider` (blueprint §1.2.1). The
/// two tabs load independently so a failure in one never blanks the other.
///
/// Live updates mirror React: a Realtime subscription on `messages` and
/// `channel_messages` refetches on any change, exactly as
/// useConversationUnreadCounts.ts and useUnreadMessages.ts do.
class MessagingProvider extends ChangeNotifier {
  MessagingProvider({MessagingService? service})
      : _service = service ?? MessagingService();

  final MessagingService _service;
  final SupabaseClient _supabase = Supabase.instance.client;
  final PresenceService _presence = PresenceService();

  RealtimeChannel? _realtime;
  String? _userId;
  bool _disposed = false;

  /// Discards a slow response if a newer load/refresh has since started, so a
  /// realtime-triggered refresh racing with a pull-to-refresh can't clobber a
  /// more recent result with a stale one.
  int _conversationsRequestId = 0;
  int _channelsRequestId = 0;

  List<ConversationSummary> _conversations = const [];
  bool _conversationsLoading = true;
  bool _conversationsFailed = false;

  List<ChannelSummary> _channels = const [];
  bool _channelsLoading = true;
  bool _channelsFailed = false;

  List<ConversationSummary> get conversations =>
      List.unmodifiable(_conversations);
  bool get conversationsLoading => _conversationsLoading;
  bool get conversationsFailed => _conversationsFailed;

  List<ChannelSummary> get channels => List.unmodifiable(_channels);
  bool get channelsLoading => _channelsLoading;
  bool get channelsFailed => _channelsFailed;

  Future<void> load(String userId) async {
    _userId = userId;
    _presence.attach();
    _subscribe(userId);
    await Future.wait([_loadConversations(userId), _loadChannels(userId)]);
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await Future.wait([_loadConversations(userId), _loadChannels(userId)]);
  }

  Future<void> _loadConversations(String userId) async {
    final requestId = ++_conversationsRequestId;
    final hadData = _conversations.isNotEmpty;
    _conversationsLoading = true;
    // A transient refresh failure must not wipe an already-populated list —
    // only a genuine first load starts from "failed" being meaningful as
    // "nothing to show".
    if (!hadData) _conversationsFailed = false;
    _safeNotify();

    try {
      final loaded = await _service.listConversations(userId);
      if (requestId != _conversationsRequestId) return;
      _conversations = loaded;
      _conversationsFailed = false;
    } catch (e) {
      if (requestId != _conversationsRequestId) return;
      debugPrint('MessagingProvider._loadConversations failed: $e');
      if (!hadData) {
        _conversationsFailed = true;
        _conversations = const [];
      }
      // else: keep showing the last-known-good list; the pull-to-refresh
      // spinner simply stops with nothing changed.
    } finally {
      if (requestId == _conversationsRequestId) {
        _conversationsLoading = false;
        _safeNotify();
      }
    }
  }

  Future<void> _loadChannels(String userId) async {
    final requestId = ++_channelsRequestId;
    final hadData = _channels.isNotEmpty;
    _channelsLoading = true;
    if (!hadData) _channelsFailed = false;
    _safeNotify();

    try {
      final loaded = await _service.listChannels(userId);
      if (requestId != _channelsRequestId) return;
      _channels = loaded;
      _channelsFailed = false;
    } catch (e) {
      if (requestId != _channelsRequestId) return;
      debugPrint('MessagingProvider._loadChannels failed: $e');
      if (!hadData) {
        _channelsFailed = true;
        _channels = const [];
      }
    } finally {
      if (requestId == _channelsRequestId) {
        _channelsLoading = false;
        _safeNotify();
      }
    }
  }

  /// Clears a conversation's badge locally so the list reflects the tap
  /// immediately; the authoritative update happens in the thread and the
  /// Realtime callback reconciles it. Returns the prior count so a failed
  /// mark-as-read can be rolled back with [restoreConversationBadge].
  int clearConversationBadge(String conversationId) {
    var prior = 0;
    _conversations = _conversations.map((c) {
      if (c.id != conversationId) return c;
      prior = c.unreadCount;
      return c.copyWith(unreadCount: 0);
    }).toList();
    _safeNotify();
    return prior;
  }

  /// Rolls back an optimistic [clearConversationBadge] when the thread's own
  /// mark-as-read call actually failed, so the badge doesn't lie about
  /// unread state until the next full refresh.
  void restoreConversationBadge(String conversationId, int count) {
    if (count <= 0) return;
    _conversations = _conversations
        .map((c) => c.id == conversationId ? c.copyWith(unreadCount: count) : c)
        .toList();
    _safeNotify();
  }

  Future<String?> acceptRequest(String conversationId) async {
    try {
      await _service.acceptConversationRequest(conversationId);
      _conversations = _conversations
          .map((c) => c.id == conversationId
              ? c.copyWith(requestStatus: 'accepted')
              : c)
          .toList();
      _safeNotify();
      return null;
    } catch (e) {
      debugPrint('MessagingProvider.acceptRequest failed: $e');
      return "Couldn't accept the request.";
    }
  }

  /// Declining a request is implemented as "hide conversation for me",
  /// matching the portal exactly — the sender is never notified.
  Future<String?> declineRequest(String conversationId) async {
    try {
      await _service.hideConversation(conversationId);
      _conversations = _conversations.where((c) => c.id != conversationId).toList();
      _safeNotify();
      return null;
    } catch (e) {
      debugPrint('MessagingProvider.declineRequest failed: $e');
      return "Couldn't decline the request.";
    }
  }

  Future<String?> setConversationMuted(String conversationId, bool muted) async {
    try {
      await _service.setConversationMuted(conversationId, muted);
      _conversations = _conversations
          .map((c) => c.id == conversationId ? c.copyWith(isMuted: muted) : c)
          .toList();
      _safeNotify();
      return null;
    } catch (e) {
      debugPrint('MessagingProvider.setConversationMuted failed: $e');
      return "Couldn't update mute setting.";
    }
  }

  void _subscribe(String userId) {
    if (_realtime != null) return;

    // Channel names must be unique per subscriber; React appends a random
    // suffix for the same reason.
    final suffix = DateTime.now().microsecondsSinceEpoch;
    _realtime = _supabase.channel('messages-list-$userId-$suffix')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'messages',
        callback: (_) => refresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'channel_messages',
        callback: (_) => refresh(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'conversation_participants',
        callback: (_) => refresh(),
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
    final channel = _realtime;
    if (channel != null) {
      _realtime = null;
      _supabase.removeChannel(channel);
    }
    super.dispose();
  }
}
