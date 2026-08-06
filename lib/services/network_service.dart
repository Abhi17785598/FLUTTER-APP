import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/network_models.dart';
import '../models/network_stats.dart';

/// Read-only reads for the Network feature.
///
/// Grew in three steps: the Profile screen's accepted-connection count
/// (blueprint §9), the hub's four KPIs (Phase 6), and the leaf screens'
/// memberships / leads / referrals / channels (Phase 9).
///
/// Every method is a `select`. All the Network writes React owns — accepting or
/// declining an invitation, assigning a lead, creating a referral or a channel,
/// sending a bulk message — stay with the web portal.
class NetworkService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Number of accepted network connections for [userId].
  ///
  /// Mirrors ProfileDashboardShell.tsx's `fetchNetworks` +
  /// `acceptedNetworks` — see blueprint §9. React selects every row the user
  /// participates in (as either `builder_id` or `member_id`) and then counts
  /// those with `status === 'accepted'`; a null status is treated as
  /// "pending", so filtering server-side on `status = 'accepted'` yields the
  /// same number without pulling the rows.
  Future<int> getAcceptedCount(String userId) async {
    try {
      final rows = await _supabase
          .from('builder_networks')
          .select('id')
          .or('member_id.eq.$userId,builder_id.eq.$userId')
          .eq('status', 'accepted');

      return (rows as List).length;
    } catch (e) {
      debugPrint('NetworkService.getAcceptedCount failed: $e');
      rethrow;
    }
  }

  /// The Network hub's four KPIs.
  ///
  /// A direct port of `NetworkDashboard.tsx`'s `fetchBuilderStats` /
  /// `fetchMemberStats`. React picks the branch on
  /// `profileData?.user_type === 'builder'`; the caller resolves the same flag
  /// from the already-loaded `AuthProvider.userType` rather than re-querying
  /// `profiles`, which React only reads because it has no auth store to ask.
  ///
  /// Read-only: three `select`s, no writes, no RPCs, and the same columns and
  /// filters the web portal already uses.
  Future<NetworkStats> getNetworkStats(
    String userId, {
    required bool isBuilder,
  }) async {
    try {
      // Builders own a network and see leads they have raised; members belong
      // to networks and see leads assigned to them. The column pairs differ
      // per branch, which is why React keeps two functions.
      final networkColumn = isBuilder ? 'builder_id' : 'member_id';
      final leadColumn = isBuilder ? 'builder_id' : 'assigned_member_id';
      final leadStatuses = isBuilder
          ? ['pending', 'assigned']
          : ['assigned', 'contacted'];

      // Local midnight on the 1st, then sent as UTC — the same instant React's
      // `setDate(1); setHours(0,0,0,0)` + `toISOString()` produces.
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month).toUtc();

      final results = await Future.wait([
        _supabase
            .from('builder_networks')
            .select('id')
            .eq(networkColumn, userId)
            .eq('status', 'accepted'),
        _supabase
            .from('network_leads')
            .select('id')
            .eq(leadColumn, userId)
            .inFilter('status', leadStatuses),
        _supabase
            .from('network_commissions')
            .select('amount')
            .eq(networkColumn, userId)
            .gte('created_at', startOfMonth.toIso8601String()),
      ]);

      final commissionRows = results[2] as List;
      final monthlyCommissions = commissionRows.fold<double>(
        0,
        (sum, row) =>
            sum +
            (double.tryParse('${(row as Map)['amount'] ?? 0}') ?? 0),
      );

      return NetworkStats(
        totalNetworks: (results[0] as List).length,
        activeLeads: (results[1] as List).length,
        // React: `const referralsCount = 0; // Temporarily disable this query`.
        // Deliberately not implemented here either — see [NetworkStats].
        totalReferrals: 0,
        monthlyCommissions: monthlyCommissions,
      );
    } catch (e) {
      debugPrint('NetworkService.getNetworkStats failed: $e');
      rethrow;
    }
  }

  /// The caller's network connections, from either side of the relationship.
  ///
  /// Ports `NetworkMemberships.tsx`'s membership fetch: `select *` filtered with
  /// `.or(member_id.eq.X, builder_id.eq.X)`, the same predicate
  /// [getAcceptedCount] already uses. Accepting or declining an invitation is a
  /// write and stays with the web portal.
  Future<List<NetworkMembership>> listMemberships(String userId) async {
    try {
      final rows = await _supabase
          .from('builder_networks')
          .select()
          .or('member_id.eq.$userId,builder_id.eq.$userId')
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) => NetworkMembership.fromJson(
                Map<String, dynamic>.from(r as Map),
                viewerId: userId,
              ))
          .toList();
    } catch (e) {
      debugPrint('NetworkService.listMemberships failed: $e');
      rethrow;
    }
  }

  /// Network leads visible to the caller.
  ///
  /// Builders see the leads they raised; members see the ones assigned to them.
  /// The column pair mirrors [getNetworkStats], which is how React splits the
  /// same query between its builder and member branches.
  Future<List<NetworkLead>> listLeads(
    String userId, {
    required bool isBuilder,
  }) async {
    try {
      final column = isBuilder ? 'builder_id' : 'assigned_member_id';
      final rows = await _supabase
          .from('network_leads')
          .select()
          .eq(column, userId)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) => NetworkLead.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('NetworkService.listLeads failed: $e');
      rethrow;
    }
  }

  /// Referrals, commissions and scored periods in one round trip.
  ///
  /// The Referrals screen's four sub-tabs all read from these three tables, so
  /// they are fetched together rather than re-querying per tab switch.
  ///
  /// Referrals are filtered on `referrer_id`: the screen is "My Referrals", the
  /// ones this user made. Commissions and performance use the builder/member
  /// column pair, same as everywhere else in this service.
  Future<ReferralBundle> getReferralBundle(
    String userId, {
    required bool isBuilder,
  }) async {
    try {
      final column = isBuilder ? 'builder_id' : 'member_id';

      final results = await Future.wait([
        _supabase
            .from('network_referrals')
            .select()
            .eq('referrer_id', userId)
            .order('created_at', ascending: false),
        _supabase
            .from('network_commissions')
            .select()
            .eq(column, userId)
            .order('created_at', ascending: false),
        _supabase
            .from('network_performance')
            .select()
            .eq(column, userId)
            .order('period_start', ascending: true),
      ]);

      return ReferralBundle(
        referrals: (results[0] as List)
            .map((r) =>
                NetworkReferral.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList(),
        commissions: (results[1] as List)
            .map((r) =>
                NetworkCommission.fromJson(Map<String, dynamic>.from(r as Map)))
            .toList(),
        performance: (results[2] as List)
            .map((r) => NetworkPerformance.fromJson(
                Map<String, dynamic>.from(r as Map)))
            .toList(),
      );
    } catch (e) {
      debugPrint('NetworkService.getReferralBundle failed: $e');
      rethrow;
    }
  }

  /// Channels attached to the caller's network.
  ///
  /// `network_channels` is keyed by `builder_id` only — a member has no rows of
  /// their own — so a member sees an empty list, which is the truthful answer
  /// rather than an error.
  Future<List<NetworkChannel>> listChannels(String builderId) async {
    try {
      final rows = await _supabase
          .from('network_channels')
          .select()
          .eq('builder_id', builderId)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) =>
              NetworkChannel.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('NetworkService.listChannels failed: $e');
      rethrow;
    }
  }
}
