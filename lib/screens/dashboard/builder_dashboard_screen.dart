import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../models/dashboard_analytics.dart';
import '../../providers/dashboard_analytics_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../providers/auth_provider.dart';
import '../../models/builder_dashboard_model.dart';
import '../../services/builder_dashboard_service.dart';
import '../widgets/builder_stats_widget.dart';
import '../widgets/builder_recent_projects_widget.dart';
import '../widgets/builder_quick_actions_widget.dart';
import 'my_listings_section.dart';
import '../../widgets/shared/section_header_back_button.dart';
import 'widgets/dashboard_primitives.dart';
import 'widgets/dashboard_tab_bodies.dart';
import 'widgets/dashboard_tab_selector.dart';

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

class BuilderDashboardScreen extends StatelessWidget {
  const BuilderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DashboardAnalyticsProvider(
        // No BuilderAnalytics/BuilderAudienceInsights exists in the React
        // portal, so builder mirrors the broker path -- builders own
        // `properties` rows too. Flagged as the one inference.
        analyticsSource: AnalyticsContentSource.properties,
        audienceSource: AnalyticsContentSource.properties,
      ),
      child: const _BuilderDashboardView(),
    );
  }
}

class _BuilderDashboardView extends StatefulWidget {
  const _BuilderDashboardView();

  @override
  State<_BuilderDashboardView> createState() => _BuilderDashboardViewState();
}

class _BuilderDashboardViewState extends State<_BuilderDashboardView> {
  late Future<BuilderDashboardModel> _dashboardFuture;

  DashboardTab _tab = DashboardTab.analytics;
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAnalytics());
  }

  Future<BuilderDashboardModel> _loadDashboard() {
    final auth = context.read<AuthProvider>();
    return BuilderDashboardService().getDashboardStats(auth.userId!);
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
      floatingActionButton: _tab == DashboardTab.content
          // Design insets the FAB 20 dp from the right edge; Scaffold's
          // endFloat location defaults to 16.
          ? Padding(
              padding: const EdgeInsets.only(right: 4),
              child: DashboardCreateFab(
                semanticLabel: 'Add project',
                onPressed: _onCreate,
              ),
            )
          : null,
      body: FutureBuilder<BuilderDashboardModel>(
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
                          DashboardTabSelector(
                            selected: _tab,
                            onChanged: (t) => setState(() => _tab = t),
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

  /// The create action this role already exposed, unchanged.
  void _onCreate() {
    Navigator.pushNamed(context, AppConstants.postPropertyScreen);
  }

  Widget _buildTabBody(
    BuildContext context,
    BuilderDashboardModel stats,
    AuthProvider auth,
  ) {
    final analytics = context.watch<DashboardAnalyticsProvider>();

    switch (_tab) {
      case DashboardTab.analytics:
        return DashboardAnalyticsBody(
          analytics: analytics.analytics,
          loading: analytics.analyticsLoading,
          failed: analytics.analyticsFailed,
          onRetry: analytics.refresh,
        );

      case DashboardTab.content:
        return DashboardContentBody(
          createLabel: 'Add Project',
          emptyActionLabel: 'Add Your First Project',
          onCreate: _onCreate,
          // Every existing section is preserved — only the containers and
          // section labels now follow the design.
          sections: [
            const DashboardSectionLabel('Overview'),
            const SizedBox(height: 10),
            BuilderStatsWidget(stats: stats),
            const SizedBox(height: 22),
            const DashboardSectionLabel('Quick Actions'),
            const SizedBox(height: 10),
            const DashboardCard(child: BuilderQuickActionsWidget()),
            const SizedBox(height: 22),
            const DashboardSectionLabel('Recent Projects'),
            const SizedBox(height: 10),
            DashboardCard(
              child: BuilderRecentProjectsWidget(builderId: auth.userId!),
            ),
            const SizedBox(height: 22),
            const DashboardSectionLabel('My Listings'),
            const SizedBox(height: 10),
            MyListingsSection(userId: auth.userId!),
          ],
        );

      case DashboardTab.audience:
        return DashboardAudienceBody(
          audience: analytics.audience,
          loading: analytics.audienceLoading,
          failed: analytics.audienceFailed,
          onRetry: analytics.refresh,
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