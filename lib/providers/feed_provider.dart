// providers/feed_provider.dart
import 'package:flutter/foundation.dart';

import '../models/feed_item.dart';
import '../services/feed_service.dart';

class FeedProvider extends ChangeNotifier {
  final FeedService _service = FeedService();

  List<FeedItem> _items = const [];
  bool _isLoading = true;
  String? _error;
  FeedRoleFilter _filter = FeedRoleFilter.all;
  String? _currentUserId;

  bool get isLoading => _isLoading;
  String? get error => _error;
  FeedRoleFilter get filter => _filter;

  /// Items matching the active filter — recomputed on every read rather than
  /// cached, since the source list only changes on [load] and the filter
  /// only changes on [setFilter], both of which already call
  /// [notifyListeners].
  List<FeedItem> get visibleItems => _items
      .where((item) => item.matchesFilter(_filter, _currentUserId))
      .toList();

  Future<void> load(String? currentUserId) async {
    _currentUserId = currentUserId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _service.fetchFeed();
    } catch (e) {
      _error = 'Failed to load feed';
      _items = const [];
    }

    _isLoading = false;
    notifyListeners();
  }

  void setFilter(FeedRoleFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    notifyListeners();
  }
}
