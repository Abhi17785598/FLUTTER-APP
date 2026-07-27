import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_constants.dart';

class StatusTag extends StatelessWidget {
  final String label;

  const StatusTag({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.getStatusChipBg(label),
        borderRadius: BorderRadius.circular(AppConstants.chipRadius),
      ),
      child: Text(
        label,
        style: AppTextStyles.chip.copyWith(
          color: AppColors.getStatusChipText(label),
        ),
      ),
    );
  }
}
