import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/shimmer_loader.dart';
import '../../../models/property_model.dart';
import '../../../providers/property_provider.dart';
import '../../../services/hot_properties_service.dart';
import '../../../widgets/property_card_vertical.dart';
import '../../../widgets/section_header.dart';
import 'empty_rail_placeholder.dart';

/// Home's "Featured Properties" rail.
///
/// Sourced from the admin-curated `hot_properties` join table (see
/// [HotPropertiesService]) rather than `PropertyProvider.getFeaturedProperties()`
/// — that method's `views >= 1` proxy is a stand-in for "featured" with no
/// real admin curation behind it, and reusing it here reproduced the bug
/// this rail exists to fix: on a populated catalogue it showed almost the
/// same head-of-list properties as "Latest Projects". `hot_properties` is the
/// portal's real curation mechanism for the `properties` table (see
/// `HotPropertiesGrid.tsx`), so this rail now shows genuinely distinct,
/// admin-picked listings.
///
/// `PropertyModel.isFeatured` (the `views >= 1` proxy) is left untouched —
/// it still drives the "Featured" ribbon on `PropertyCardVertical` wherever
/// that card appears outside Home (search results, reels, property detail),
/// which is outside this rail's concern.
class FeaturedPropertiesSection extends StatefulWidget {
  const FeaturedPropertiesSection({super.key, this.service});

  @visibleForTesting
  final HotPropertiesService? service;

  @override
  State<FeaturedPropertiesSection> createState() =>
      _FeaturedPropertiesSectionState();
}

class _FeaturedPropertiesSectionState extends State<FeaturedPropertiesSection> {
  late final Future<List<PropertyModel>> _future =
      (widget.service ?? HotPropertiesService()).listActive();

  @override
  Widget build(BuildContext context) {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        return FutureBuilder<List<PropertyModel>>(
          future: _future,
          builder: (context, snapshot) {
            final loading = snapshot.connectionState != ConnectionState.done;
            final featuredProperties = snapshot.data ?? const <PropertyModel>[];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Featured Properties',
                  actionLabel: 'See all ›',
                  onActionTap: () => Navigator.pushNamed(
                    context,
                    AppConstants.searchResultsScreen,
                  ),
                ),
                const SizedBox(height: 12),
                if (loading)
                  SizedBox(
                    height: AppConstants.propertyCardHeight,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 3,
                      itemBuilder: (context, index) => const PropertyCardShimmer(),
                    ),
                  )
                else if (featuredProperties.isEmpty)
                  const EmptyRailPlaceholder(
                    height: AppConstants.propertyCardHeight,
                    message: 'No featured listings yet',
                    detail: 'Our team curates featured listings — check back soon.',
                  )
                else
                  SizedBox(
                    height: AppConstants.propertyCardHeight,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: featuredProperties.length,
                      itemBuilder: (context, index) {
                        return PropertyCardVertical(
                          property: featuredProperties[index],
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppConstants.propertyDetailScreen,
                            arguments: {'propertyId': featuredProperties[index].id},
                          ),
                          onFavoriteToggle: () => propertyProvider.toggleShortlist(
                            featuredProperties[index].id,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
