// providers/notification_provider.dart
//
// Notification Centre state: the list, the unread count, and the realtime channel.
//
// Mirrors what `hooks/useNotifications.ts` returns — `notifications`, `unreadCount`,
// `loading`, `markAsRead`, `markAsUnread`, `markAllAsRead` — minus
// `createNotification`, which five existing services already own and which Spec G is
// instructed not to duplicate.
//
// WHY APP-LEVEL AND NOT SCREEN-SCOPED
// -----------------------------------
// Every other provider in this app is created by the screen that needs it. This one
// is not, because two surfaces need the same count at the same time: the
// notifications screen and the unread badge on the home header. Two screen-scoped
// instances would open two channels and could disagree about the count.
//
// It is therefore registered once in `main.dart` alongside the other app-level
// providers, and `load()` is idempotent per user id so a rebuild does not re-fetch.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({NotificationService? service})
      : _service = service ?? NotificationService();

  final NotificationService _service;

  List<AppNotification> _items = const [];
  bool _loading = false;
  bool _failed = false;
  bool _disposed = false;

  String? _userId;
  RealtimeChannel? _channel;

  /// Newest first, as fetched.
  List<AppNotification> get items => _items;

  bool get loading => _loading;
  bool get failed => _failed;

  /// What the badge shows.
  ///
  /// Derived from the list rather than tracked as a separate counter. The portal
  /// keeps a `useState` count and adjusts it by ±1 on every action
  /// (`useNotifications.ts:57`, `:76`), which is how a count drifts out of step with
  /// the rows it is meant to describe — its own UPDATE listener has to recalculate
  /// from scratch to correct for exactly that (`:156`). Deriving cannot drift.
  int get unreadCount => _items.where((n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  /// Loads for [userId] and opens the realtime channel.
  ///
  /// Idempotent per user: a second call for the same id is ignored, so a widget
  /// rebuild does not re-fetch or open a second channel. Passing a different id —
  /// an account switch — tears the old channel down first.
  Future<void> load(String? userId) async {
    if (userId == null || userId.isEmpty) {
      _teardown();
      _items = const [];
      _userId = null;
      _loading = false;
      _failed = false;
      _safeNotify();
      return;
    }

    if (userId == _userId && _channel != null) return;

    if (userId != _userId) _teardown();
    _userId = userId;

    _loading = true;
    _failed = false;
    _safeNotify();

    try {
      _items = await _service.list(userId);
      _failed = false;
    } catch (e) {
      debugPrint('NotificationProvider.load failed: $e');
      _failed = true;
      _items = const [];
    } finally {
      _loading = false;
      _safeNotify();
    }

    _subscribe(userId);
  }

  /// Re-fetches for the current user. Used by pull-to-refresh and the retry button.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;

    _failed = false;
    _safeNotify();
    try {
      _items = await _service.list(userId);
    } catch (e) {
      debugPrint('NotificationProvider.refresh failed: $e');
      _failed = true;
    }
    _safeNotify();
  }

  void _subscribe(String userId) {
    if (_channel != null) return;
    try {
      _channel = _service.subscribe(
        userId: userId,
        // Distinct per provider instance. Two clients on one channel name receive
        // each other's broadcasts, which is why the portal randomises its own.
        channelSuffix: identityHashCode(this).toRadixString(36),
        onInsert: _onInserted,
        onUpdate: _onUpdated,
      );
    } catch (e) {
      // A failed subscription must not break the list, which is already loaded.
      // The user simply does not see live arrivals until the next refresh.
      debugPrint('NotificationProvider subscribe failed: $e');
    }
  }

  /// A new notification arrived.
  ///
  /// Prepended, not re-fetched: `REPLICA IDENTITY FULL` means the payload carries the
  /// whole row. Guarded against duplicates because an optimistic local insert and the
  /// broadcast for the same row would otherwise both land.
  void _onInserted(AppNotification notification) {
    if (_items.any((n) => n.id == notification.id)) return;
    _items = [notification, ..._items];
    _safeNotify();
  }

  /// An existing notification changed — usually `is_read`, possibly from another
  /// device.
  ///
  /// Replaced in place so ordering is preserved. Ignored when the row is not held:
  /// a row beyond the fifty fetched should not be spliced in out of order.
  void _onUpdated(AppNotification notification) {
    final index = _items.indexWhere((n) => n.id == notification.id);
    if (index < 0) return;
    final next = [..._items];
    next[index] = notification;
    _items = next;
    _safeNotify();
  }

  /// Marks one read, optimistically.
  ///
  /// The local flip lands first so the row stops looking unread the instant it is
  /// tapped, and is rolled back if the write fails. The realtime UPDATE for the same
  /// row arrives afterwards and is idempotent.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;

    _replace(notification.id, isRead: true);
    try {
      await _service.markRead(notification.id);
    } catch (e) {
      debugPrint('NotificationProvider.markRead failed: $e');
      _replace(notification.id, isRead: false);
    }
  }

  /// Marks one unread again.
  Future<void> markUnread(AppNotification notification) async {
    if (!notification.isRead) return;

    _replace(notification.id, isRead: false);
    try {
      await _service.markUnread(notification.id);
    } catch (e) {
      debugPrint('NotificationProvider.markUnread failed: $e');
      _replace(notification.id, isRead: true);
    }
  }

  /// Marks every unread notification read.
  ///
  /// The previous list is kept so a failed write restores the exact prior state
  /// rather than guessing which rows had been unread.
  Future<void> markAllRead() async {
    final userId = _userId;
    if (userId == null || unreadCount == 0) return;

    final previous = _items;
    _items = _items.map((n) => n.isRead ? n : n.copyWith(isRead: true)).toList();
    _safeNotify();

    try {
      await _service.markAllRead(userId);
    } catch (e) {
      debugPrint('NotificationProvider.markAllRead failed: $e');
      _items = previous;
      _safeNotify();
    }
  }

  void _replace(String id, {required bool isRead}) {
    final index = _items.indexWhere((n) => n.id == id);
    if (index < 0) return;
    final next = [..._items];
    next[index] = next[index].copyWith(isRead: isRead);
    _items = next;
    _safeNotify();
  }

  void _teardown() {
    final channel = _channel;
    _channel = null;
    if (channel != null) _service.unsubscribe(channel);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _teardown();
    super.dispose();
  }
}
