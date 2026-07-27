import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/premium_button.dart';

/// Terminal screen shown after a listing is successfully published to Supabase.
class PropertySubmissionConfirmationScreen extends StatelessWidget {
  final String? propertyId;

  const PropertySubmissionConfirmationScreen({this.propertyId, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.primaryGlow,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
              ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 28),
              Text(
                propertyId != null ? 'Your listing is live!' : 'Your listing is ready',
                textAlign: TextAlign.center,
                style: AppTextStyles.heading1.copyWith(fontWeight: FontWeight.w700),
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
              const SizedBox(height: 12),
              Text(
                propertyId != null
                    ? 'Your property has been submitted and is now visible to buyers.'
                    : "You've completed every step of the property wizard.",
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ).animate().fadeIn(delay: 250.ms, duration: 300.ms),
              const SizedBox(height: 36),
              SizedBox(
                width: double.infinity,
                child: PremiumButton(
                  label: 'Done',
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
            ],
          ),
        ),
      ),
    );
  }
}
