import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/property_model.dart';
import '../../../providers/property_provider.dart';
import '../../../widgets/property_card_vertical.dart';
import '../../../widgets/section_header.dart';

/// Generic horizontal property rail, parameterized by [title] and a
/// client-side [selector] over the already-loaded `properties` list — shared
/// by Luxury Collection / New Launches / Investment Opportunities so those
/// three near-identical rails don't need three near-duplicate files. No new
/// queries: every rail is just a different sort/filter of data already in
/// `PropertyProvider.properties`.
class PropertyRailSection extends StatelessWidget {
  const PropertyRailSection({
    super.key,
    required this.title,
    required this.selector,
    double? cardWidth,
    double? cardImageHeight,
  }) : cardWidth = cardWidth ?? AppConstants.propertyCardWidth,
       cardImageHeight =
           cardImageHeight ?? AppConstants.propertyCardImageHeight;

  final String title;
  final List<PropertyModel> Function(List<PropertyModel> all) selector;

  /// Lets one rail (Luxury Collection) render a visibly larger "step up"
  /// card than the others, for image-rhythm variety — same card widget,
  /// just a different size.
  final double cardWidth;
  final double cardImageHeight;

  @override
  Widget build(BuildContext context) {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final items = selector(propertyProvider.properties);
        if (items.isEmpty) return const SizedBox.shrink();
        final rowHeight =
            AppConstants.propertyCardHeight +
            (cardImageHeight - AppConstants.propertyCardImageHeight);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: title,
              actionLabel: 'See all ›',
              onActionTap: () => Navigator.pushNamed(
                context,
                AppConstants.searchResultsScreen,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: rowHeight,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  return PropertyCardVertical(
                    property: items[index],
                    width: cardWidth,
                    imageHeight: cardImageHeight,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppConstants.propertyDetailScreen,
                      arguments: {'propertyId': items[index].id},
                    ),
                    onFavoriteToggle: () =>
                        propertyProvider.toggleShortlist(items[index].id),
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
