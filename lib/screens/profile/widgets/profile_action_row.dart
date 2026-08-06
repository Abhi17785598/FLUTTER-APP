import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/scale_tap.dart';

/// Edit Profile / Share / QR action row (blueprint §4.1).
class ProfileActionRow extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onShare;
  final VoidCallback onQr;

  const ProfileActionRow({
    super.key,
    required this.onEdit,
    required this.onShare,
    required this.onQr,
  });

  static const double _kHeight = 44;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FilledAction(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: onEdit,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OutlinedAction(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: onShare,
          ),
        ),
        const SizedBox(width: 10),
        _SquareAction(
          icon: Icons.qr_code_2_rounded,
          semanticLabel: 'Profile QR code',
          onTap: onQr,
        ),
      ],
    );
  }
}

class _FilledAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _FilledAction({
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
            height: ProfileActionRow._kHeight,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
              boxShadow: AppColors.primaryActionShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppTextStyles.button.copyWith(fontSize: 13.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlinedAction({
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
            height: ProfileActionRow._kHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
              border: Border.all(color: AppColors.primary, width: 1.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: AppTextStyles.button.copyWith(
                    fontSize: 13.5,
                    color: AppColors.primary,
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

class _SquareAction extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  const _SquareAction({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: ScaleTap(
        onTap: onTap,
        child: ColoredBox(
          color: AppColors.background,
          child: Container(
            width: ProfileActionRow._kHeight,
            height: ProfileActionRow._kHeight,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
