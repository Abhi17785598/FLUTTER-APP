import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/property_provider.dart';
import '../../../widgets/property_card_vertical.dart';
import '../../../widgets/section_header.dart';

/// Same data source as before (`properties.take(4)`) and same navigation —
/// extracted verbatim into its own widget.
class TrendingSection extends StatelessWidget {
  const TrendingSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final trendingProperties = propertyProvider.properties.take(4).toList();
        if (trendingProperties.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Trending This Week',
              actionLabel: 'See all ›',
              onActionTap: () => Navigator.pushNamed(
                context,
                AppConstants.searchResultsScreen,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: AppConstants.propertyCardHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: trendingProperties.length,
                itemBuilder: (context, index) {
                  return PropertyCardVertical(
                    property: trendingProperties[index],
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppConstants.propertyDetailScreen,
                      arguments: {'propertyId': trendingProperties[index].id},
                    ),
                    onFavoriteToggle: () => propertyProvider.toggleShortlist(
                      trendingProperties[index].id,
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
