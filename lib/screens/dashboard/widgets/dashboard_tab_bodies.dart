import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/dashboard_analytics.dart';
import 'audience_insights_card.dart';
import '../../../widgets/shared/app_chart_wrapper.dart';
import 'dashboard_primitives.dart';
import '../../../widgets/shared/stat_kpi_card.dart';
import 'top_content_list.dart';

/// `1240` → `1,240`, matching React's `toLocaleString()` and the design's
/// thousands separators. Deliberately not the Profile screen's `2.3K` style —
/// the dashboard design shows full numbers.
String formatThousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return '${value < 0 ? '-' : ''}$buffer';
}

/// Analytics tab body — six metric tiles, the performance chart and the
/// top-content list, in the design's order and spacing.
class DashboardAnalyticsBody extends StatelessWidget {
  final DashboardAnalytics analytics;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  const DashboardAnalyticsBody({
    super.key,
    required this.analytics,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const MetricCardGridShimmer(count: 6);

    if (failed) {
      return DashboardEmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load analytics",
        message: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricCardGrid(
          cards: [
            MetricCard(
              icon: Icons.visibility_outlined,
              value: formatThousands(analytics.totalViews),
              label: 'Total Views',
            ),
            MetricCard(
              icon: Icons.favorite_border,
              value: formatThousands(analytics.totalLikes),
              label: 'Total Likes',
            ),
            MetricCard(
              icon: Icons.bookmark_border_rounded,
              value: formatThousands(analytics.totalSaved),
              label: 'Saved Properties',
            ),
            MetricCard(
              icon: Icons.trending_up_rounded,
              // React's card renders two decimals; the design shows one.
              value: '${analytics.avgEngagement.toStringAsFixed(1)}%',
              label: 'Avg Engagement',
            ),
            MetricCard(
              icon: Icons.people_outline,
              value: formatThousands(analytics.totalInteractions),
              label: 'Total Interactions',
            ),
            MetricCard(
              icon: Icons.description_outlined,
              value: formatThousands(analytics.contentPosted),
              label: 'Content Posted',
            ),
          ],
        ),
        const SizedBox(height: 18),
        DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DashboardCardTitle('Performance Over Time'),
              const SizedBox(height: AppConstants.spacingM),
              DashboardLineChart(
                points: analytics.performance,
                height: 120,
                showDayLabels: true,
                emptyMessage: 'No performance data yet',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const DashboardSectionLabel('Top Performing Content'),
        const SizedBox(height: 10),
        if (analytics.topContent.isEmpty)
          DashboardCard(
            child: DashboardEmptyState(
              icon: Icons.insights_outlined,
              title: 'No content yet',
              message: 'Start posting to see which content performs best.',
            ),
          )
        else
          TopContentList(items: analytics.topContent),
      ],
    );
  }
}

/// Audience tab body — four metric tiles, the follower-growth chart and the
/// insights list.
class DashboardAudienceBody extends StatelessWidget {
  final DashboardAudience audience;
  final bool loading;
  final bool failed;
  final VoidCallback onRetry;

  const DashboardAudienceBody({
    super.key,
    required this.audience,
    required this.loading,
    required this.failed,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const MetricCardGridShimmer(count: 4);

    if (failed) {
      return DashboardEmptyState(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load audience data",
        message: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }

    final growth = audience.followersGrowth;
    final growthLabel =
        '${growth >= 0 ? '+' : ''}${growth.toStringAsFixed(0)}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricCardGrid(
          cards: [
            MetricCard(
              icon: Icons.people_outline,
              value: formatThousands(audience.totalFollowers),
              label: 'Total Followers',
            ),
            MetricCard(
              icon: Icons.visibility_outlined,
              value: formatThousands(audience.totalViews),
              label: 'Total Views',
            ),
            MetricCard(
              icon: Icons.grid_view_rounded,
              value: formatThousands(audience.avgViewsPerPost.round()),
              label: 'Avg Views/Post',
            ),
            MetricCard(
              icon: Icons.percent_rounded,
              value: '${audience.engagementRate.toStringAsFixed(1)}%',
              label: 'Engagement Rate',
            ),
          ],
        ),
        const SizedBox(height: 18),
        DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DashboardCardTitle('Follower Growth'),
              const SizedBox(height: AppConstants.spacingM),
              DashboardLineChart(
                points: audience.followerGrowth,
                height: 100,
                // The prototype fills this one with the lighter accent.
                areaColor: Color(0xFF7C72F0),
                emptyMessage: 'No follower data yet',
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const DashboardSectionLabel('Audience Insights'),
        const SizedBox(height: 10),
        AudienceInsightsCard(
          rows: [
            AudienceInsightRow(
              icon: Icons.trending_up_rounded,
              label: 'Avg Engagement',
              value: '${audience.engagementRate.toStringAsFixed(1)}%',
            ),
            AudienceInsightRow(
              icon: Icons.people_outline,
              label: 'Follower Growth',
              value: growthLabel,
            ),
            AudienceInsightRow(
              icon: Icons.visibility_outlined,
              label: 'Total Reach',
              value: formatThousands(audience.totalViews),
            ),
            AudienceInsightRow(
              icon: Icons.person_outline,
              label: 'Audience Size',
              value: formatThousands(audience.totalFollowers),
            ),
          ],
        ),
      ],
    );
  }
}

/// Content Manager tab body — the design's "Content Library" header over each
/// role's own content sections.
///
/// [sections] receives the role's existing, working widgets (Quick Actions,
/// Recent Properties/Projects/Campaigns, My Listings) unchanged, so no
/// functionality is lost; only the surrounding presentation is the design's.
/// When a role has nothing to show, [isEmpty] swaps in the design's empty state.
class DashboardContentBody extends StatelessWidget {
  final VoidCallback? onCreate;
  final String createLabel;
  final bool isEmpty;
  final String emptyTitle;
  final String emptyMessage;
  final String emptyActionLabel;
  final List<Widget> sections;

  const DashboardContentBody({
    super.key,
    required this.onCreate,
    required this.sections,
    this.createLabel = 'Create Post',
    this.isEmpty = false,
    this.emptyTitle = 'No posts yet',
    this.emptyMessage = 'Start creating content to build your presence',
    this.emptyActionLabel = 'Create Your First Post',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ContentLibraryHeader(
          actionLabel: createLabel,
          onAction: onCreate,
        ),
        if (isEmpty) ...[
          // Prototype puts 44 dp between the header row and the empty state.
          const SizedBox(height: 44),
          // Full width so the centred empty state is not left-aligned by the
          // surrounding start-aligned Column.
          SizedBox(
            width: double.infinity,
            child: DashboardEmptyState(
              icon: Icons.description_outlined,
              title: emptyTitle,
              message: emptyMessage,
              actionLabel: emptyActionLabel,
              onAction: onCreate,
            ),
          ),
        ] else ...[
          const SizedBox(height: 18),
          ...sections,
        ],
      ],
    );
  }
}

