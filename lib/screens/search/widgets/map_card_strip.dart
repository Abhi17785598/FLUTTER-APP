import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/property_model.dart';

/// Card width and image height, per the redesign's map strip.
const double _kCardWidth = 200;
const double _kCardImageHeight = 80;

/// Overall strip height: image + 10 dp padding either side of a price and a
/// title line.
const double kMapCardStripHeight = 138;

/// The horizontally-scrolling rail of result cards beneath the map.
///
/// Tapping a card does exactly what tapping its pin does — the redesign wires
/// both to the same `openPreview(i)` — so this takes a single callback and the
/// screen decides what that means.
class MapCardStrip extends StatelessWidget {
  final List<PropertyModel> properties;
  final ValueChanged<PropertyModel> onCardTap;

  /// Lets the screen scroll the rail programmatically if it ever needs to.
  final ScrollController? controller;

  const MapCardStrip({
    super.key,
    required this.properties,
    required this.onCardTap,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kMapCardStripHeight,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        // Leading inset only, matching the redesign's `padding-left: 20`; the
        // last card is allowed to run to the edge so the rail reads as scrollable.
        padding: const EdgeInsets.only(left: AppConstants.spacingXL),
        itemCount: properties.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppConstants.spacingM),
        itemBuilder: (context, index) {
          final property = properties[index];
          return _MapStripCard(
            property: property,
            onTap: () => onCardTap(property),
          );
        },
      ),
    );
  }
}

/// Private to the strip: a denser sibling of the list and grid cards.
///
/// Not `PropertyCardCompact` — that is a 130x95 image ROW rendered by the
/// Shortlist screen and Profile's My Content, so it is both the wrong shape and
/// off limits. Not `PropertyCardSearchGrid` either: this card is a fixed 200 dp
/// wide, has an 80 dp image and drops the facts line, so bending the grid tile
/// would have meant three optional parameters and two conditionals.
class _MapStripCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onTap;

  const _MapStripCard({required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${property.title}, ${property.priceDisplay}',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _kCardWidth,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            // The redesign gives the strip the quieter chrome shadow, not the
            // purple-tinted one the list and grid cards carry.
            boxShadow: AppColors.surfaceCardShadow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _kCardImageHeight,
                width: double.infinity,
                child: CachedNetworkImage(
                  imageUrl: property.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => ColoredBox(
                    color: AppColors.textHint.withValues(alpha: 0.1),
                  ),
                  errorWidget: (context, url, error) => ColoredBox(
                    color: AppColors.textHint.withValues(alpha: 0.1),
                    child: const Icon(Icons.broken_image, size: 18),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        property.priceDisplay,
                        style: AppTextStyles.price.copyWith(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        property.title,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
