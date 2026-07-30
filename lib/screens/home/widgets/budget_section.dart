import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/section_header.dart';

class _BudgetBucket {
  const _BudgetBucket({
    required this.label,
    required this.icon,
    required this.color,
    required this.image,
  });

  final String label;
  final IconData icon;
  final Color color;
  final String image;
}

/// Same 4 buckets, same (unfiltered) `/search-results` navigation as
/// before on every tile — this is a visual-only redesign, so that
/// pre-existing behavior is preserved as-is rather than silently "fixed".
class BudgetSection extends StatelessWidget {
  const BudgetSection({super.key});

  static const List<_BudgetBucket> _budgets = [
    _BudgetBucket(
      label: 'Under ₹50L',
      icon: Icons.home_outlined,
      color: Color(0xFF22C55E),
      image:
          'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?w=400&h=300&fit=crop',
    ),
    _BudgetBucket(
      label: '₹50L – ₹1Cr',
      icon: Icons.apartment,
      color: Color(0xFF3B82F6),
      image:
          'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=400&h=300&fit=crop',
    ),
    _BudgetBucket(
      label: '₹1Cr – ₹2Cr',
      icon: Icons.villa,
      color: AppColors.primary,
      image:
          'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=400&h=300&fit=crop',
    ),
    _BudgetBucket(
      label: '₹2Cr+',
      icon: Icons.business_center,
      color: Color(0xFFF97316),
      image:
          'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=400&h=300&fit=crop',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Browse by Budget'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.3,
            ),
            itemCount: _budgets.length,
            itemBuilder: (context, index) {
              final budget = _budgets[index];
              return GestureDetector(
                onTap: () => Navigator.pushNamed(
                  context,
                  AppConstants.searchResultsScreen,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          budget.image,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(color: budget.color.withOpacity(0.15)),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                budget.color.withOpacity(0.05),
                                Colors.black.withOpacity(0.75),
                              ],
                              stops: const [0.3, 1],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                            child: Icon(
                              budget.icon,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 12,
                          left: 12,
                          right: 12,
                          child: Text(
                            budget.label,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
