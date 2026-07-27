import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../models/broker_dashboard_model.dart';
import '../../services/broker_dashboard_service.dart';
import '../widgets/broker_stats_widget.dart';
import '../widgets/broker_recent_properties_widget.dart';
import '../widgets/broker_quick_actions_widget.dart';
import 'my_listings_section.dart';

// ---------------------------------------------------------------------------
// PREMIUM PALETTE — keep this rich/deep across the whole gradient, no fading.
// ---------------------------------------------------------------------------
class _BrandGradient {
  // All four stay deep/saturated — c4 is only used for small accents
  // (icons, badges, glow blobs), never as a large gradient endpoint,
  // since a light endpoint is exactly what reads as "faded" at scale.
  static const Color c1 = Color(0xFF2A1AA8); // deepest — anchors top-left
  static const Color c2 = Color(0xFF3424C8); // base brand purple
  static const Color c3 = Color(0xFF4C3EF0); // brightest point, mid-card only
  static const Color c4 = Color(0xFF6657FF); // accent only — icons/glows

  // Base header gradient: deep -> bright -> deep again, so the right edge
  // is exactly as saturated as the left edge. No light corner anywhere.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [c1, c3, c2],
    stops: [0.0, 0.55, 1.0],
  );
}

class BrokerDashboardScreen extends StatefulWidget {
  const BrokerDashboardScreen({super.key});

  @override
  State<BrokerDashboardScreen> createState() =>
      _BrokerDashboardScreenState();
}

class _BrokerDashboardScreenState extends State<BrokerDashboardScreen> {
  late Future<BrokerDashboardModel> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadDashboard();
  }

  Future<BrokerDashboardModel> _loadDashboard() {
    final auth = context.read<AuthProvider>();
    return BrokerDashboardService().getDashboardStats(auth.userId!);
  }

  Future<void> _refresh() async {
    setState(() {
      _dashboardFuture = _loadDashboard();
    });
    await _dashboardFuture;
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  String _formattedDate() {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    const days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    final now = DateTime.now();
    return "${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}";
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final scheme = Theme.of(context).colorScheme;

    if (auth.userId == null) {
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        body: const Center(
          child: CircularProgressIndicator(color: _BrandGradient.c2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F5FB),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [_BrandGradient.c2, _BrandGradient.c3],
          ),
          boxShadow: [
            BoxShadow(
              color: _BrandGradient.c2.withOpacity(0.4),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () {},
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_home_work_rounded, color: Colors.white),
          label: const Text(
            "Add Property",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: FutureBuilder<BrokerDashboardModel>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(context);
          }

          if (snapshot.hasError) {
            return _buildErrorState(context);
          }

          final stats = snapshot.data;
          if (stats == null) {
            return _buildErrorState(context);
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            color: _BrandGradient.c2,
            displacement: 60,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                _buildHeroHeader(context, auth),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 110),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle(context, "Overview", Icons.dashboard_rounded),
                        const SizedBox(height: 16),
                        BrokerStatsWidget(stats: stats),

                        const SizedBox(height: 30),
                        _buildPerformanceOverview(context, stats),

                        const SizedBox(height: 30),
                        _sectionTitle(context, "Quick Actions", Icons.bolt_rounded),
                        const SizedBox(height: 16),
                        _quickActionsCard(context),

                        const SizedBox(height: 30),
                        _sectionTitle(context, "Recent Properties", Icons.apartment_rounded),
                        const SizedBox(height: 16),
                        _recentPropertiesCard(context, auth),

                        const SizedBox(height: 30),
                        _buildRecentActivitySection(context),

                        const SizedBox(height: 30),
                        _sectionTitle(context, "My Listings", Icons.home_work_rounded),
                        const SizedBox(height: 16),
                        MyListingsSection(userId: auth.userId!),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------- SECTION TITLE ----------------

  Widget _sectionTitle(BuildContext context, String label, IconData icon) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_BrandGradient.c2, _BrandGradient.c4],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: const Color(0xFF1C1530),
          ),
        ),
      ],
    );
  }

  // ---------------- HERO HEADER ----------------

  Widget _buildHeroHeader(BuildContext context, AuthProvider auth) {
    final textTheme = Theme.of(context).textTheme;

    return SliverToBoxAdapter(
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: _BrandGradient.hero,
            boxShadow: [
              BoxShadow(
                color: _BrandGradient.c1.withOpacity(0.35),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative glow #1 — kept on the LEFT so the right edge
              // of the header stays fully saturated, not lightened.
              Positioned(
                top: -50,
                left: -60,
                child: _glowCircle(190, Colors.white.withOpacity(0.08)),
              ),
              // Decorative glow #2 — soft accent, bottom-left only.
              Positioned(
                bottom: -90,
                left: -30,
                child: _glowCircle(220, _BrandGradient.c1.withOpacity(0.4)),
              ),
              // Decorative glow #3 — small, deep accent near top-right,
              // dark enough to not read as a "fade".
              Positioned(
                top: -30,
                right: -30,
                child: _glowCircle(140, _BrandGradient.c1.withOpacity(0.45)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 56, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              _buildAvatar(auth),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _greeting(),
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: Colors.white.withOpacity(0.85),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            auth.userName.isNotEmpty ? auth.userName : "Broker",
                                            style: textTheme.titleLarge?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -0.3,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _brokerBadge(),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildGlassIconButton(
                          icon: Icons.notifications_none_rounded,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    _glassDateCard(context),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glowCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0)],
        ),
      ),
    );
  }

  Widget _brokerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: const Text(
        "BROKER",
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _glassDateCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.22)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _formattedDate(),
                  style: textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                "Listings overview",
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.85),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(AuthProvider auth) {
    final url = auth.avatarUrl;
    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.4)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: (url != null && url.isNotEmpty)
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _avatarFallback(auth),
              )
            : _avatarFallback(auth),
      ),
    );
  }

  Widget _avatarFallback(AuthProvider auth) {
    final name = auth.userName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : "B";
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_BrandGradient.c2, _BrandGradient.c4],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withOpacity(0.16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withOpacity(0.22)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(11),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
                Positioned(
                  top: 9,
                  right: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF5D5D),
                      border: Border.all(color: _BrandGradient.c2, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- PERFORMANCE OVERVIEW ----------------
  // Broker equivalent of Builder's Performance Overview card.
  // Uses only fields available on BrokerDashboardModel: totalListings,
  // activeListings, totalViews, averageRating. No fake/dummy data.

  Widget _buildPerformanceOverview(
    BuildContext context,
    BrokerDashboardModel stats,
  ) {
    final textTheme = Theme.of(context).textTheme;

    final totalListings = stats.totalListings;
    final activeRate = totalListings > 0
        ? (stats.activeListings / totalListings).clamp(0.0, 1.0)
        : 0.0;

    // "Views" progress is normalized against a nominal 100-views-per-listing
    // benchmark purely for the progress-bar visualization — the trailing
    // label always shows the real, unmodified total views figure.
    final viewsPerListing = totalListings > 0
        ? (stats.totalViews / totalListings)
        : 0.0;
    final viewsRate = (viewsPerListing / 100).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3424C8).withOpacity(0.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_BrandGradient.c2, _BrandGradient.c4],
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.insights_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                "Listing Performance",
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1C1530),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _progressRow(
            context,
            label: "Views",
            value: viewsRate,
            color: const Color(0xFFF97316),
            trailing: stats.totalViews.toString(),
          ),
          const SizedBox(height: 20),
          _progressRow(
            context,
            label: "Conversion",
            value: activeRate,
            color: const Color(0xFF3B82F6),
            trailing: "${stats.activeListings}/$totalListings",
          ),
          const SizedBox(height: 24),
          Divider(color: Colors.grey.withOpacity(0.12), height: 1),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ratingTile(
                  context,
                  label: "Customer Rating",
                  value: stats.averageRating,
                  icon: Icons.star_rounded,
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _ratingTile(
                  context,
                  label: "Active Listings",
                  value: stats.activeListings.toDouble(),
                  icon: Icons.workspace_premium_rounded,
                  color: const Color(0xFF8B5CF6),
                  showAsInt: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressRow(
    BuildContext context, {
    required String label,
    required double value,
    required Color color,
    required String trailing,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1C1530),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trailing,
                style: textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            tween: Tween(begin: 0, end: value),
            builder: (context, animatedValue, _) => LinearProgressIndicator(
              value: animatedValue,
              minHeight: 9,
              backgroundColor: color.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _ratingTile(
    BuildContext context, {
    required String label,
    required double value,
    required IconData icon,
    required Color color,
    bool showAsInt = false,
  }) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 9),
          Text(
            showAsInt ? value.toInt().toString() : value.toStringAsFixed(1),
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1C1530),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- QUICK ACTIONS WRAPPER CARD ----------------
  // Wraps the existing BrokerQuickActionsWidget in a premium container
  // without altering its internal logic.

  Widget _quickActionsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3424C8).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const BrokerQuickActionsWidget(),
    );
  }

  // ---------------- RECENT PROPERTIES WRAPPER CARD ----------------
  // Wraps the existing BrokerRecentPropertiesWidget in a premium container
  // without altering its internal logic.

  Widget _recentPropertiesCard(BuildContext context, AuthProvider auth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3424C8).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: BrokerRecentPropertiesWidget(
        brokerId: auth.userId!,
      ),
    );
  }

  // ---------------- RECENT ACTIVITY ----------------

  Widget _buildRecentActivitySection(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, "Recent Activity", Icons.history_rounded),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF3424C8).withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF3424C8).withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          _BrandGradient.c4.withOpacity(0.14),
                          _BrandGradient.c4.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_BrandGradient.c2, _BrandGradient.c4],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _BrandGradient.c2.withOpacity(0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.timeline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                "Nothing here yet",
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1C1530),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Your latest updates and enquiries\nwill show up here.",
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- LOADING STATE ----------------

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