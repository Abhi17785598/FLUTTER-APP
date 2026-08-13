import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/scale_tap.dart';

/// "Create Content" tile grid (blueprint §4.1). Two-up normally; a third
/// "Add Video" tile appears when [onAddVideo] is supplied — mirrors the
/// portal's `CreateContent.tsx`, which only widens this grid to
/// `grid-cols-3` for `userType === 'influencer'` (lines 379-390).
class CreateContentGrid extends StatelessWidget {
  final VoidCallback onAddProperty;
  final VoidCallback onAddArticle;
  final VoidCallback? onAddVideo;

  const CreateContentGrid({
    super.key,
    required this.onAddProperty,
    required this.onAddArticle,
    this.onAddVideo,
  });

  @override
  Widget build(BuildContext context) {
    // `CrossAxisAlignment.stretch` sizes children along the *cross* axis,
    // which for a Row is vertical. This Row lives in a Column inside the
    // Profile screen's SingleChildScrollView, so its incoming height
    // constraint is 0..Infinity — stretch cannot resolve against an infinite
    // maximum, and RenderFlex ends up with no size at all.
    //
    // IntrinsicHeight bounds the cross axis to the taller of the two tiles,
    // which is what stretch needs and what keeps the pair equal-height like
    // the prototype's `1fr 1fr` grid. Same pattern already used by
    // ProfileStatsRow in this scroll view. Two shallow tiles, so the extra
    // measuring pass costs nothing meaningful.
    final addVideo = onAddVideo;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ContentTile(
              icon: Icons.apartment_rounded,
              label: 'Add Property',
              onTap: onAddProperty,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _ContentTile(
              icon: Icons.article_outlined,
              label: 'Add Article',
              onTap: onAddArticle,
            ),
          ),
          if (addVideo != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: _ContentTile(
                icon: Icons.videocam_rounded,
                label: 'Add Video',
                onTap: addVideo,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ContentTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: ScaleTap(
        onTap: onTap,
        child: ColoredBox(
          color: AppColors.background,
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spacingL),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              boxShadow: AppColors.surfaceCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
