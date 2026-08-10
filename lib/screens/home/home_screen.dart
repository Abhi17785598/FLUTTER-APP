import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
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
import 'widgets/recommended_section.dart';
import 'widgets/property_rail_section.dart';
import 'widgets/premium_banner_section.dart';
import 'widgets/scroll_reveal.dart';
import 'widgets/property_verification_section.dart';
import 'widgets/news_section.dart';
import 'widgets/tell_your_needs_section.dart';
import 'widgets/smart_tools_section.dart';

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
      const ScrollReveal(child: HeroBannerSection()),
      const SizedBox(height: 6),

      const QuickActionsSection(),
      const SizedBox(height: 18),

      const CategoryIconGrid(),
      const SizedBox(height: 18),

      // Property Verification — one of the first "do something" moments on the
      // page, mirroring its high position on the web home page.
      const ScrollReveal(child: PropertyVerificationSection()),
      const SizedBox(height: 24),

      const PropertyReelsSection(),
      const SizedBox(height: 4),

      // Premium Banner bleeds on both edges — no extra gap either side.
      const ScrollReveal(child: PremiumBannerSection()),

      const SizedBox(height: 24),
      const FeaturedPropertiesSection(),
      const SizedBox(height: 24),

      // Latest News. Renders nothing at all — not even its header — when the
      // `news` table has no active rows, so it carries its own trailing 24 dp
      // internally; a spacer entry here would outlive the section and leave a
      // hole in the feed. See `_kNewsBottomGap`.
      const ScrollReveal(child: NewsSection()),

      // "Latest projects" — newest listings first. Sits directly under
      // Featured, right after the Premium banner, and keeps its header even
      // before any listings exist so the feed doesn't open with a gap.
      PropertyRailSection(
        title: 'Latest Projects',
        showWhenEmpty: true,
        emptyMessage: 'No projects listed yet',
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

      const TrendingSection(),
      const SizedBox(height: 24),

      // Tell Your Needs — mid-page, after the main listings content, mirroring
      // where the web home page sits its lead form.
      const ScrollReveal(child: TellYourNeedsSection()),
      const SizedBox(height: 28),

      const ScrollReveal(child: SmartToolsSection()),
      const SizedBox(height: 28),

      const BudgetSection(),
      const SizedBox(height: 28),

      const RecommendedSection(),
      const SizedBox(height: 32),

      // The "step up" rail — visibly larger cards, plus a one-shot reveal —
      // reads as the premium moment among the property rails.
      ScrollReveal(
        child: PropertyRailSection(
          title: 'Luxury Collection',
          cardWidth: 260,
          cardImageHeight: 170,
          selector: (all) {
            // ₹2Cr+ — same threshold as the "₹2Cr+" Browse-by-Budget bucket.
            final luxury = all.where((p) => p.price >= 20000000).toList()
              ..sort((a, b) => b.price.compareTo(a.price));
            return luxury.take(8).toList();
          },
        ),
      ),
      const SizedBox(height: 32),

      PropertyRailSection(
        title: 'Investment Opportunities',
        selector: (all) {
          // Proxy for "hot": most-viewed + most-enquired-about listings.
          final hottest = List.of(all)
            ..sort((a, b) {
              final scoreA = (a.views ?? 0) + (a.interestCount ?? 0);
              final scoreB = (b.views ?? 0) + (b.interestCount ?? 0);
              return scoreB.compareTo(scoreA);
            });
          return hottest.take(8).toList();
        },
      ),
      const SizedBox(height: 100),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }
}
