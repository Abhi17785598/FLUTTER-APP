import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/compare_toggle_handler.dart';
import '../../../models/property_model.dart';
import '../../../providers/compare_provider.dart';
import '../../../providers/property_provider.dart';
import '../../../widgets/property_card_vertical.dart';
import '../../../widgets/section_header.dart';

/// "Trending This Week" — sorted by `views` descending, a genuine popularity
/// signal rather than a plain `.take(4)` off the already `created_at`-DESC
/// list. The previous `.take(4)` selector just returned the newest 4
/// listings again, which is exactly the "same properties in every section"
/// duplication this rail should not reproduce — the newest listings already
/// anchor "Latest Projects", so this rail needs its own ordering to earn its
/// place on the page.
class TrendingSection extends StatelessWidget {
  const TrendingSection({super.key});

  /// The rail's own selection, exposed so [RecommendedSection] can exclude
  /// exactly what this rail shows rather than guessing at a different slice.
  static List<PropertyModel> topTrending(
    List<PropertyModel> all, {
    int count = 4,
  }) {
    final byViews = List.of(all)
      ..sort((a, b) => (b.views ?? 0).compareTo(a.views ?? 0));
    return byViews.take(count).toList();
  }

  @override
  Widget build(BuildContext context) {
    final compareProvider = context.watch<CompareProvider>();
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final trendingProperties = topTrending(propertyProvider.properties);
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
                    isInCompare: compareProvider.isSelected(
                      trendingProperties[index].id,
                    ),
                    onCompareToggle: () =>
                        handleCompareToggle(context, trendingProperties[index]),
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
