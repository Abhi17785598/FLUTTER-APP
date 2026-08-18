import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../models/property_model.dart';

class PropertyCardCompact extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;

  /// Shown only when the caller supplies it — this card is reused for
  /// browsing (Shortlist, public profiles), where the viewer never owns the
  /// listing, so the edit affordance stays opt-in rather than conditioned on
  /// an ownership flag threaded through every call site.
  final VoidCallback? onEdit;

  /// Same opt-in rule as [onEdit] — only the owner's own "My Content" call
  /// site supplies this, so browsing surfaces never render it.
  final VoidCallback? onDelete;

  const PropertyCardCompact({
    super.key,
    required this.property,
    this.onTap,
    this.onFavoriteToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          border: Border(
            bottom: BorderSide(
              color: AppColors.textHint,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.imageThumbnailRadius),
                  child: CachedNetworkImage(
                    imageUrl: property.imageUrl,
                    width: AppConstants.propertyCompactImageWidth,
                    height: AppConstants.propertyCompactImageHeight,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.textHint.withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.textHint.withOpacity(0.1),
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
                if (property.isVerified)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.verifiedBadge,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Verified',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${property.photoCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    property.priceDisplay,
                    style: AppTextStyles.price.copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    // Land/Plot has no bedroom/bathroom concept (mirrors the
                    // portal's `property.category === 'land'` branch in
                    // PropertyCard.tsx) — show area alone for that category.
                    property.category == 'land'
                        ? '${property.sqft} Sq.ft'
                        : '${property.sqft} Sq.ft • ${property.beds} Beds • ${property.baths} Baths',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onEdit != null)
              GestureDetector(
                onTap: onEdit,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Icon(
                    Icons.edit_outlined,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ),
              ),
            if (onDelete != null)
              GestureDetector(
                onTap: onDelete,
                child: const Padding(
                  padding: EdgeInsets.only(bottom: 8, left: 8),
                  child: Icon(
                    Icons.delete_outline,
                    color: AppColors.textSecondary,
                    size: 22,
                  ),
                ),
              ),
            GestureDetector(
              onTap: onFavoriteToggle,
              child: Icon(
                Icons.favorite,
                color: Colors.red,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
