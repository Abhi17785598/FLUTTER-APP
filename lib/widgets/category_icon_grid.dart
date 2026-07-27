import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

class CategoryItem {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color iconColor;

  CategoryItem({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.iconColor,
  });
}

class CategoryIconGrid extends StatelessWidget {
  final Function(String)? onCategoryTap;

  const CategoryIconGrid({
    super.key,
    this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    final categories = [
      CategoryItem(
        label: 'Buy\nProperties',
        icon: Icons.home,
        bgColor: AppColors.categoryBuyBg,
        iconColor: AppColors.primary,
      ),
      CategoryItem(
        label: 'Rent\nProperties',
        icon: Icons.apartment,
        bgColor: AppColors.categoryRentBg,
        iconColor: const Color(0xFF3B82F6),
      ),
      CategoryItem(
        label: 'Plots /\nLands',
        icon: Icons.flag,
        bgColor: AppColors.categoryPlotBg,
        iconColor: const Color(0xFF22C55E),
      ),
      CategoryItem(
        label: 'Commercial\nSpaces',
        icon: Icons.business,
        bgColor: AppColors.categoryCommercialBg,
        iconColor: const Color(0xFFF97316),
      ),
      CategoryItem(
        label: 'PG /\nCo-living',
        icon: Icons.bed,
        bgColor: AppColors.categoryPgBg,
        iconColor: const Color(0xFFEC4899),
      ),
    ];

    return SizedBox(
      // ✅ FIX: was 90 — increased to 100 to fit icon (52) + gap (8) + 2-line text (~34) = 94 → give 100
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () =>
                  onCategoryTap?.call(category.label.replaceAll('\n', ' ')),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: AppConstants.categoryIconSize,
                    height: AppConstants.categoryIconSize,
                    decoration: BoxDecoration(
                      color: category.bgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      category.icon,
                      color: category.iconColor,
                      size: AppConstants.categoryIconInnerSize,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 64,
                    child: Text(
                      category.label,
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
