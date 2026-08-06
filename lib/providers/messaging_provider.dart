import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/channel_summary.dart';
import '../models/conversation_summary.dart';
import '../services/messaging_service.dart';

/// State for the Messages list — the Chats and Channels tabs.
///
/// Follows the shape of `IndividualDashboardProvider` (blueprint §1.2.1). The
/// two tabs load independently so a failure in one never blanks the other.
///
/// Live updates mirror React: a Realtime subscription on `messages` and
/// `channel_messages` (the only two of these tables in the
/// `supabase_realtime` publication) refetches on any change, exactly as
/// useConversationUnreadCounts.ts and useUnreadMessages.ts do.
class MessagingProvider extends ChangeNotifier {
  MessagingProvider({MessagingService? service})
      : _service = service ?? MessagingService();

  final MessagingService _service;
  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _realtime;
  String? _userId;
  bool _disposed = false;

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
    _subscribe(userId);
    await Future.wait([_loadConversations(userId), _loadChannels(userId)]);
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await Future.wait([_loadConversations(userId), _loadChannels(userId)]);
  }

  Future<void> _loadConversations(String userId) async {
    _conversationsLoading = true;
    _conversationsFailed = false;
    _safeNotify();

    try {
      _conversations = await _service.listConversations(userId);
    } catch (e) {
      debugPrint('MessagingProvider._loadConversations failed: $e');
      _conversationsFailed = true;
      _conversations = const [];
    } finally {
      _conversationsLoading = false;
      _safeNotify();
    }
  }

  Future<void> _loadChannels(String userId) async {
    _channelsLoading = true;
    _channelsFailed = false;
    _safeNotify();

    try {
      _channels = await _service.listChannels(userId);
    } catch (e) {
      debugPrint('MessagingProvider._loadChannels failed: $e');
      _channelsFailed = true;
      _channels = const [];
    } finally {
      _channelsLoading = false;
      _safeNotify();
    }
  }

  /// Clears a conversation's badge locally so the list reflects the tap
  /// immediately; the authoritative update happens in the thread and the
  /// Realtime callback reconciles it.
  void clearConversationBadge(String conversationId) {
    _conversations = _conversations
        .map((c) => c.id == conversationId ? c.copyWith(unreadCount: 0) : c)
        .toList();
    _safeNotify();
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
