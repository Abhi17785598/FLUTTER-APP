import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_text.dart';
import '../../core/widgets/premium_button.dart';
import '../../core/widgets/step_indicator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_property_provider.dart';
import '../../services/property_service.dart';
import 'steps/type_selection_step.dart';
import 'steps/basic_info_step.dart';
import 'steps/property_dimensions_step.dart';
import 'steps/condition_step.dart';
import 'steps/amenities_step.dart';
import 'steps/legal_details_step.dart';
import 'steps/pricing_step.dart';
import 'steps/media_contact_step.dart';
import 'steps/review_step.dart';
import 'property_submission_confirmation_screen.dart';

/// Post Property wizard shell.
///
/// Implements the full 9-step frontend flow (type selection, basic info,
/// dimensions, condition, amenities, legal, pricing, media & contact, review)
/// across all 5 property categories. On the final step, tapping Publish
/// triggers [PostPropertyProvider.submit] → [PropertyService.createProperty]
/// which uploads media and writes to Supabase.
///
/// Pass [editPropertyId] + [editBundle] when opening for an existing listing —
/// the wizard pre-fills all fields via [PostPropertyProvider.initFromRawData]
/// and switches submit to UPDATE mode.
class PostPropertyScreen extends StatelessWidget {
  final String? editPropertyId;
  final PropertyEditBundle? editBundle;

  const PostPropertyScreen({
    super.key,
    this.editPropertyId,
    this.editBundle,
  });

  static const _stepLabels = [
    'Type',
    'Basic Info',
    'Dimensions',
    'Condition',
    'Amenities',
    'Legal',
    'Pricing',
    'Media',
    'Review',
  ];

  static const _stepHeadings = [
    ('What are you listing?', 'Choose a category and how you want to list it'),
    ('Tell us the basics', 'Add the core details buyers will see first'),
    ('Dimensions & Layout', 'Specify the physical size and layout of the property'),
    ('Condition & Furnishing', "Tell us about the property's age, availability and furnishings"),
    ('Amenities & Facilities', 'What facilities are available at this property?'),
    ('Legal & Approvals', 'Provide legal and documentation status for transparency'),
    ('Pricing & Terms', 'Provide pricing details, terms and conditions'),
    ('Media & Contact', 'Add photos and how buyers can reach you'),
    ('Review Your Listing', 'Check everything before you finish'),
  ];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PostPropertyProvider(),
      child: _PostPropertyWizard(
        stepLabels: _stepLabels,
        stepHeadings: _stepHeadings,
        editPropertyId: editPropertyId,
        editBundle: editBundle,
      ),
    );
  }
}

class _PostPropertyWizard extends StatefulWidget {
  final List<String> stepLabels;
  final List<(String, String)> stepHeadings;
  final String? editPropertyId;
  final PropertyEditBundle? editBundle;

  const _PostPropertyWizard({
    required this.stepLabels,
    required this.stepHeadings,
    this.editPropertyId,
    this.editBundle,
  });

  @override
  State<_PostPropertyWizard> createState() => _PostPropertyWizardState();
}

class _PostPropertyWizardState extends State<_PostPropertyWizard> {
  @override
  void initState() {
    super.initState();
    final bundle = widget.editBundle;
    final id = widget.editPropertyId;
    if (bundle != null && id != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<PostPropertyProvider>().initFromRawData(
          editingPropertyId: id,
          propertyRow: bundle.propertyRow,
          subtableRow: bundle.subtableRow,
          contactRow: bundle.contactRow,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (provider.currentStep > 0) {
              provider.previousStep();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          provider.isEditMode ? 'Edit Property' : 'Post Property',
          style: AppTextStyles.heading2.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 640;
          final horizontalPadding = isWide ? 40.0 : 20.0;
          final maxContentWidth = isWide ? 560.0 : double.infinity;

          return SafeArea(
            child: Column(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          horizontalPadding, 12, horizontalPadding, 20),
                      child: StepIndicator(
                        currentStep: provider.currentStep,
                        stepLabels: widget.stepLabels,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxContentWidth),
                      child: ClipRect(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 320),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final slide = Tween<Offset>(
                              begin: const Offset(0.06, 0),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: slide,
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            key: ValueKey(provider.currentStep),
                            padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _StepHeader(
                                    stepNumber: provider.currentStep + 1,
                                    totalSteps: widget.stepLabels.length,
                                    title: widget.stepHeadings[provider.currentStep].$1,
                                    subtitle:
                                        widget.stepHeadings[provider.currentStep].$2,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildStepContent(provider.currentStep),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _NavigationBar(
                  provider: provider,
                  maxContentWidth: maxContentWidth,
                  horizontalPadding: horizontalPadding,
                ),
              ],
            ),
          );
        },
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildStepContent(int step) {
    switch (step) {
      case 0:
        return const TypeSelectionStep();
      case 1:
        return const BasicInfoStep();
      case 2:
        return const PropertyDimensionsStep();
      case 3:
        return const ConditionStep();
      case 4:
        return const AmenitiesStep();
      case 5:
        return const LegalDetailsStep();
      case 6:
        return const PricingStep();
      case 7:
        return const MediaContactStep();
      case 8:
      default:
        return const ReviewStep();
    }
  }
}

class _StepHeader extends StatelessWidget {
  final int stepNumber;
  final int totalSteps;
  final String title;
  final String subtitle;

  const _StepHeader({
    required this.stepNumber,
    required this.totalSteps,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP $stepNumber OF $totalSteps',
          style: AppTextStyles.caption.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        GradientText(
          text: title,
          style: AppTextStyles.heading1.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final PostPropertyProvider provider;
  final double maxContentWidth;
  final double horizontalPadding;

  const _NavigationBar({
    required this.provider,
    required this.maxContentWidth,
    required this.horizontalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxContentWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 16, horizontalPadding, 16),
              child: Row(
                children: [
                  if (provider.currentStep > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: provider.isSubmitting ? null : provider.previousStep,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: AppTextStyles.button.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    flex: 2,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: (provider.canGoNext && !provider.isSubmitting) ? 1 : 0.5,
                      child: PremiumButton(
                        label: provider.isLastStep
                            ? (provider.isEditMode ? 'Update Property' : 'Publish')
                            : 'Next',
                        height: 52,
                        isLoading: provider.isSubmitting,
                        onPressed: (provider.canGoNext && !provider.isSubmitting)
                            ? () => _onPrimaryAction(context, provider)
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onPrimaryAction(BuildContext context, PostPropertyProvider provider) {
    if (!provider.isLastStep) {
      provider.nextStep();
      return;
    }
    _submitProperty(context, provider);
  }

  Future<void> _submitProperty(
    BuildContext context,
    PostPropertyProvider provider,
  ) async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to publish a listing.'),
        ),
      );
      return;
    }

    try {
      final propertyId = await provider.submit(PropertyService(), userId);
      if (!context.mounted) return;
      if (provider.isEditMode) {
        Navigator.of(context).pop(true);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PropertySubmissionConfirmationScreen(propertyId: propertyId),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }
}
