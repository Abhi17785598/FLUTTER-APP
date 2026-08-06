import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_analytics.dart';

/// Read-only analytics for the Manage Dashboard.
///
/// Ported from the React portal's `features/analytics/*` — see blueprint §9.
/// The three Analytics files (`IndividualAnalytics.tsx`,
/// `BrokerAnalytics.tsx`, `InfluencerAnalytics.tsx`) and the three Audience
/// files (`IndividualAudienceInsights.tsx`, `BrokerAudienceInsights.tsx`,
/// `InfluencerAudienceInsights.tsx`) apply identical formulas and differ only
/// in which table holds the user's content, so both are expressed once here
/// with an [AnalyticsContentSource].
///
/// No schema, RLS, API or business-logic change: every call below is a SELECT.
class DashboardAnalyticsService {
  /// Resolved on first use rather than at construction, so the service (and the
  /// provider that owns one) can be instantiated in a widget test without a
  /// live `Supabase.initialize`.
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Days in the performance window. React groups the last 30 days; the design
  /// shows a seven-point Mon–Sun axis, so the same per-day aggregation is
  /// rendered over the last seven days.
  static const int performanceWindowDays = 7;

  /// Days in the follower-growth series, matching React's
  /// `for (let i = 30; i >= 0; i--)` loop — 31 points.
  static const int followerWindowDays = 30;

  // ── Analytics tab ─────────────────────────────────────────────────────────

  /// Mirrors `fetchAnalytics` in the three `*Analytics.tsx` files.
  ///
  /// [includeSavedProperties] reflects that only `IndividualAnalytics.tsx`
  /// queries `saved_properties`; the other roles leave that tile at zero.
  /// [growthFromContent] reflects that `BrokerAnalytics.tsx` deliberately
  /// hard-codes its growth figures to 0, noting that real growth needs
  /// historical engagement tracking.
  Future<DashboardAnalytics> fetchAnalytics({
    required String userId,
    required AnalyticsContentSource source,
    bool includeSavedProperties = false,
    bool growthFromContent = true,
  }) async {
    try {
      final rows = await _supabase
          .from(source.table)
          .select('id, title, views, likes, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final content = List<Map<String, dynamic>>.from(rows as List);

      // React returns early with all-zero state when the user has no content.
      if (content.isEmpty) return DashboardAnalytics.empty;

      final totalViews = _sum(content, 'views');
      final totalLikes = _sum(content, 'likes');
      final avgEngagement =
          totalViews > 0 ? (totalLikes / totalViews) * 100 : 0.0;

      var totalSaved = 0;
      if (includeSavedProperties) {
        final saved = await _supabase
            .from('saved_properties')
            .select('id')
            .eq('user_id', userId);
        totalSaved = (saved as List).length;
      }

      double viewsGrowth = 0;
      double likesGrowth = 0;
      if (growthFromContent) {
        viewsGrowth = _growth(content, 'views');
        likesGrowth = _growth(content, 'likes');
      }

      // Top 5 by views, descending — React's `.sort(...).slice(0, 5)`.
      final sorted = List<Map<String, dynamic>>.from(content)
        ..sort((a, b) => _int(b['views']).compareTo(_int(a['views'])));

      final topContent = sorted
          .take(5)
          .map(
            (row) => TopContentItem(
              id: row['id'].toString(),
              title: (row['title'] as String?)?.trim().isNotEmpty == true
                  ? row['title'] as String
                  : 'Untitled',
              views: _int(row['views']),
              likes: _int(row['likes']),
            ),
          )
          .toList();

      return DashboardAnalytics(
        totalViews: totalViews,
        totalLikes: totalLikes,
        totalSaved: totalSaved,
        avgEngagement: avgEngagement,
        totalInteractions: totalViews + totalLikes,
        // React shows `topContent.length` here, which its own `.slice(0, 5)`
        // caps at five. The tile is labelled "Total posts", so the real count
        // is used instead — the same call made for the article-edit RLS quirk.
        contentPosted: content.length,
        viewsGrowth: viewsGrowth,
        likesGrowth: likesGrowth,
        topContent: topContent,
        performance: _dailySeries(content, 'views', performanceWindowDays),
      );
    } catch (e) {
      debugPrint('DashboardAnalyticsService.fetchAnalytics failed: $e');
      rethrow;
    }
  }

  // ── Audience tab ──────────────────────────────────────────────────────────

  /// Mirrors `fetchAudienceInsights` in the three `*AudienceInsights.tsx`
  /// files.
  ///
  /// Followers come from the `followers` table keyed on `following_id`, which
  /// is what all three React audience files read. (The Profile screen's
  /// Followers tile intentionally stays on `builder_networks`, because
  /// `ProfileDashboardShell.tsx` — its own reference — uses that instead.)
  Future<DashboardAudience> fetchAudience({
    required String userId,
    required AnalyticsContentSource source,
  }) async {
    try {
      final followerRows = await _supabase
          .from('followers')
          .select('created_at')
          .eq('following_id', userId);

      final followers = List<Map<String, dynamic>>.from(followerRows as List);
      final totalFollowers = followers.length;

      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      final fourteenDaysAgo = now.subtract(const Duration(days: 14));

      final recent = followers.where((f) {
        final d = _date(f['created_at']);
        return d != null && !d.isBefore(sevenDaysAgo);
      }).length;

      final previous = followers.where((f) {
        final d = _date(f['created_at']);
        return d != null &&
            !d.isBefore(fourteenDaysAgo) &&
            d.isBefore(sevenDaysAgo);
      }).length;

      // React's audience fallback differs from its analytics one: with no
      // previous window it returns 100 when there were recent followers.
      final followersGrowth = previous > 0
          ? ((recent - previous) / previous) * 100
          : (recent > 0 ? 100.0 : 0.0);

      final contentRows = await _supabase
          .from(source.table)
          .select('views, likes')
          .eq('user_id', userId);

      final content = List<Map<String, dynamic>>.from(contentRows as List);
      final totalViews = _sum(content, 'views');
      final totalLikes = _sum(content, 'likes');

      return DashboardAudience(
        totalFollowers: totalFollowers,
        followersGrowth: followersGrowth,
        totalViews: totalViews,
        avgViewsPerPost:
            content.isNotEmpty ? totalViews / content.length : 0.0,
        engagementRate: totalViews > 0 ? (totalLikes / totalViews) * 100 : 0.0,
        followerGrowth: _cumulativeFollowerSeries(
          followers: followers,
          totalFollowers: totalFollowers,
          recentCount: recent,
          now: now,
        ),
      );
    } catch (e) {
      debugPrint('DashboardAnalyticsService.fetchAudience failed: $e');
      rethrow;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int _sum(List<Map<String, dynamic>> rows, String key) =>
      rows.fold<int>(0, (total, row) => total + _int(row[key]));

  /// `prev > 0 ? ((recent - prev) / prev) * 100 : 0` over the two trailing
  /// 7-day windows — React's analytics growth formula.
  double _growth(List<Map<String, dynamic>> rows, String key) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));

    var recent = 0;
    var previous = 0;

    for (final row in rows) {
      final created = _date(row['created_at']);
      if (created == null) continue;
      final value = _int(row[key]);

      if (!created.isBefore(sevenDaysAgo)) {
        recent += value;
      } else if (!created.isBefore(fourteenDaysAgo)) {
        previous += value;
      }
    }

    if (previous <= 0) return 0;
    return ((recent - previous) / previous) * 100;
  }

  /// Per-day totals for the trailing [days] window, oldest first.
  ///
  /// Same aggregation React performs — bucket content by its `created_at` day
  /// and sum the metric — with every day in the window present so the chart
  /// has a fixed number of points.
  List<ChartPoint> _dailySeries(
    List<Map<String, dynamic>> rows,
    String key,
    int days,
  ) {
    final today = DateTime.now();
    final buckets = <DateTime, double>{};

    for (var i = days - 1; i >= 0; i--) {
      final day = _dayOnly(today.subtract(Duration(days: i)));
      buckets[day] = 0;
    }

    for (final row in rows) {
      final created = _date(row['created_at']);
      if (created == null) continue;
      final day = _dayOnly(created);
      if (buckets.containsKey(day)) {
        buckets[day] = buckets[day]! + _int(row[key]);
      }
    }

    return buckets.entries
        .map((e) => ChartPoint(date: e.key, value: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// 31 cumulative points, starting from the follower count that predates the
  /// window — React's `cumulative = totalFollowers - recentFollowers`.
  List<ChartPoint> _cumulativeFollowerSeries({
    required List<Map<String, dynamic>> followers,
    required int totalFollowers,
    required int recentCount,
    required DateTime now,
  }) {
    final perDay = <DateTime, int>{};
    for (var i = followerWindowDays; i >= 0; i--) {
      perDay[_dayOnly(now.subtract(Duration(days: i)))] = 0;
    }

    for (final follower in followers) {
      final created = _date(follower['created_at']);
      if (created == null) continue;
      final day = _dayOnly(created);
      if (perDay.containsKey(day)) perDay[day] = perDay[day]! + 1;
    }

    final days = perDay.keys.toList()..sort();
    var cumulative = (totalFollowers - recentCount).toDouble();

    return days.map((day) {
      cumulative += perDay[day]!;
      return ChartPoint(date: day, value: cumulative);
    }).toList();
  }

  static DateTime _dayOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static DateTime? _date(dynamic value) {
    if (value is String) return DateTime.tryParse(value);
    if (value is DateTime) return value;
    return null;
  }
}
