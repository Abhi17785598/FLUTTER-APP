import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/property_model.dart';
import '../../../providers/auth_provider.dart';
import '../../property_detail/widgets/share_property_sheet.dart';
import 'people_result_card.dart' show PeopleAvatar;
import 'property_card_facts.dart';

/// Width of the leading image. The redesign's list card is a row with a fixed
/// 112 dp image column and a flexible content column.
const double _kImageWidth = 112;

/// The listing-type chip's colours. No existing token pairs a background with
/// a matching foreground here, so — like the other `_k`-prefixed prototype
/// values in this feature — they're declared locally rather than guessed from
/// an unrelated palette entry.
const Color _kListingChipBg = Color(0xFFFCE4EC);
const Color _kListingChipFg = Color(0xFFD6336C);

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
/// The image column now stretches to match the content column's height
/// (`IntrinsicHeight` + `CrossAxisAlignment.stretch`) instead of a fixed 120 dp
/// — the richer content block below (poster row, title, tags/price, location)
/// is usually taller than that, and a stretched photo is what the reference
/// design shows rather than a short image over blank card background.
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
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(width: _kImageWidth, child: _buildImage()),
              Expanded(child: _buildContent(context)),
            ],
          ),
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
        // The favourite toggle moved into the content column (next to the
        // poster row, matching the reference), freeing this corner for the
        // compare button that used to sit beneath it.
        if (onCompareToggle != null)
          Positioned(
            top: AppConstants.spacingS,
            right: AppConstants.spacingS,
            child: _buildCompareButton(),
          ),
        if (property.photoCount > 0)
          Positioned(
            left: AppConstants.spacingS,
            bottom: AppConstants.spacingS,
            child: _buildPhotoCountBadge(),
          ),
      ],
    );
  }

  Widget _buildPhotoCountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppConstants.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.camera_alt_rounded,
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            '${property.photoCount}',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
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

  Widget _buildContent(BuildContext context) {
    final String factsLine = propertyFactsLine(property);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPosterRow(context),
          const SizedBox(height: 8),
          Text(
            property.title,
            style: AppTextStyles.body.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 7),
          _buildTagsAndPriceRow(),
          const SizedBox(height: 6),
          _buildLocationRow(),
          if (factsLine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              factsLine,
              style: AppTextStyles.caption.copyWith(fontSize: 10.5),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Avatar + poster name + "posted X ago", with the favourite/share actions
  /// trailing on the same row — mirrors the reference card's top line.
  Widget _buildPosterRow(BuildContext context) {
    final String? name = property.postedByName;
    final String initials = _initialsFor(name);
    final String postedAgo = propertyPostedAgo(property.createdAt);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PeopleAvatar(avatarUrl: property.postedByAvatarUrl, initials: initials, size: 26),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name?.trim().isNotEmpty == true ? name!.trim() : 'PropCid',
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (property.isVerified) ...[
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.verified_rounded,
                      size: 12,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
              if (postedAgo.isNotEmpty)
                Text(
                  postedAgo,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
        ),
        if (onFavoriteToggle != null) ...[
          const SizedBox(width: 4),
          _buildFavouriteButton(),
        ],
        const SizedBox(width: 4),
        _buildShareButton(context),
      ],
    );
  }

  Widget _buildFavouriteButton() {
    return Semantics(
      label: property.isShortlisted ? 'Remove from saved' : 'Save property',
      button: true,
      child: GestureDetector(
        onTap: onFavoriteToggle,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(
            property.isShortlisted ? Icons.favorite : Icons.favorite_border,
            size: 17,
            color: property.isShortlisted
                ? AppColors.error
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  /// Opens the existing property share sheet (`share_property_sheet.dart`) —
  /// the same one the Property Detail screen already uses — rather than
  /// inventing a second share flow for this card.
  Widget _buildShareButton(BuildContext context) {
    return Semantics(
      label: 'Share property',
      button: true,
      child: GestureDetector(
        onTap: () => showSharePropertySheet(
          context,
          propertyId: property.id,
          title: property.title,
          location: property.location,
          priceDisplay: property.priceDisplay,
          currentUserId: Provider.of<AuthProvider>(
            context,
            listen: false,
          ).userId,
        ),
        behavior: HitTestBehavior.opaque,
        child: const SizedBox(
          width: 26,
          height: 26,
          child: Icon(
            Icons.share_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTagsAndPriceRow() {
    final String? category = property.category;
    final String? listingType = property.propertyType;

    return Row(
      children: [
        // Flexible (not a fixed-size Row child): the chips shrink-to-fit
        // instead of competing with the price for a 50/50 flex split, which is
        // what was clipping the amount down to "₹40…" before.
        Flexible(
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (category != null) _buildCategoryChip(category),
              if (listingType != null) _buildListingChip(listingType),
            ],
          ),
        ),
        const SizedBox(width: 6),
        // Expanded, not Flexible: this claims every pixel left over after the
        // chips instead of splitting it with them, so the full amount always
        // has room to render.
        Expanded(
          child: Text(
            _priceWithSuffix(listingType),
            style: AppTextStyles.price.copyWith(fontSize: 15),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Appends "/month" to a rent listing's price, matching the reference —
  /// `priceDisplay` itself is a plain currency format with no listing-type
  /// awareness, so this only adjusts what's shown, not the underlying value.
  String _priceWithSuffix(String? listingType) {
    if (listingType == 'rent') return '${property.priceDisplay} /month';
    return property.priceDisplay;
  }

  Widget _buildCategoryChip(String category) {
    final (icon, label) = _categoryIconAndLabel(category);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppConstants.chipRadius),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10.5, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.chip.copyWith(
              fontSize: 10,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingChip(String listingType) {
    final String label = _listingTypeLabel(listingType);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _kListingChipBg,
        borderRadius: BorderRadius.circular(AppConstants.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sell_rounded, size: 10.5, color: _kListingChipFg),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.chip.copyWith(
              fontSize: 10,
              color: _kListingChipFg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow() {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 12,
          color: AppColors.textHint,
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Text(
            property.location,
            style: AppTextStyles.caption.copyWith(fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Same 4 categories `FiltersScreen`/`search_screen.dart` already filter by,
  /// plus the 2 the results screen's own `_categoryDisplayName` also handles
  /// (`pg_coliving`, `others`) — mirrored here rather than imported, since
  /// that method is private to `_SearchResultsScreenState`.
  (IconData, String) _categoryIconAndLabel(String category) {
    switch (category) {
      case 'residential':
        return (Icons.home_rounded, 'Residential');
      case 'commercial':
        return (Icons.store_mall_directory_rounded, 'Commercial');
      case 'land':
        return (Icons.landscape_rounded, 'Land');
      case 'pg_coliving':
        return (Icons.groups_rounded, 'PG/Co-living');
      case 'others':
        return (Icons.category_rounded, 'Others');
      default:
        return (Icons.home_work_outlined, category);
    }
  }

  String _listingTypeLabel(String listingType) {
    switch (listingType) {
      case 'sell':
        return 'For Sale';
      case 'rent':
        return 'For Rent';
      case 'lease':
        return 'For Lease';
      default:
        return listingType;
    }
  }

  /// Same 2-letter rule `UserProfile.initials` uses, falling back to "PC"
  /// (PropCid) rather than "U" when there is no poster name at all — this
  /// card's fallback identity is the platform, not a generic user.
  String _initialsFor(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'PC';
    final words = trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'PC';
    final letters = words.take(2).map((w) => w[0].toUpperCase()).join();
    return letters.isEmpty ? 'PC' : letters;
  }
}
