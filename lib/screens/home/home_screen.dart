import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/glass_card.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/property_provider.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/hero_banner_carousel.dart';
import '../../widgets/category_icon_grid.dart';
import '../../widgets/section_header.dart';
import '../../widgets/property_card_vertical.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/premium_launch_banner.dart';
import '../../widgets/premium_launch_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _staggerController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
        PremiumLaunchBottomSheet.showOnce(context);
      }
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _buildHeroText(context),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppColors.primaryGlow.map((shadow) =>
                            BoxShadow(
                              color: shadow.color.withOpacity(0.2),
                              blurRadius: shadow.blurRadius,
                              offset: shadow.offset,
                            )
                          ).toList(),
                        ),
                        child: SearchBarWidget(
                          hint: 'Search properties, locations...',
                          onTap: () {
                            Navigator.pushNamed(context, AppConstants.searchScreen);
                          },
                          // NEW: this was a plain, non-interactive Container —
                          // it sat visually on top of the search bar's own
                          // tap target but wasn't wired to anything itself,
                          // so tapping specifically on the mic icon did
                          // nothing at all. Wrapped in its own tap handler
                          // that jumps to Search and starts listening
                          // immediately, matching what the icon promises.
                          trailing: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppConstants.searchScreen,
                                arguments: {'autoStartVoice': true},
                              );
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.mic,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── QUICK ACTION PILLS (NEW) ──────────────────
                    _buildQuickActions(context),
                    const SizedBox(height: 20),

                    const HeroBannerCarousel(),
                    const SizedBox(height: 20),

                    // ── PREMIUM LAUNCH OFFER (NEW) ─────────────────
                    const PremiumLaunchBanner(),
                    const SizedBox(height: 24),

                    const CategoryIconGrid(),
                    const SizedBox(height: 12),
                    Consumer<PropertyProvider>(
                      builder: (context, propertyProvider, child) {
                        return SectionHeader(
                          title: 'Featured Properties',
                          actionLabel: 'See all ›',
                          onActionTap: () {
                            Navigator.pushNamed(context, AppConstants.searchResultsScreen);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Consumer<PropertyProvider>(
                      builder: (context, propertyProvider, child) {
                        final featuredProperties = propertyProvider.getFeaturedProperties();
                        return SizedBox(
                          height: AppConstants.propertyCardHeight,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: featuredProperties.length,
                            itemBuilder: (context, index) {
                              return PropertyCardVertical(
                                property: featuredProperties[index],
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppConstants.propertyDetailScreen,
                                    arguments: {'propertyId': featuredProperties[index].id},
                                  );
                                },
                                onFavoriteToggle: () {
                                  propertyProvider.toggleShortlist(featuredProperties[index].id);
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Consumer<PropertyProvider>(
                      builder: (context, propertyProvider, child) {
                        return SectionHeader(
                          title: 'Trending This Week ',
                          actionLabel: 'See all ›',
                          onActionTap: () {
                            Navigator.pushNamed(context, AppConstants.searchResultsScreen);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Consumer<PropertyProvider>(
                      builder: (context, propertyProvider, child) {
                        final trendingProperties = propertyProvider.properties.take(4).toList();
                        return SizedBox(
                          height: AppConstants.propertyCardHeight,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: trendingProperties.length,
                            itemBuilder: (context, index) {
                              return PropertyCardVertical(
                                property: trendingProperties[index],
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppConstants.propertyDetailScreen,
                                    arguments: {'propertyId': trendingProperties[index].id},
                                  );
                                },
                                onFavoriteToggle: () {
                                  propertyProvider.toggleShortlist(trendingProperties[index].id);
                                },
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    const SectionHeader(
                      title: 'Browse by Budget',
                      actionLabel: '',
                    ),
                    const SizedBox(height: 12),
                    _buildBudgetGrid(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),
    );
  }

  // ── NEW: Quick Action Pills ─────────────────────────────────────
  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'label': 'EMI Calc',
        'icon': Icons.calculate_outlined,
        'color': AppColors.primary,
        'route': AppConstants.emiCalculatorScreen,
        'args': null,
      },
      {
        'label': 'Compare',
        'icon': Icons.compare_arrows_rounded,
        'color': const Color(0xFF8B5CF6),
        'route': AppConstants.comparePropertiesScreen,
        'args': {'propertyIds': <String>[]},
      },
      {
        'label': 'Visits',
        'icon': Icons.calendar_today_outlined,
        'color': const Color(0xFF10B981),
        'route': AppConstants.visitsScreen,
        'args': null,
      },
      {
        'label': 'Post Property',
        'icon': Icons.add_home_outlined,
        'color': const Color(0xFFF97316),
        'route': AppConstants.postPropertyScreen,
        'args': null,
      },
    ];

    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: actions.length,
        itemBuilder: (context, i) {
          final a = actions[i];
          final color = a['color'] as Color;
          return GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              a['route'] as String,
              arguments: a['args'] as Map<String, dynamic>?,
            ),
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(color: color.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(a['icon'] as IconData, color: color, size: 17),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    a['label'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  // ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showLogoDropdown(context),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppColors.primaryGlow,
                  ),
                  child: const Center(
                    child: Text(
                      'PC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'PropCID',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down,
                    size: 20, color: AppColors.textSecondary),
              ],
            ),
          ),
          Row(
            children: [
              // Calendar / Visits
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined,
                      color: AppColors.textPrimary, size: 20),
                  onPressed: () =>
                      Navigator.pushNamed(context, AppConstants.visitsScreen),
                  padding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 12),

              // 🔔 Notifications bell → goes to full NotificationsScreen
              Stack(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                        context, AppConstants.notificationsScreen),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.notifications_outlined,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // Avatar → Profile
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppConstants.profileScreen),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    image: const DecorationImage(
                      image: NetworkImage(
                          'https://picsum.photos/seed/avatar/100/100'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroText(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back,',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          Row(
            children: [
              Text('Find your perfect ', style: AppTextStyles.heading1),
              const GradientText(
                text: 'property',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetGrid() {
    final budgets = [
      {
        'label': 'Under ₹50L',
        'icon': Icons.home_outlined,
        'color': const Color(0xFF22C55E),
        'image': 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400&h=300&fit=crop',
      },
      {
        'label': '₹50L – ₹1Cr',
        'icon': Icons.apartment,
        'color': const Color(0xFF3B82F6),
        'image': 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=400&h=300&fit=crop',
      },
      {
        'label': '₹1Cr – ₹2Cr',
        'icon': Icons.villa,
        'color': AppColors.primary,
        'image': 'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=400&h=300&fit=crop',
      },
      {
        'label': '₹2Cr+',
        'icon': Icons.business_center,
        'color': const Color(0xFFF97316),
        'image': 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=400&h=300&fit=crop',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
        ),
        itemCount: budgets.length,
        itemBuilder: (context, index) {
          final budget = budgets[index];
          return GestureDetector(
            onTap: () =>
                Navigator.pushNamed(context, AppConstants.searchResultsScreen),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      budget['image'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: (budget['color'] as Color).withOpacity(0.1),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Text(
                        budget['label'] as String,
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showLogoDropdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          children: [
            _buildDropdownItem(Icons.home_outlined, 'Home',
                () => Navigator.pop(context)),
            const SizedBox(height: 8),
            _buildDropdownItem(Icons.search_outlined, 'Search', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.searchScreen);
            }),
            const SizedBox(height: 8),
            _buildDropdownItem(Icons.favorite_border, 'Shortlist', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.shortlistScreen);
            }),
            const SizedBox(height: 8),
            _buildDropdownItem(Icons.calculate_outlined, 'EMI Calculator', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.emiCalculatorScreen);
            }),
            const SizedBox(height: 8),
            _buildDropdownItem(Icons.compare_arrows_rounded, 'Compare Properties', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.comparePropertiesScreen,
                  arguments: {'propertyIds': <String>[]});
            }),
            const SizedBox(height: 8),
            _buildDropdownItem(Icons.notifications_outlined, 'Notifications', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.notificationsScreen);
            }),
            const SizedBox(height: 8),
            _buildDropdownItem(Icons.movie_outlined, 'Reels', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.reelsScreen);
            }),
            const SizedBox(height: 8),
            _buildDropdownItem(Icons.person_outline, 'Profile', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.profileScreen);
            }),
            const SizedBox(height: 16),
            Divider(color: AppColors.textHint.withOpacity(0.2)),
            const SizedBox(height: 16),
            _buildDropdownItem(Icons.info_outline, 'About PropCID', () {
              Navigator.pop(context);
              _showAboutDialog(context);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(label,
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500)),
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('About PropCID'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PropCID is a modern real-estate application designed to make property search and visits seamless and efficient.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 16),
            Text('Version: 1.0.0'),
            Text('Developer: Rajesh Kumar'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}