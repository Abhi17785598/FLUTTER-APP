import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/property_model.dart';
import '../../../widgets/status_tag.dart';
import 'property_card_facts.dart';

/// Image height for the grid tile, per the redesign.
const double _kImageHeight = 96;

/// Fixed tile height, handed to the grid delegate as `mainAxisExtent`.
///
/// A `mainAxisExtent` rather than a `childAspectRatio` on purpose: the ratio
/// would make the tile's height depend on the device width, so the same card
/// would clip on a narrow phone and leave dead space on a wide one. Pinning the
/// height keeps the layout identical everywhere and lets only the width flex.
///
/// 96 image + 10/10 padding + price/title/facts and their gaps ≈ 175; 180 leaves
/// a little headroom for text-scale variation.
const double kSearchGridTileExtent = 180;

/// The Search results Grid-surface card — the module's one genuinely new view.
///
/// A NEW widget, not a variant of `PropertyCardVertical`: that widget is
/// rendered by four Home rails (featured, latest, recommended, trending),
/// hard-codes `margin: right 16` (which would produce uneven gutters inside a
/// GridView), and carries a 36 dp heart, a locality overlay and luxury-threshold
/// logic that the redesign's tile does not have. Bending it to fit would have
/// changed all four of those rails.
class PropertyCardSearchGrid extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;

  const PropertyCardSearchGrid({
    super.key,
    required this.property,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: _kImageHeight, child: _buildImage()),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: property.imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => ColoredBox(
            color: AppColors.textHint.withValues(alpha: 0.1),
          ),
          errorWidget: (context, url, error) => ColoredBox(
            color: AppColors.textHint.withValues(alpha: 0.1),
            child: const Icon(Icons.broken_image, size: 20),
          ),
        ),
        if (property.statusTags.isNotEmpty)
          Positioned(
            top: 7,
            left: 7,
            child: StatusTag(label: property.statusTags.first),
          ),
      ],
    );
  }

  /// No favourite button and no locality line — the redesign's grid tile omits
  /// both, keeping the denser layout readable at half width.
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            property.priceDisplay,
            style: AppTextStyles.price.copyWith(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            property.title,
            style: AppTextStyles.body.copyWith(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Text(
            propertyFactsLine(property),
            style: AppTextStyles.caption.copyWith(
              fontSize: 10,
              color: AppColors.textHint,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
