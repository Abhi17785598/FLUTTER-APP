import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/gradient_text.dart';
import '../../../widgets/search_bar_widget.dart';

/// Welcome heading + the premium search bar. Same two navigations as before
/// (tap the bar → Search; tap the mic → Search with `autoStartVoice: true`) —
/// only the visual treatment changes.
class PremiumSearchSection extends StatelessWidget {
  const PremiumSearchSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back,',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              Row(
                children: [
                  Text('Find your perfect ', style: AppTextStyles.heading1),
                  const GradientText(
                    text: 'property',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text(' 🏡', style: TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppColors.cardShadow,
                ),
                child: SearchBarWidget(
                  hint: 'Search properties, locations...',
                  onTap: () =>
                      Navigator.pushNamed(context, AppConstants.searchScreen),
                  trailing: GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppConstants.searchScreen,
                      arguments: {'autoStartVoice': true},
                    ),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: AppColors.primaryGlow,
                      ),
                      child: const Icon(
                        Icons.mic,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.08, end: 0, duration: 400.ms, curve: Curves.easeOut);
  }
}
