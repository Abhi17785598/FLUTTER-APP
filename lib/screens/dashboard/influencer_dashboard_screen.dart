import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/dashboard_analytics.dart';
import '../../providers/dashboard_analytics_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../providers/auth_provider.dart';
import '../../models/influencer_dashboard_model.dart';
import '../../services/influencer_dashboard_service.dart';
import '../widgets/influencer_stats_widget.dart';
import '../widgets/influencer_quick_actions_widget.dart';
import 'my_listings_section.dart';
import '../../widgets/shared/section_header_back_button.dart';
import 'widgets/dashboard_primitives.dart';
import 'widgets/dashboard_tab_bodies.dart';
import '../../core/widgets/segmented_tab_pill.dart';
import '../network/widgets/network_invitations_section.dart';
import 'widgets/my_videos_section.dart';

// ---------------------------------------------------------------------------
// PREMIUM PALETTE — keep this rich/deep across the whole gradient, no fading.
// ---------------------------------------------------------------------------
class _BrandGradient {
  // All four stay deep/saturated — c4 is only used for small accents
  // (icons, badges, glow blobs), never as a large gradient endpoint,
  // since a light endpoint is exactly what reads as "faded" at scale.
  // NOTE: the c1 anchor and the hero gradient were removed in Phase 3 with
  // the bespoke gradient header they existed for; DashboardHeaderBar replaced
  // it. c2/c3/c4 are still used by the FAB, cards and loading/error states.
  static const Color c2 = Color(0xFF3424C8); // base brand purple
  static const Color c4 = Color(0xFF6657FF); // accent only — icons/glows
}

/// The Influencer dashboard's four sections.
///
/// `InfluencerDashboardManage.tsx:95-110` — Analytics · Content · Audience ·
/// **Collaboration**. The fourth is the one Flutter's shared three-tab selector had
/// no room for.
///
/// Its own enum, like the builder's and the broker's, so the shared
/// `DashboardTabSelector` keeps serving Individual unchanged.
enum InfluencerSection { analytics, content, audience, collaboration }

/// Four labels over the app's existing segmented pill.
class InfluencerSectionSelector extends StatelessWidget {
  const InfluencerSectionSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final InfluencerSection selected;
  final ValueChanged<InfluencerSection> onChanged;

  static const _labels = <InfluencerSection, String>{
    InfluencerSection.analytics: 'Analytics',
    InfluencerSection.content: 'Content',
    InfluencerSection.audience: 'Audience',
    InfluencerSection.collaboration: 'Collabs',
  };

  @override
  Widget build(BuildContext context) {
    // "Collaboration" shortened to "Collabs" for the pill only; the section heading
    // inside the tab keeps the portal's full word.
    return SegmentedTabPill(
      labels: InfluencerSection.values.map((s) => _labels[s]!).toList(),
      selectedIndex: InfluencerSection.values.indexOf(selected),
      onChanged: (i) => onChanged(InfluencerSection.values[i]),
      labelFontSize: 11.5,
    );
  }
}

class InfluencerDashboardScreen extends StatelessWidget {
  const InfluencerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardAnalyticsProvider(
        // InfluencerAnalytics.tsx and InfluencerAudienceInsights.tsx both
        // read `influencer_videos`.
        analyticsSource: AnalyticsContentSource.influencerVideos,
        audienceSource: AnalyticsContentSource.influencerVideos,
        // Spec C: avgWatchTime and avgCompletionRate, the two metrics
        // InfluencerAnalytics.tsx derives from `influencer_video_views`.
        includeWatchMetrics: true,
      ),
      child: const _InfluencerDashboardView(),
    );
  }
}

class _InfluencerDashboardView extends StatefulWidget {
  const _InfluencerDashboardView();

  @override
  State<_InfluencerDashboardView> createState() => _InfluencerDashboardViewState();
}

class _InfluencerDashboardViewState extends State<_InfluencerDashboardView> {
  late Future<InfluencerDashboardModel> _dashboardFuture;

  /// Opens on Analytics, as the portal's Tabs default does.
  InfluencerSection _section = InfluencerSection.analytics;
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalytics());
  }

  Future<InfluencerDashboardModel> _loadDashboard() {
    final auth = context.read<AuthProvider>();
    return InfluencerDashboardService().getDashboardStats(auth.userId!);
  }

  /// Deferred to after the frame: `load()` notifies synchronously before its
  /// first await, which would mark this element dirty mid-build.
  void _loadAnalytics() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId == null || userId == _loadedUserId) return;
    _loadedUserId = userId;
    context.read<DashboardAnalyticsProvider>().load(userId);
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
    await Future.wait([
      _dashboardFuture,
      context.read<DashboardAnalyticsProvider>().refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.userId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      // Design places an icon-only square FAB on the Content tab only.
      floatingActionButton: _section == InfluencerSection.content
          // Design insets the FAB 20 dp from the right edge; Scaffold's
          // endFloat location defaults to 16.
          ? Padding(
              padding: const EdgeInsets.only(right: 4),
              child: DashboardCreateFab(
                semanticLabel: 'Upload video',
                onPressed: _onCreate,
              ),
            )
          : null,
      body: FutureBuilder<InfluencerDashboardModel>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(context);
          }

          final stats = snapshot.data;
          if (snapshot.hasError || stats == null) {
            return _buildErrorState(context);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const DashboardHeaderBar(
                            title: 'Manage Dashboard',
                            subtitle:
                                'Manage your content and track performance',
                          ),
                          const SizedBox(height: 18),
                          InfluencerSectionSelector(
                            selected: _section,
                            onChanged: (s) => setState(() => _section = s),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    child: _buildTabBody(context, stats, auth),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  /// Opens the influencer video form.
  ///
  /// Was [AppConstants.postPropertyScreen]. Every affordance this feeds already
  /// promised video — the FAB's semantic label is "Upload video" (:117), the
  /// Content tab's button reads "Upload Video" and its empty state reads "Upload
  /// Your First Video" (:203-204) — and all three opened the property listing
  /// wizard instead.
  void _onCreate() {
    Navigator.pushNamed(context, AppConstants.influencerVideoFormScreen);
  }

  /// One of the portal's four sections.
  Widget _buildTabBody(
    BuildContext context,
    InfluencerDashboardModel stats,
    AuthProvider auth,
  ) {
    final analytics = context.watch<DashboardAnalyticsProvider>();

    switch (_section) {
      // ── Analytics — `InfluencerAnalytics.tsx` ───────────────────────────
      case InfluencerSection.analytics:
        return DashboardAnalyticsBody(
          analytics: analytics.analytics,
          loading: analytics.analyticsLoading,
          failed: analytics.analyticsFailed,
          onRetry: analytics.refresh,
          showSavedProperties: analytics.includeSavedProperties,
        );

      // ── Content — `InfluencerContentManager.tsx` ────────────────────────
      case InfluencerSection.content:
        return DashboardContentBody(
          createLabel: 'Upload Video',
          emptyActionLabel: 'Upload Your First Video',
          onCreate: _onCreate,
          sections: [
            const DashboardSectionLabel('Overview'),
            const SizedBox(height: 10),
            InfluencerStatsWidget(stats: stats),
            const SizedBox(height: 22),
            const DashboardSectionLabel('Quick Actions'),
            const SizedBox(height: 10),
            const DashboardCard(child: InfluencerQuickActionsWidget()),
            const SizedBox(height: 22),
            const DashboardSectionLabel('My Videos'),
            const SizedBox(height: 10),
            MyVideosSection(userId: auth.userId!),
            const SizedBox(height: 22),
            // An influencer may list properties too — CreateContent.tsx:379-402
            // gives them three create buttons where other roles get two — so this
            // stays.
            const DashboardSectionLabel('My Listings'),
            const SizedBox(height: 10),
            MyListingsSection(userId: auth.userId!),
          ],
        );

      // ── Audience — `InfluencerAudienceInsights.tsx` ─────────────────────
      case InfluencerSection.audience:
        return DashboardAudienceBody(
          audience: analytics.audience,
          loading: analytics.audienceLoading,
          failed: analytics.audienceFailed,
          onRetry: analytics.refresh,
        );

      // ── Collaboration — `InfluencerCollaborationHub.tsx` ────────────────
      //
      // The portal's fourth tab, which the shared three-tab selector had no room
      // for. Both halves of that component already exist:
      //
      //   pending invitations + accept/reject → NetworkInvitationsSection (Spec F)
      //   accepted collaborations            → NetworkMembershipsSection, the same
      //                                        provider My Networks uses
      //
      // Reused as they are. Nothing new fetches anything.
      case InfluencerSection.collaboration:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardSectionLabel('Collaboration Invitations'),
            const SizedBox(height: 10),
            NetworkInvitationsSection(
              userId: auth.userId,
              // An accepted invitation becomes a `builder_networks` row, which is
              // what the memberships list below reads.
              onChanged: () => setState(() {}),
            ),
          ],
        );
    }
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: _BrandGradient.c2),
          const SizedBox(height: 16),
          Text(
            "Loading your dashboard...",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
    );
  }

  // ---------------- ERROR STATE ----------------

  Widget _buildErrorState(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFE4E4),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Color(0xFFE53935),
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              "Something went wrong",
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1C1530),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "We couldn't load your dashboard. Pull down to try again.",
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 22),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [_BrandGradient.c2, _BrandGradient.c4],
                ),
                boxShadow: [
                  BoxShadow(
                    color: _BrandGradient.c2.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: _refresh,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                ),
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: const Text(
                  "Retry",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}