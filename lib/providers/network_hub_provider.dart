import 'package:flutter/foundation.dart';

import '../models/network_stats.dart';
import '../services/network_service.dart';

/// Loads the Network hub's four KPIs.
///
/// Deliberately thin: the hub's navigation cards are static, so the only state
/// worth holding is the stats block plus its loading/failed flags. Mirrors
/// [MessagingProvider]'s shape so the two read the same way.
class NetworkHubProvider extends ChangeNotifier {
  /// Constructed lazily rather than in a field initialiser: [NetworkService]
  /// resolves `Supabase.instance.client` on construction, and this provider is
  /// created during `build`, before a widget test has any reason to have
  /// initialised Supabase.
  NetworkService? _service;
  NetworkService get _network => _service ??= NetworkService();

  NetworkStats _stats = NetworkStats.empty;
  bool _loading = true;
  bool _failed = false;
  bool _disposed = false;
  String? _userId;

  NetworkStats get stats => _stats;
  bool get loading => _loading;
  bool get failed => _failed;

  Future<void> load(String userId, {required bool isBuilder}) async {
    _userId = userId;
    _isBuilder = isBuilder;
    _loading = true;
    _failed = false;
    _safeNotify();

    try {
      _stats = await _network.getNetworkStats(userId, isBuilder: isBuilder);
      _failed = false;
    } catch (_) {
      // The hub renders an em dash per tile rather than a zero, so a failed
      // query is never mistaken for "you have no networks".
      _stats = NetworkStats.empty;
      _failed = true;
    } finally {
      _loading = false;
      _safeNotify();
    }
  }

  bool _isBuilder = false;

  Future<void> refresh() {
    final userId = _userId;
    if (userId == null) return Future.value();
    return load(userId, isBuilder: _isBuilder);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
