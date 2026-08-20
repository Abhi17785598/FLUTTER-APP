import 'package:flutter/foundation.dart';

import '../models/network_relationship.dart';
import '../models/network_stats.dart';
import '../services/network_relationship_service.dart';
import '../services/network_service.dart';

/// Loads the Network hub's four KPIs.
///
/// Mirrors [MessagingProvider]'s shape, but the "networks" and "referrals"
/// tiles are no longer a straight pass-through of [NetworkService.
/// getNetworkStats] — see [load]'s own comment for why.
class NetworkHubProvider extends ChangeNotifier {
  NetworkHubProvider({
    NetworkService? service,
    NetworkRelationshipService? relationshipService,
  }) : _service = service,
       _relationshipService = relationshipService;

  /// Constructed lazily rather than in a field initialiser: [NetworkService]
  /// resolves `Supabase.instance.client` on construction, and this provider is
  /// created during `build`, before a widget test has any reason to have
  /// initialised Supabase.
  NetworkService? _service;
  NetworkService get _network => _service ??= NetworkService();

  NetworkRelationshipService? _relationshipService;
  NetworkRelationshipService get _relationships =>
      _relationshipService ??= NetworkRelationshipService();

  NetworkStats _stats = NetworkStats.empty;
  bool _loading = true;
  bool _failed = false;
  bool _disposed = false;
  String? _userId;

  NetworkStats get stats => _stats;
  bool get loading => _loading;
  bool get failed => _failed;
  bool get isBuilder => _isBuilder;

  /// [NetworkService.getNetworkStats] answers "networks" with a raw
  /// `builder_networks` accepted-count on whichever side [isBuilder] picks —
  /// which, because that table's RLS is fully symmetric and shared with the
  /// generic profile "Connect" flow, can include peer connections that are
  /// not genuine network memberships (see `network_relationship.dart`'s
  /// header). This re-derives that one number from [NetworkRelationshipService
  /// .listRelationships]'s classification instead, and also replaces the
  /// portal-inherited hardcoded `totalReferrals: 0` with a real count — every
  /// other figure ([NetworkService.getNetworkStats]'s leads/commissions) is
  /// unchanged and still comes from there.
  Future<void> load(String userId, {required bool isBuilder}) async {
    _userId = userId;
    _isBuilder = isBuilder;
    _loading = true;
    _failed = false;
    _safeNotify();

    try {
      final results = await Future.wait([
        _network.getNetworkStats(userId, isBuilder: isBuilder),
        _relationships.listRelationships(userId),
        _relationships.countReferralsMade(userId),
      ]);
      final baseStats = results[0] as NetworkStats;
      final relationships = results[1] as List<NetworkRelationship>;
      final referralsMade = results[2] as int;

      final wantedKind = isBuilder
          ? NetworkRelationshipKind.ownedNetworkMember
          : NetworkRelationshipKind.joinedBuilderNetwork;
      final networksCount = relationships
          .where((r) => r.kind == wantedKind)
          .length;

      _stats = NetworkStats(
        totalNetworks: networksCount,
        activeLeads: baseStats.activeLeads,
        totalReferrals: referralsMade,
        monthlyCommissions: baseStats.monthlyCommissions,
      );
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

  /// Re-runs [load] for the already-known user, reusing whichever `isBuilder`
  /// the last [load] call was given.
  ///
  /// This is *not* a re-derivation of the role from `AuthProvider` — this
  /// provider has no context to read it from. A caller that has since learned
  /// a fresher `isBuilder` (e.g. role resolution completed after this
  /// provider's first load, or the caller is reacting to a mutation whose
  /// outcome could change it) must call [load] directly with that value
  /// instead of this method, or the stale cached role will silently persist
  /// across the "refresh". See `network_hub_screen.dart`'s own
  /// `onNetworkChanged` wiring for the pattern.
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
