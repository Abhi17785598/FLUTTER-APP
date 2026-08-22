import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../providers/property_provider.dart';
import '../../../widgets/property_card_vertical.dart';
import '../../../widgets/section_header.dart';
import 'trending_section.dart';

/// "More properties you haven't already seen" — the loaded `properties` list
/// minus whatever Featured/Trending already showed, top 8. No new query.
class RecommendedSection extends StatelessWidget {
  const RecommendedSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final all = propertyProvider.properties;
        // Excludes the same top-4 TrendingSection actually renders (sorted by
        // views), not a re-guessed slice — see TrendingSection.topTrending.
        final shownIds = <String>{
          ...propertyProvider.getFeaturedProperties().map((p) => p.id),
          ...TrendingSection.topTrending(all).map((p) => p.id),
        };
        final recommended = all
            .where((p) => !shownIds.contains(p.id))
            .take(8)
            .toList();
        if (recommended.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Recommended for You',
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
                itemCount: recommended.length,
                itemBuilder: (context, index) {
                  return PropertyCardVertical(
                    property: recommended[index],
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppConstants.propertyDetailScreen,
                      arguments: {'propertyId': recommended[index].id},
                    ),
                    onFavoriteToggle: () =>
                        propertyProvider.toggleShortlist(recommended[index].id),
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
