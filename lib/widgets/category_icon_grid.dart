import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants/app_constants.dart';
import '../core/navigation/banner_destination_resolver.dart';
import '../core/theme/app_text_styles.dart';
import '../models/banner_destination.dart';
import '../providers/filter_provider.dart';
import '../services/property_service.dart';
import 'section_header.dart';

class CategoryItem {
  final String label;

  /// Category-specific illustration, copied verbatim from the portal's own
  /// `src/assets/categoriesicons/*.webp` (`PropertyCategories.tsx`'s
  /// `categoryIconConfig`) into `assets/categoriesicons/` — same art, same
  /// files, not a Flutter-only redraw.
  final String imageAsset;

  /// Accent used for the live-count badge's border/text — sampled to match
  /// each image's own dominant colour so the badge reads as part of the
  /// same illustration rather than an unrelated flat tint.
  final Color accentColor;

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
    required this.imageAsset,
    required this.accentColor,
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

  static const String _assetBase = 'assets/categoriesicons';

  static const List<CategoryItem> categories = [
    CategoryItem(
      label: 'Land',
      imageAsset: '$_assetBase/land.webp',
      accentColor: Color(0xFF22C55E),
      destination: BannerDestination.collection(category: 'land'),
      countKey: 'land',
    ),
    CategoryItem(
      label: 'Residential',
      imageAsset: '$_assetBase/residential.webp',
      accentColor: Color(0xFF2563EB),
      destination: BannerDestination.collection(category: 'residential'),
      countKey: 'residential',
    ),
    CategoryItem(
      label: 'Commercial',
      imageAsset: '$_assetBase/commercial.webp',
      accentColor: Color(0xFF9333EA),
      destination: BannerDestination.collection(category: 'commercial'),
      countKey: 'commercial',
    ),
    CategoryItem(
      label: 'Rent',
      imageAsset: '$_assetBase/rent.webp',
      accentColor: Color(0xFF14B8A6),
      destination: BannerDestination.collection(listingType: 'rent'),
      countKey: 'rent',
    ),
    CategoryItem(
      label: 'For Sale',
      imageAsset: '$_assetBase/sale.webp',
      accentColor: Color(0xFF92722A),
      destination: BannerDestination.collection(listingType: 'sell'),
      countKey: 'sell',
    ),
    CategoryItem(
      label: 'Verified Brokers',
      imageAsset: '$_assetBase/brokerverified.webp',
      accentColor: Color(0xFF1E3A8A),
      countKey: 'brokers',
    ),
    CategoryItem(
      label: 'Builders',
      imageAsset: '$_assetBase/builder.webp',
      accentColor: Color(0xFFD97706),
      countKey: 'builders',
    ),
    CategoryItem(
      label: 'Influencers',
      imageAsset: '$_assetBase/influencer.webp',
      accentColor: Color(0xFFDB2777),
      countKey: 'influencers',
    ),
    CategoryItem(
      label: 'Premium Projects',
      imageAsset: '$_assetBase/premiumproject.webp',
      accentColor: Color(0xFFB8860B),
      countKey: 'projects',
    ),
  ];

  @override
  State<CategoryIconGrid> createState() => _CategoryIconGridState();
}

class _CategoryIconGridState extends State<CategoryIconGrid> {
  /// Side length each category illustration renders at. Bigger than the
  /// old flat icon's 52 dp — these are detailed illustrations, not simple
  /// glyphs, and need more room to stay legible.
  static const double _kTileImageSize = 64.0;

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
              // Was 100 for the old flat icon-in-circle (52 dp). The
              // portal-sourced illustrations need more room to read clearly
              // (_kTileImageSize, 64 dp) — 100 → 112 keeps the same
              // gap(8)/2-line-label allowance as before, just around the
              // bigger image.
              height: 112,
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
                              // The portal renders these with plain
                              // `object-contain` — no colour chip behind
                              // them, since each illustration already
                              // carries its own backdrop/badge art baked
                              // in. Matching that here rather than boxing
                              // it in the old flat circle.
                              Image.asset(
                                category.imageAsset,
                                width: _kTileImageSize,
                                height: _kTileImageSize,
                                fit: BoxFit.contain,
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
                                        color: category.accentColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      count > 999 ? '999+' : '$count',
                                      style: AppTextStyles.chip.copyWith(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: category.accentColor,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: _kTileImageSize,
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
