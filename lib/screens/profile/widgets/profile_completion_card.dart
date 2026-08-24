import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/profile_completion.dart';
import '../../../core/widgets/scale_tap.dart';

/// Profile-completion progress with a next-step hint (blueprint §4.1).
///
/// The percentage comes from [calculateProfileCompletion], a pure port of
/// React's `getCompletionItems()`, so the number matches the web app for the
/// same profile. Tapping opens the same edit-profile destination the Edit
/// button uses — mirroring React, where the widget is itself a button to
/// `/edit-profile`.
class ProfileCompletionCard extends StatelessWidget {
  final ProfileCompletion completion;
  final VoidCallback onTap;

  const ProfileCompletionCard({
    super.key,
    required this.completion,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = completion.percentage;
    final next = completion.nextItem;

    return Semantics(
      label: 'Profile completion $percentage percent',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Profile Completion',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$percentage%',
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.pillRadius),
                  child: LinearProgressIndicator(
                    value: percentage / 100,
                    minHeight: 7,
                    backgroundColor: AppColors.primaryLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  // Derived from the checklist rather than hardcoded, so the
                  // hint always names something that actually moves the bar.
                  next == null
                      ? 'Your profile is complete'
                      : 'Add ${next.label.toLowerCase()} to reach 100%',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    color: AppColors.textHint,
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
