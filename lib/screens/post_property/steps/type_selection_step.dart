import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/post_property_provider.dart';

class _CategoryOption {
  final PropertyCategory value;
  final String label;
  final IconData icon;

  const _CategoryOption(this.value, this.label, this.icon);
}

class _IntentOption {
  final ListingIntent value;
  final String label;

  const _IntentOption(this.value, this.label);
}

/// Step 1 of the Post Property wizard: property category + listing intent.
class TypeSelectionStep extends StatelessWidget {
  const TypeSelectionStep({super.key});

  static const _categories = [
    _CategoryOption(PropertyCategory.residential, 'Residential', Icons.home_outlined),
    _CategoryOption(PropertyCategory.commercial, 'Commercial', Icons.store_outlined),
    _CategoryOption(PropertyCategory.land, 'Land / Plot', Icons.landscape_outlined),
    _CategoryOption(PropertyCategory.pg, 'PG / Co-living', Icons.night_shelter_outlined),
    _CategoryOption(PropertyCategory.other, 'Other', Icons.category_outlined),
  ];

  static const _intents = [
    _IntentOption(ListingIntent.sell, 'Sell'),
    _IntentOption(ListingIntent.rent, 'Rent'),
    _IntentOption(ListingIntent.lease, 'Lease'),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          icon: Icons.category_outlined,
          title: 'Property Category',
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 2.5,
            ),
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final option = _categories[index];
              final isSelected = provider.category == option.value;
              return _ChoiceTile(
                icon: option.icon,
                label: option.label,
                isSelected: isSelected,
                onTap: () => context
                    .read<PostPropertyProvider>()
                    .setCategory(option.value),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        _SectionCard(
          icon: Icons.sell_outlined,
          title: 'Listing Intent',
          child: Row(
            children: _intents.map((option) {
              final isSelected = provider.listingIntent == option.value;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _ChoiceTile(
                    label: option.label,
                    isSelected: isSelected,
                    compact: true,
                    onTap: () => context
                        .read<PostPropertyProvider>()
                        .setListingIntent(option.value),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// A premium card wrapper used to group a section of the wizard form.
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool isSelected;
  final bool compact;
  final VoidCallback onTap;

  const _ChoiceTile({
    this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 14 : 0,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected ? null : AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? AppColors.primaryGlow : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: (compact ? AppTextStyles.button : AppTextStyles.body).copyWith(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
