import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  final BannerDestination destination;

  /// Key into [PropertyService.getCategoryCounts]'s result map, for the
  /// live count badge.
  final String countKey;

  const CategoryItem({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.destination,
    required this.countKey,
  });
}

/// Home's "Popular Categories" — title and tile set mirror the portal's
/// `PropertyCategories.tsx` exactly for the five property-side categories
/// (Land, Residential, Commercial, Rent, For Sale): same table filter, same
/// live counts, same tap behaviour.
///
/// The portal's remaining four tiles (Verified Brokers, Builders,
/// Influencers, Premium Projects) are not reproduced — those navigate to
/// dedicated "browse all of this role/type" list pages
/// (`/brokers`, `/builders`, `/influencers`, `/latest-projects`) that this
/// app has no equivalent screen for. `PeopleSearchScreen` only searches by
/// typed text and returns nothing for a blank query, so it cannot stand in
/// for a role-browse tile without landing on an empty "type to search"
/// prompt — a placeholder navigation this task explicitly rules out.
///
/// WHAT EACH TILE FILTERS BY
/// --------------------------
/// Taken from the portal's own `PropertyCategories.handleCardClick`
/// (`PropertyCategories.tsx:54-59`): **Rent and For Sale set a listing type,
/// never a category**, while Land / Residential / Commercial set a category
/// and leave the listing type open.
///
/// Values are the wire values `FilterProvider` validates against
/// (`validCategories` / `validListingTypes`) — a display label passed to
/// `setCategory` is silently coerced to null, which would quietly return
/// unfiltered results.
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
  ];

  @override
  State<CategoryIconGrid> createState() => _CategoryIconGridState();
}

class _CategoryIconGridState extends State<CategoryIconGrid> {
  late final Future<Map<String, int>> _counts =
      (widget.service ?? PropertyService()).getCategoryCounts();

  /// A shortcut is a fresh entry point, so it starts from a clean filter set.
  ///
  /// `BannerDestinationResolver` only *sets* the fields its destination
  /// carries; without the reset, tapping Commercial and then Residential
  /// would leave `category: commercial` behind. The portal gets this for
  /// free — each shortcut navigates to a fresh `/search?...` URL — so the
  /// reset is what matches its behaviour.
  void _open(BuildContext context, CategoryItem category) {
    context.read<FilterProvider>().resetFilters();
    BannerDestinationResolver.navigate(context, category.destination);
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
