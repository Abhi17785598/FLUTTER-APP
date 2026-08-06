import 'package:flutter/material.dart';

import '../../core/animations/page_transitions.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/scale_tap.dart';
import '../../widgets/shared/section_header_back_button.dart';
import '../../widgets/shared/toggle_row.dart';
import '../stubs/coming_soon_screen.dart';
import 'plan_catalogue.dart';

/// Upgrade Your Plan — the plan ladder with a monthly/yearly switch.
///
/// Design: the `isSubscription` screen. Functionally this is React's
/// `PlanUpgradeSection` + `UpgradePlanCard` pair, reading the same kind of
/// static plan config (`planConfig.ts` there, [PlanCatalogue] here) rather than
/// any table.
///
/// Checkout is not part of this phase — React's flow is a four-step
/// `CheckoutModal` with a payment provider behind it, and the design carries
/// its own `isCheckout` and `isPaymentSuccess` screens. Every paid CTA
/// therefore lands on the honest placeholder instead of a dead button or a
/// half-wired payment form.
class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  bool _yearly = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DashboardHeaderBar(
                title: 'Upgrade Your Plan',
                subtitle: 'Unlock more features and grow faster on PropCid',
              ),
              const SizedBox(height: 18),
              _BillingPeriodSwitch(
                yearly: _yearly,
                onChanged: (value) => setState(() => _yearly = value),
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < PlanCatalogue.plans.length; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                _PlanCard(
                  plan: PlanCatalogue.plans[i],
                  yearly: _yearly,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "Monthly · switch · Yearly" with a Save 20% pill once Yearly is selected.
class _BillingPeriodSwitch extends StatelessWidget {
  final bool yearly;
  final ValueChanged<bool> onChanged;

  const _BillingPeriodSwitch({required this.yearly, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Billing period',
      value: yearly ? 'Yearly' : 'Monthly',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PeriodLabel(
            'Monthly',
            selected: !yearly,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 10),
          // The design's larger 44×26 track, primary in both positions since
          // this selects between two periods rather than switching a setting
          // on and off.
          ExcludeSemantics(
            child: AppToggle(
              value: yearly,
              onChanged: onChanged,
              trackWidth: 44,
              trackHeight: 26,
              knobSize: 22,
              inactiveTrackColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          _PeriodLabel(
            'Yearly',
            selected: yearly,
            onTap: () => onChanged(true),
          ),
          if (yearly) ...[
            const SizedBox(width: 10),
            const _SavingPill(),
          ],
        ],
      ),
    );
  }
}

class _PeriodLabel extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _PeriodLabel(this.text, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Text(
        text,
        style: AppTextStyles.body.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.textPrimary : AppColors.textHint,
        ),
      ),
    );
  }
}

/// `Save 20%` — 20 dp amber pill.
class _SavingPill extends StatelessWidget {
  const _SavingPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3E2),
        borderRadius: BorderRadius.circular(AppConstants.pillRadius),
      ),
      child: Text(
        PlanCatalogue.yearlySavingLabel,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFB45309),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanDefinition plan;
  final bool yearly;

  const _PlanCard({required this.plan, required this.yearly});

  @override
  Widget build(BuildContext context) {
    final price = yearly ? plan.yearlyPricePerMonth : plan.monthlyPrice;
    final showBilledNote = yearly && plan.yearlyTotal != null;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppColors.surfaceCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 dp down, leaving room for the badge that overhangs the top edge.
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: plan.tintBackground,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(plan.icon, size: 20, color: plan.tint),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.name,
                      style: AppTextStyles.heading3.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      plan.description,
                      style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹$price',
                style: AppTextStyles.heading1.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                yearly ? '/year' : '/month',
                style: AppTextStyles.caption.copyWith(fontSize: 12.5),
              ),
            ],
          ),
          if (showBilledNote) ...[
            const SizedBox(height: 2),
            Text(
              'Billed annually (₹${plan.yearlyTotal}/year)',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
          ],
          const SizedBox(height: 14),
          for (var i = 0; i < plan.features.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            _FeatureRow(feature: plan.features[i]),
          ],
          const SizedBox(height: AppConstants.spacingL),
          _PlanCta(plan: plan),
        ],
      ),
    );

    if (plan.badge == null) return card;

    // The badge overhangs the card's top edge by 11 dp, so the stack is allowed
    // to paint outside its bounds and the row is padded to make room.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        card,
        Positioned(
          top: -11,
          left: AppConstants.spacingL,
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: plan.badgeColor ?? AppColors.primary,
              borderRadius: BorderRadius.circular(AppConstants.pillRadius),
            ),
            child: Text(
              plan.badge!,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final PlanFeature feature;

  const _FeatureRow({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          feature.included ? Icons.check : Icons.close,
          size: 15,
          color: feature.included
              ? AppColors.success
              : const Color(0xFFD1D5DB),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            feature.label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12.5,
              color: feature.included
                  ? AppColors.textPrimary
                  : AppColors.textHint,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanCta extends StatelessWidget {
  final PlanDefinition plan;

  const _PlanCta({required this.plan});

  @override
  Widget build(BuildContext context) {
    final isCurrent = plan.ctaStyle == PlanCtaStyle.current;
    final isSolid = plan.ctaStyle == PlanCtaStyle.solid;

    final button = Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFFE7F8ED)
            : (isSolid ? AppColors.primary : AppColors.cardBackground),
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        border: plan.ctaStyle == PlanCtaStyle.outline
            ? Border.all(color: AppColors.primary, width: 1.5)
            : null,
        boxShadow: isSolid ? AppColors.primaryActionShadow : null,
      ),
      child: Text(
        plan.cta,
        style: AppTextStyles.button.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isCurrent
              ? AppColors.success
              : (isSolid ? Colors.white : AppColors.primary),
        ),
      ),
    );

    // The design gives the current plan no onClick, so it stays a label.
    if (isCurrent) return button;

    return Semantics(
      label: plan.cta,
      button: true,
      child: ScaleTap(
        onTap: () => Navigator.of(context).push(
          PremiumPageRoute(
            builder: (_) => ComingSoonScreen(title: '${plan.name} checkout'),
          ),
        ),
        child: button,
      ),
    );
  }
}
