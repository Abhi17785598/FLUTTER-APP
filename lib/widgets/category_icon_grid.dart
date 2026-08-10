import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/navigation/banner_destination_resolver.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/banner_destination.dart';
import '../providers/filter_provider.dart';

class CategoryItem {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  /// Where tapping this shortcut goes. A `collection` is just a pre-applied
  /// set of filter fields, which is exactly what a category shortcut is.
  final BannerDestination destination;

  const CategoryItem({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.destination,
  });
}

/// The five home-screen category shortcuts.
///
/// WHAT EACH ONE FILTERS BY
/// ------------------------
/// Taken from the portal's own `PropertyCategories.handleCardClick`
/// (`PropertyCategories.tsx:54-59`), which is the source of truth: **Buy and
/// Rent set a listing type, never a category**, while Plots / Commercial /
/// PG set a category and leave the listing type open. So "Buy Properties"
/// means everything for sale, not residential-for-sale — a plot listed for
/// sale belongs under Buy too, and the portal treats it that way.
///
/// Values are the wire values `FilterProvider` validates against
/// (`validCategories` / `validListingTypes`) — a display label passed to
/// `setCategory` is silently coerced to null, which would quietly return
/// unfiltered results.
class CategoryIconGrid extends StatelessWidget {
  const CategoryIconGrid({super.key});

  static const List<CategoryItem> _categories = [
    CategoryItem(
      label: 'Buy\nProperties',
      icon: Icons.home,
      bgColor: AppColors.categoryBuyBg,
      iconColor: AppColors.primary,
      destination: BannerDestination.collection(listingType: 'sell'),
    ),
    CategoryItem(
      label: 'Rent\nProperties',
      icon: Icons.apartment,
      bgColor: AppColors.categoryRentBg,
      iconColor: Color(0xFF3B82F6),
      destination: BannerDestination.collection(listingType: 'rent'),
    ),
    CategoryItem(
      label: 'Plots /\nLands',
      icon: Icons.flag,
      bgColor: AppColors.categoryPlotBg,
      iconColor: Color(0xFF22C55E),
      destination: BannerDestination.collection(category: 'land'),
    ),
    CategoryItem(
      label: 'Commercial\nSpaces',
      icon: Icons.business,
      bgColor: AppColors.categoryCommercialBg,
      iconColor: Color(0xFFF97316),
      destination: BannerDestination.collection(category: 'commercial'),
    ),
    CategoryItem(
      label: 'PG /\nCo-living',
      icon: Icons.bed,
      bgColor: AppColors.categoryPgBg,
      iconColor: Color(0xFFEC4899),
      destination: BannerDestination.collection(category: 'pg_coliving'),
    ),
  ];

  /// A shortcut is a fresh entry point, so it starts from a clean filter set.
  ///
  /// `BannerDestinationResolver` only *sets* the fields its destination
  /// carries; without the reset, tapping Commercial and then Buy would leave
  /// `category: commercial` behind and show commercial-for-sale under "Buy
  /// Properties". The portal gets this for free — each shortcut navigates to a
  /// fresh `/search?...` URL — so the reset is what matches its behaviour.
  void _open(BuildContext context, CategoryItem category) {
    context.read<FilterProvider>().resetFilters();
    BannerDestinationResolver.navigate(context, category.destination);
  }

  @override
  Widget build(BuildContext context) {
    const categories = _categories;

    return SizedBox(
      // ✅ FIX: was 90 — increased to 100 to fit icon (52) + gap (8) + 2-line text (~34) = 94 → give 100
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _open(context, category),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
  }
}
