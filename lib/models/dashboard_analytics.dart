/// Which table a role's "content" lives in.
///
/// React uses a different source per role but an identical set of formulas:
/// `BrokerAnalytics.tsx` and the audience variants read `properties`, while
/// `InfluencerAnalytics.tsx` and `IndividualAnalytics.tsx` read
/// `influencer_videos`. Modelling it as a source keeps one code path.
enum AnalyticsContentSource {
  properties,
  influencerVideos;

  String get table => switch (this) {
        AnalyticsContentSource.properties => 'properties',
        AnalyticsContentSource.influencerVideos => 'influencer_videos',
      };
}

/// One point in a dashboard chart series.
class ChartPoint {
  final DateTime date;
  final double value;

  const ChartPoint({required this.date, required this.value});
}

/// The Analytics tab's six metrics, plus its chart and top-content list.
///
/// Mirrors the state assembled by `IndividualAnalytics.tsx` /
/// `BrokerAnalytics.tsx` / `InfluencerAnalytics.tsx`.
class DashboardAnalytics {
  final int totalViews;
  final int totalLikes;

  /// `saved_properties` row count. Only `IndividualAnalytics.tsx` computes
  /// this; the other roles leave it at zero, as React does.
  final int totalSaved;

  /// `(totalLikes / totalViews) * 100`, or 0 when there are no views.
  final double avgEngagement;

  /// `totalViews + totalLikes`.
  final int totalInteractions;

  /// Number of content rows the user owns.
  final int contentPosted;

  /// Last 7 days vs the 7 before, as a percentage. `BrokerAnalytics.tsx`
  /// hard-codes these to 0 with the comment that growth needs historical
  /// engagement tracking, so brokers keep 0.
  final double viewsGrowth;
  final double likesGrowth;

  /// Top 5 by views, descending.
  final List<TopContentItem> topContent;

  /// Seven points ending today — the window the design's Mon–Sun axis shows.
  final List<ChartPoint> performance;

  const DashboardAnalytics({
    this.totalViews = 0,
    this.totalLikes = 0,
    this.totalSaved = 0,
    this.avgEngagement = 0,
    this.totalInteractions = 0,
    this.contentPosted = 0,
    this.viewsGrowth = 0,
    this.likesGrowth = 0,
    this.topContent = const [],
    this.performance = const [],
  });

  static const DashboardAnalytics empty = DashboardAnalytics();

  bool get hasPerformanceData =>
      performance.any((p) => p.value > 0);
}

/// The Audience tab's four metrics, its chart and its insight rows.
///
/// Mirrors `IndividualAudienceInsights.tsx` / `BrokerAudienceInsights.tsx` /
/// `InfluencerAudienceInsights.tsx`, which are identical apart from the
/// content table they read.
class DashboardAudience {
  final int totalFollowers;

  /// Last 7 days vs the 7 before. React's fallback differs from the analytics
  /// one: when there is no previous window it returns 100 if there were any
  /// recent followers, else 0.
  final double followersGrowth;

  final int totalViews;

  /// `totalViews / contentCount`, rounded for display.
  final double avgViewsPerPost;

  /// `(totalLikes / totalViews) * 100`.
  final double engagementRate;

  /// 31 cumulative points, matching React's `for (let i = 30; i >= 0; i--)`
  /// loop. Rendered unlabelled, as the design shows.
  final List<ChartPoint> followerGrowth;

  const DashboardAudience({
    this.totalFollowers = 0,
    this.followersGrowth = 0,
    this.totalViews = 0,
    this.avgViewsPerPost = 0,
    this.engagementRate = 0,
    this.followerGrowth = const [],
  });

  static const DashboardAudience empty = DashboardAudience();

  bool get hasGrowthData => followerGrowth.any((p) => p.value > 0);
}

/// One row of "Top Performing Content".
class TopContentItem {
  final String id;
  final String title;
  final int views;
  final int likes;

  const TopContentItem({
    required this.id,
    required this.title,
    this.views = 0,
    this.likes = 0,
  });
}
