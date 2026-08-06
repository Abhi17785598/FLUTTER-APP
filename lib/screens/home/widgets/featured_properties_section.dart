import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/property_provider.dart';
import '../../../widgets/property_card_vertical.dart';
import '../../../widgets/section_header.dart';
import 'empty_rail_placeholder.dart';

/// Same data source as before (`PropertyProvider.getFeaturedProperties()`)
/// and same navigation — extracted verbatim into its own widget.
class FeaturedPropertiesSection extends StatelessWidget {
  const FeaturedPropertiesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final featuredProperties = propertyProvider.getFeaturedProperties();

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
            if (featuredProperties.isEmpty)
              const EmptyRailPlaceholder(
                height: AppConstants.propertyCardHeight,
                message: 'No featured listings yet',
                detail: 'Listings become featured once they start getting views.',
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
  }
}
