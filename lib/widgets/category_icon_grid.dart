import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/navigation/banner_destination_resolver.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/banner_destination.dart';
import '../providers/filter_provider.dart';
import '../services/property_service.dart';
import 'section_header.dart';

class CategoryItem {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  /// Where tapping this shortcut goes. A `collection` is just a pre-applied
  /// set of filter fields, which is exactly what a category shortcut is.
  /// Null for the four role/project tiles below, which have no dedicated
  /// "browse all" screen in this app yet (see [_CategoryIconGridState._open]).
  final BannerDestination? destination;

  /// Key into [_CategoryIconGridState._counts]'s result map, for the live
  /// count badge.
  final String countKey;

  const CategoryItem({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.countKey,
    this.destination,
  });
}

/// Home's "Popular Categories" — mirrors the portal's `PropertyCategories.tsx`
/// in full: all nine tiles (Land, Residential, Commercial, Rent, For Sale,
/// Verified Brokers, Builders, Influencers, Premium Projects), each with a
/// live count badge.
///
/// WHAT EACH TILE FILTERS BY
/// --------------------------
/// Taken from the portal's own `PropertyCategories.handleCardClick`
/// (`PropertyCategories.tsx:42-66`): **Rent and For Sale set a listing type,
/// never a category**, while Land / Residential / Commercial set a category
/// and leave the listing type open.
///
/// Values are the wire values `FilterProvider` validates against
/// (`validCategories` / `validListingTypes`) — a display label passed to
/// `setCategory` is silently coerced to null, which would quietly return
/// unfiltered results.
///
/// The remaining four tiles (Verified Brokers, Builders, Influencers,
/// Premium Projects) navigate to dedicated "browse all of this role/type"
/// pages on the portal (`/brokers`, `/builders`, `/influencers`,
/// `/latest-projects`); this app has no equivalent screen for those yet, so
/// tapping one surfaces a "coming soon" notice instead of either opening
/// nothing (a silent, unexplained no-op) or a route that doesn't exist.
class CategoryIconGrid extends StatefulWidget {
  const CategoryIconGrid({super.key, this.service});

  @visibleForTesting
  final PropertyService? service;

  static const List<CategoryItem> categories = [
    CategoryItem(
      label: 'Land',
      icon: Icons.landscape_rounded,
      bgColor: AppColors.categoryPlotBg,
      iconColor: Color(0xFF22C55E),
      destination: BannerDestination.collection(category: 'land'),
      countKey: 'land',
    ),
    CategoryItem(
      label: 'Residential',
      icon: Icons.home_rounded,
      bgColor: AppColors.categoryBuyBg,
      iconColor: AppColors.primary,
      destination: BannerDestination.collection(category: 'residential'),
      countKey: 'residential',
    ),
    CategoryItem(
      label: 'Commercial',
      icon: Icons.business_rounded,
      bgColor: AppColors.categoryCommercialBg,
      iconColor: Color(0xFFF97316),
      destination: BannerDestination.collection(category: 'commercial'),
      countKey: 'commercial',
    ),
    CategoryItem(
      label: 'Rent',
      icon: Icons.apartment_rounded,
      bgColor: AppColors.categoryRentBg,
      iconColor: Color(0xFF3B82F6),
      destination: BannerDestination.collection(listingType: 'rent'),
      countKey: 'rent',
    ),
    CategoryItem(
      label: 'For Sale',
      icon: Icons.sell_rounded,
      bgColor: AppColors.categoryPgBg,
      iconColor: Color(0xFFEC4899),
      destination: BannerDestination.collection(listingType: 'sell'),
      countKey: 'sell',
    ),
    CategoryItem(
      label: 'Verified Brokers',
      icon: Icons.verified_user_rounded,
      bgColor: Color(0xFFFCE7F3),
      iconColor: Color(0xFFE11D48),
      countKey: 'brokers',
    ),
    CategoryItem(
      label: 'Builders',
      icon: Icons.foundation_rounded,
      bgColor: Color(0xFFFFEDD5),
      iconColor: Color(0xFFD97706),
      countKey: 'builders',
    ),
    CategoryItem(
      label: 'Influencers',
      icon: Icons.camera_alt_rounded,
      bgColor: Color(0xFFF3E8FF),
      iconColor: Color(0xFF9333EA),
      countKey: 'influencers',
    ),
    CategoryItem(
      label: 'Premium Projects',
      icon: Icons.diamond_rounded,
      bgColor: Color(0xFFCCFBF1),
      iconColor: Color(0xFF0D9488),
      countKey: 'projects',
    ),
  ];

  @override
  State<CategoryIconGrid> createState() => _CategoryIconGridState();
}

class _CategoryIconGridState extends State<CategoryIconGrid> {
  late final Future<Map<String, int>> _counts = _loadCounts();

  /// Merges [PropertyService.getCategoryCounts] (land/residential/
  /// commercial/rent/sell) with counts for the four role/project tiles,
  /// queried here directly rather than adding to that service — mirrors the
  /// portal's own `countProfiles`/`countProjects` queries
  /// (`PropertyCategories.tsx`) against the same `profiles`/
  /// `builder_projects` tables every other role rail on this app already
  /// reads (`PeopleSearchService.listPopularAgents`,
  /// `ProjectService.listLatestActive`).
  Future<Map<String, int>> _loadCounts() async {
    final propertyCounts = await (widget.service ?? PropertyService())
        .getCategoryCounts();

    Future<int> countProfiles(String userType) async {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('user_id')
            .eq('user_type', userType)
            .eq('approval_status', 'approved')
            .not('is_blocked', 'is', true)
            .limit(1)
            .count(CountOption.exact);
        return response.count;
      } catch (_) {
        return 0;
      }
    }

    Future<int> countProjects() async {
      try {
        final response = await Supabase.instance.client
            .from('builder_projects')
            .select('id')
            .eq('status', 'active')
            .eq('approval_status', 'approved')
            .limit(1)
            .count(CountOption.exact);
        return response.count;
      } catch (_) {
        return 0;
      }
    }

    final extra = await Future.wait([
      countProfiles('broker'),
      countProfiles('builder'),
      countProfiles('influencer'),
      countProjects(),
    ]);

    return {
      ...propertyCounts,
      'brokers': extra[0],
      'builders': extra[1],
      'influencers': extra[2],
      'projects': extra[3],
    };
  }

  /// A shortcut is a fresh entry point, so it starts from a clean filter set.
  ///
  /// `BannerDestinationResolver` only *sets* the fields its destination
  /// carries; without the reset, tapping Commercial and then Residential
  /// would leave `category: commercial` behind. The portal gets this for
  /// free — each shortcut navigates to a fresh `/search?...` URL — so the
  /// reset is what matches its behaviour.
  void _open(BuildContext context, CategoryItem category) {
    final destination = category.destination;
    if (destination == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${category.label} — coming soon')),
        );
      return;
    }
    context.read<FilterProvider>().resetFilters();
    BannerDestinationResolver.navigate(context, destination);
  }

  @override
  Widget build(BuildContext context) {
    const categories = CategoryIconGrid.categories;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Popular Categories'),
        FutureBuilder<Map<String, int>>(
          future: _counts,
          builder: (context, snapshot) {
            final counts = snapshot.data ?? const <String, int>{};

            return SizedBox(
              // ✅ FIX: was 90 — increased to 100 to fit icon (52) + gap (8) + 2-line text (~34) = 94 → give 100
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final count = counts[category.countKey];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => _open(context, category),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: AppConstants.categoryIconSize,
                                height: AppConstants.categoryIconSize,
                                decoration: BoxDecoration(
                                  color: category.bgColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  category.icon,
                                  color: category.iconColor,
                                  size: AppConstants.categoryIconInnerSize,
                                ),
                              ),
                              if (count != null && count > 0)
                                Positioned(
                                  top: -4,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.pillRadius,
                                      ),
                                      border: Border.all(
                                        color: category.iconColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      count > 999 ? '999+' : '$count',
                                      style: AppTextStyles.chip.copyWith(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: category.iconColor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: 64,
                            child: Text(
                              category.label,
                              style: AppTextStyles.caption,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
