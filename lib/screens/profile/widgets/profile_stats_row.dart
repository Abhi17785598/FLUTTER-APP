import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/profile_stats.dart';

/// Followers / Reviews / Profile Views, in one card divided into thirds
/// (blueprint §4.1).
///
/// Every number is real, sourced from `builder_networks`, `user_ratings` and
/// `profile_views` respectively — none are hardcoded. While loading, each
/// value is a shimmer box rather than `0`, since a bare zero reads as a real
/// (wrong) answer (blueprint §12).
class ProfileStatsRow extends StatelessWidget {
  final ProfileStats stats;
  final bool isLoading;

  /// When the stat queries failed, values render as `—` instead of `0` so a
  /// failure is never mistaken for an empty profile.
  final bool hasFailed;

  const ProfileStatsRow({
    super.key,
    required this.stats,
    required this.isLoading,
    this.hasFailed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppColors.surfaceCardShadow,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _StatTile(
                value: stats.followers,
                label: 'Followers',
                isLoading: isLoading,
                hasFailed: hasFailed,
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatTile(
                value: stats.reviews,
                label: 'Reviews',
                isLoading: isLoading,
                hasFailed: hasFailed,
              ),
            ),
            const _StatDivider(),
            Expanded(
              child: _StatTile(
                value: stats.profileViews,
                label: 'Profile Views',
                isLoading: isLoading,
                hasFailed: hasFailed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const VerticalDivider(
      width: 1,
      thickness: 1,
      color: Color(0xFFF0F0F4),
      indent: 2,
      endIndent: 2,
    );
  }
}

class _StatTile extends StatelessWidget {
  final int value;
  final String label;
  final bool isLoading;
  final bool hasFailed;

  const _StatTile({
    required this.value,
    required this.label,
    required this.isLoading,
    required this.hasFailed,
  });

  /// 2300 -> "2.3K", 1_240_000 -> "1.2M". Matches the prototype's compact
  /// presentation without misreporting the underlying number.
  static String formatCount(int value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return '${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return '${k.toStringAsFixed(k >= 10 ? 0 : 1)}K';
    }
    return '$value';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: isLoading ? '$label loading' : '$value $label',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: 34,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            )
          else
            Text(
              hasFailed ? '—' : formatCount(value),
              style: AppTextStyles.heading3.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
