import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/category_icon_grid.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/premium_launch_bottom_sheet.dart';
import 'widgets/home_header.dart';
import 'widgets/premium_search_section.dart';
import 'widgets/quick_actions_section.dart';
import 'widgets/hero_banner_section.dart';
import 'widgets/property_reels_section.dart';
import 'widgets/featured_properties_section.dart';
import 'widgets/trending_section.dart';
import 'widgets/budget_section.dart';
import 'widgets/property_rail_section.dart';
import 'widgets/property_verification_section.dart';
import 'widgets/news_section.dart';
import 'widgets/tell_your_needs_section.dart';
import 'widgets/smart_tools_section.dart';
import 'widgets/trending_cities_section.dart';
import 'widgets/latest_articles_section.dart';
import 'widgets/popular_agents_section.dart';
import 'widgets/featured_projects_section.dart';
import 'widgets/latest_projects_section.dart';
import 'widgets/top_builders_section.dart';
import 'widgets/investors_corner_section.dart';
import 'widgets/city_roi_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
        PremiumLaunchBottomSheet.showOnce(context);
      }
    });
  }

  // Every rail below is a pure client-side slice/sort of the properties
  // already loaded by PropertyProvider — no new queries. Thresholds/proxies
  // are documented alongside each selector since PropertyModel has no
  // dedicated isLuxury/isNewLaunch/isInvestment flags to read instead.
  //
  // Spacing between sections is deliberately uneven — tight near the top
  // (Hero/Reels feel immediate), calmer and more generous the deeper the
  // page goes (New Launches/Investment) — plain vertical rhythm rather than
  // one flat gap repeated between every section.

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      const SizedBox(height: 6),
      const PremiumSearchSection(),
      const SizedBox(height: 18),

      // Hero Banner bleeds its own gradient tail into the page, so it needs
      // almost no gap after it.
      const HeroBannerSection(),
      const SizedBox(height: 6),

      const QuickActionsSection(),
      const SizedBox(height: 18),

      const CategoryIconGrid(),
      const SizedBox(height: 18),

      // Trending Cities — mirrors the web home page's position for this rail,
      // right after the category tiles. Renders nothing (no trailing gap
      // left behind either) when the admin table has no active cities; see
      // TrendingCitiesSection's own bottom padding.
      const TrendingCitiesSection(),

      // Property Verification — one of the first "do something" moments on the
      // page, mirroring its high position on the web home page.
      const PropertyVerificationSection(),
      const SizedBox(height: 24),

      const PropertyReelsSection(),
      const SizedBox(height: 4),

      // Latest Articles. Same "renders nothing, owns its own trailing gap"
      // convention as Latest News below — see LatestArticlesSection.
      const LatestArticlesSection(),

      const SizedBox(height: 24),

      // Featured Projects (builder_projects, via the admin-curated
      // `featured_projects` table) sits directly before Featured Properties
      // (properties, via `hot_properties`) — the same order the web home
      // page uses for its "Featured Projects" / "Hot Properties" pair. Kept
      // as two separate sections/queries/cards on purpose: projects and
      // properties are different entities ([ProjectModel] vs
      // [PropertyModel]) and must never be shown as if they were the same
      // list.
      const FeaturedProjectsSection(),
      const FeaturedPropertiesSection(),
      const SizedBox(height: 24),

      // Latest News. Renders nothing at all — not even its header — when the
      // `news` table has no active rows, so it carries its own trailing 24 dp
      // internally; a spacer entry here would outlive the section and leave a
      // hole in the feed. See `_kNewsBottomGap`.
      const NewsSection(),

      // Top Builders — mirrors the web home page's sidebar position, right
      // after Latest News.
      const TopBuildersSection(),

      // "New Listings" — individual property listings, newest first. This is
      // deliberately titled differently from the section below: it renders
      // `properties` rows, not `builder_projects` rows, and the two used to
      // share the title "Latest Projects" while showing entirely different
      // data — exactly the property/project conflation this pass fixes.
      PropertyRailSection(
        title: 'New Listings',
        showWhenEmpty: true,
        emptyMessage: 'No properties listed yet',
        selector: (all) {
          final newest = List.of(all)
            ..sort(
              (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
                a.createdAt ?? DateTime(0),
              ),
            );
          return newest.take(8).toList();
        },
      ),
      const SizedBox(height: 24),

      // The genuine "Latest Projects" rail — `builder_projects`, not
      // `properties`. Sits right after New Listings, mirroring the web home
      // page's Latest-Projects-in-city → Top Brokers → Top Influencers order.
      const LatestProjectsSection(),

      // Popular Brokers / Popular Influencers — mirrors the web home page's
      // "Top Brokers" / "Top Influencers" position, right after the latest
      // listings. Each renders nothing (and owns its own trailing gap) when
      // there are no matching approved profiles.
      const PopularBrokersSection(),
      const PopularInfluencersSection(),

      const TrendingSection(),
      const SizedBox(height: 24),

      // Tell Your Needs — mid-page, after the main listings content, mirroring
      // where the web home page sits its lead form.
      const TellYourNeedsSection(),
      const SizedBox(height: 28),

      const SmartToolsSection(),
      const SizedBox(height: 28),

      // Investor's Corner, then City ROI Index — mirrors the web home
      // page's order right after its "Useful Tools" block. Each renders
      // nothing when the admin table has no active rows.
      const InvestorsCornerSection(),
      const CityRoiSection(),

      const BudgetSection(),
      const SizedBox(height: 100),
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-screen, fixed (non-scrolling) backdrop behind the whole
          // page — the glassmorphism header/search/quick-actions above sit
          // on top of it, and it also shows faintly through the gaps
          // between the ordinary opaque section cards further down the
          // scroll, without any of those ~20 other sections needing to
          // change. (The header needs this: its `GlassCard` is a real
          // translucent blur, which reads as flat, pointless glass with
          // nothing but plain background behind it — this backdrop is what
          // that glass is actually showing through.)
          const _HomeBackground(),
          SafeArea(
            child: Column(
              children: [
                const HomeHeader(),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => sections[index],
                          childCount: sections.length,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}

/// The Home Screen's premium backdrop: "Frosted Glass + Subtle Waves" — a
/// soft, cool-neutral gradient base with a handful of large, extremely
/// low-opacity flowing shapes drifting diagonally across it, so the header/
/// search/quick-actions glass surfaces and every ordinary opaque section
/// card further down the scroll have a quiet, premium environment to sit in
/// rather than a flat single colour. Fixed and non-scrolling, sitting behind
/// the whole page (see the `Scaffold` in `build()`), so it shows faintly
/// through the gaps between section cards too without any of those ~20
/// other sections needing to change.
///
/// Deliberately built from plain gradients/shapes rather than a photo:
/// - No network image / decode cost, no placeholder flash while it loads.
/// - Each "wave" blurs only its own simple static shape via `ImageFiltered`
///   once at first paint — never a `BackdropFilter` sampling whatever is
///   live behind it, which is what caused real scroll jank when tried
///   elsewhere in this app (see `AppGlassBackdrop`'s own doc comment). This
///   widget doesn't animate and isn't a `BackdropFilter`, so it costs
///   nothing extra while the page scrolls.
class _HomeBackground extends StatelessWidget {
  const _HomeBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Soft, cool-neutral base gradient — very light throughout,
            // never dark or saturated enough to fight the cards on top.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF9FBFD),
                    Color(0xFFF2F5F8),
                    Color(0xFFEEF1F5),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
            // 2-4 large, smooth, heavily blurred "wave" bands drifting
            // diagonally — a soft frosted-white one for light, a soft
            // cool-blue-grey one for depth, and a single, very faint
            // brand-orange glow tucked in a corner as the only accent.
            Positioned(
              top: -size.height * 0.10,
              left: -size.width * 0.4,
              child: Transform.rotate(
                angle: -0.22,
                child: _WaveBand(
                  width: size.width * 1.7,
                  height: size.height * 0.32,
                  color: const Color(0x1FFFFFFF),
                ),
              ),
            ),
            Positioned(
              top: size.height * 0.28,
              right: -size.width * 0.5,
              child: Transform.rotate(
                angle: 0.16,
                child: _WaveBand(
                  width: size.width * 1.8,
                  height: size.height * 0.30,
                  color: const Color(0x149DB2C9),
                ),
              ),
            ),
            Positioned(
              bottom: -size.height * 0.14,
              left: -size.width * 0.35,
              child: Transform.rotate(
                angle: -0.14,
                child: _WaveBand(
                  width: size.width * 1.7,
                  height: size.height * 0.34,
                  color: const Color(0x18FFFFFF),
                ),
              ),
            ),
            // A single, very subtle PropCid-orange glow — the only warm
            // accent, kept faint enough to read as ambience, not colour.
            Positioned(
              bottom: size.height * 0.06,
              right: -size.width * 0.22,
              child: _WaveBand(
                width: size.width * 0.9,
                height: size.width * 0.9,
                color: const Color(0x14F97316),
                circular: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One soft, blurred band (or, for the accent glow, a circle) — the
/// building block of the frosted-wave backdrop above. Self-blurring via
/// `ImageFiltered`, not a `BackdropFilter`; see `_HomeBackground`'s own doc
/// comment for why that distinction matters for scroll performance.
class _WaveBand extends StatelessWidget {
  const _WaveBand({
    required this.width,
    required this.height,
    required this.color,
    this.circular = false,
  });

  final double width;
  final double height;
  final Color color;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          shape: circular ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: circular ? null : BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}
