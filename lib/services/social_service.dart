import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/social_models.dart';

/// Read-only reads for the Social module.
///
/// Ports the query half of `src/services/social/*`:
///   - `socialAccountsService.getAccount` / `getPreferences`
///   - `analyticsService.getAnalytics`
///   - `campaignsService.listCampaigns`
///   - `adLeadsService.listLeads`
///   - `shareLoggerService.listLogs`
///
/// The write half is deliberately not ported. `savePreferences`,
/// `setAutoRefresh`, `updateLeadStatus`, `retryQueueItem` and every `meta-*`
/// Edge Function (OAuth exchange, campaign create, disconnect, sync) stay with
/// the web portal: connecting a Meta account needs a mobile OAuth strategy that
/// is still an open decision, and none of those writes is useful before an
/// account exists.
class SocialService {
  /// Resolved lazily so the class can be referenced without an initialised
  /// Supabase client.
  SupabaseClient get _supabase => Supabase.instance.client;

  /// The caller's Meta connection.
  ///
  /// Reads `social_accounts_safe`, never the base table: the base table carries
  /// the encrypted OAuth tokens and their IVs, and those must not reach a
  /// client. React reads the same view for the same reason.
  Future<SocialAccount?> getAccount(String userId) async {
    try {
      final row = await _supabase
          .from('social_accounts_safe')
          .select()
          .eq('user_id', userId)
          .eq('provider', 'meta')
          .maybeSingle();

      if (row == null) return null;
      return SocialAccount.fromJson(row);
    } catch (e) {
      debugPrint('SocialService.getAccount failed: $e');
      rethrow;
    }
  }

  /// Share preferences, falling back to React's `DEFAULT_PREFERENCES` when the
  /// user has never saved a row.
  Future<SocialPreferences> getPreferences(String userId) async {
    try {
      final row = await _supabase
          .from('social_share_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return SocialPreferences.defaults;
      return SocialPreferences.fromJson(row);
    } catch (e) {
      debugPrint('SocialService.getPreferences failed: $e');
      rethrow;
    }
  }

  /// The most recent publish records, newest first.
  Future<List<ShareLog>> listLogs(String userId, {int limit = 100}) async {
    try {
      final rows = await _supabase
          .from('social_share_logs')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List)
          .map((r) => ShareLog.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('SocialService.listLogs failed: $e');
      rethrow;
    }
  }

  /// Publishing analytics.
  ///
  /// React reads up to 500 logs and counts the queue separately; both are done
  /// here so the derivation stays identical.
  Future<SocialAnalytics> getAnalytics(String userId) async {
    try {
      final logs = await listLogs(userId, limit: 500);

      // `head: true` with an exact count returns the number without the rows.
      final pending = await _supabase
          .from('social_share_queue')
          .select('id')
          .eq('user_id', userId)
          .inFilter('status', ['queued', 'processing'])
          .count(CountOption.exact);

      return SocialAnalytics.fromLogs(logs, pending: pending.count);
    } catch (e) {
      debugPrint('SocialService.getAnalytics failed: $e');
      rethrow;
    }
  }

  Future<List<AdCampaign>> listCampaigns(String userId) async {
    try {
      final rows = await _supabase
          .from('social_ad_campaigns')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) => AdCampaign.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('SocialService.listCampaigns failed: $e');
      rethrow;
    }
  }

  Future<List<AdLead>> listLeads(String userId) async {
    try {
      final rows = await _supabase
          .from('social_ad_leads')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (rows as List)
          .map((r) => AdLead.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    } catch (e) {
      debugPrint('SocialService.listLeads failed: $e');
      rethrow;
    }
  }
}
