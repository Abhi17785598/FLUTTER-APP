import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/property_model.dart';
import '../../../widgets/status_tag.dart';
import 'property_card_facts.dart';

/// Width of the leading image. The redesign's list card is a row with a fixed
/// 112 dp image column and a flexible content column.
const double _kImageWidth = 112;

/// Height of the image column — and therefore the card's natural height.
///
/// This has to be an explicit number. The redesign's card is CSS flexbox, where
/// the row's height falls out of the content and the image then stretches to
/// match. Flutter's `RenderFlex` cannot do that in a single layout pass: inside
/// a vertical `ListView` a row's incoming `maxHeight` is `infinity`, so asking
/// it to stretch its children hands them a tight infinite height and layout
/// throws. Pinning the image instead gives the row a finite height to size
/// itself from. See the class doc for the full constraint chain.
///
/// 120 clears the content block (price 19 + title 13 + locality 11 + facts 10.5
/// plus their gaps and 12 dp of padding) at default text scale.
const double _kImageHeight = 120;

/// The Search results List-surface card.
///
/// A NEW widget rather than a variant of `PropertyCardHorizontal`, deliberately.
/// That widget is a 280 dp-wide vertical column with a hard-coded
/// `margin: right 16`, built for a horizontally-scrolling rail, and it is
/// rendered by the Property Detail screen — so it is both the wrong shape for
/// this row layout and unsafe to change. Same reasoning rules out
/// `PropertyCardCompact` (Shortlist, Profile) and `PropertyCardVertical` (four
/// Home rails). Duplicating the card here keeps every one of those screens
/// untouched.
///
/// Constraint chain, which is load-bearing — a vertical `ListView` hands each
/// item `height: 0..infinity`, so nothing in here may depend on the incoming
/// `maxHeight`:
///
///   ListView item   height 0..infinity
///     -> Container  no height, so the infinity passes straight through
///       -> Row      crossAxisAlignment.start, so children get LOOSE height
///         -> SizedBox   overrides with its own tight 112 x 120  (finite)
///           -> Stack    StackFit.expand, now tight 112 x 120    (finite)
///         -> Expanded   tight width, loose height
///           -> Column   mainAxisSize.min, sizes to its children (finite)
///
/// The row's height is then `max(120, contentHeight)` and the container adopts
/// it. No infinite value is ever forced on a child.
class PropertyCardSearchRow extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  /// Opt-in, same convention as [onFavoriteToggle]: only rendered when a
  /// caller supplies it.
  final VoidCallback? onCompareToggle;
  final bool isInCompare;

  const PropertyCardSearchRow({
    super.key,
    required this.property,
    this.onTap,
    this.onFavoriteToggle,
    this.onCompareToggle,
    this.isInCompare = false,
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
          // Already an exact match for the redesign's card shadow
          // (`0 6px 20px rgba(91,80,232,.10), 0 2px 8px rgba(0,0,0,.05)`).
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          // `start`, never `stretch`. Every non-stretch alignment passes the
          // cross axis down LOOSE, so the image keeps its own tight 120 and the
          // content column sizes to its own content — no infinity reaches
          // either child. The row then takes the taller of the two, so if a
          // large text scale grows the content past 120 the card simply gets
          // taller instead of overflowing.
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: _kImageWidth,
              height: _kImageHeight,
              child: _buildImage(),
            ),
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
          placeholder: (context, url) =>
              ColoredBox(color: AppColors.textHint.withValues(alpha: 0.1)),
          errorWidget: (context, url, error) => ColoredBox(
            color: AppColors.textHint.withValues(alpha: 0.1),
            child: const Icon(Icons.broken_image, size: 20),
          ),
        ),
        if (property.statusTags.isNotEmpty)
          Positioned(
            top: AppConstants.spacingS,
            left: AppConstants.spacingS,
            // Only the first tag: the redesign's card carries a single badge,
            // and `statusTags` is the listing's raw hashtag list, so showing
            // several would quickly overrun a 112 dp column.
            child: StatusTag(label: property.statusTags.first),
          ),
        if (onFavoriteToggle != null)
          Positioned(
            top: AppConstants.spacingS,
            right: AppConstants.spacingS,
            child: _buildFavouriteButton(),
          ),
        if (onCompareToggle != null)
          Positioned(
            top: onFavoriteToggle != null ? 40 : AppConstants.spacingS,
            right: AppConstants.spacingS,
            child: _buildCompareButton(),
          ),
      ],
    );
  }

  Widget _buildCompareButton() {
    return Semantics(
      label: isInCompare ? 'Remove from compare' : 'Add to compare',
      button: true,
      child: GestureDetector(
        onTap: onCompareToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppConstants.pillRadius),
          ),
          child: Icon(
            isInCompare ? Icons.check_circle : Icons.compare_arrows_rounded,
            size: 15,
            color: isInCompare ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFavouriteButton() {
    return Semantics(
      label: property.isShortlisted ? 'Remove from saved' : 'Save property',
      button: true,
      child: GestureDetector(
        onTap: onFavoriteToggle,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(AppConstants.pillRadius),
          ),
          child: Icon(
            property.isShortlisted ? Icons.favorite : Icons.favorite_border,
            size: 15,
            color: property.isShortlisted
                ? AppColors.error
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            property.priceDisplay,
            style: AppTextStyles.price.copyWith(fontSize: 19),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppConstants.spacingXS),
          Text(
            property.title,
            style: AppTextStyles.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            property.location,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            propertyFactsLine(property),
            style: AppTextStyles.caption.copyWith(fontSize: 10.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
