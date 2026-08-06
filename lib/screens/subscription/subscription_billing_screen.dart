import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/animations/page_transitions.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/shared/app_action_button.dart';
import '../../widgets/shared/section_header_back_button.dart';
import '../shared/section_loader.dart';
import 'billing_policies_screen.dart';
import 'widgets/subscription_tabs.dart';

/// The ten entries in the design's horizontal tab strip.
enum SubscriptionTab {
  overview('Overview', Icons.grid_view_rounded),
  billing('Billing', Icons.credit_card_outlined),
  payments('Payments', Icons.credit_card_outlined),
  features('Features', Icons.card_giftcard_outlined),
  invoices('Invoices', Icons.receipt_long_outlined),
  usage('Usage', Icons.bar_chart_rounded),
  security('Security', Icons.verified_user_outlined),
  refunds('Refunds', Icons.refresh),
  help('Help', Icons.settings_outlined),

  /// Navigates to [BillingPoliciesScreen] rather than rendering inline — the
  /// design has no `isTabPolicies` body, it has a separate policies screen.
  policies('Billing Policies', Icons.article_outlined);

  const SubscriptionTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Subscription & Billing — the design's `isSubHome` screen.
///
/// Read-only throughout. Every mutating billing path React owns
/// (`create-order`, `verify-payment`, `refund-payment`, `manage-subscription`,
/// `update-billing-profile`) is deliberately out of scope: those move money
/// through Razorpay, which this app has no integration for. Actions that would
/// write land on the shared placeholder, and "Upgrade" goes to the real
/// [UpgradeScreen] delivered in Phase 6.
class SubscriptionBillingScreen extends StatelessWidget {
  const SubscriptionBillingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SubscriptionProvider(),
      child: const _SubscriptionBillingView(),
    );
  }
}

class _SubscriptionBillingView extends StatefulWidget {
  const _SubscriptionBillingView();

  @override
  State<_SubscriptionBillingView> createState() =>
      _SubscriptionBillingViewState();
}

class _SubscriptionBillingViewState extends State<_SubscriptionBillingView> {
  String? _loadedUserId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  void _loadIfNeeded() {
    if (!mounted) return;
    final userId = context.read<AuthProvider>().userId;
    if (userId == null || userId == _loadedUserId) return;
    _loadedUserId = userId;

    // Deferred to the end of the frame with the provider captured up front —
    // `load()` notifies before its first `await`, and this runs inside the
    // build phase. Same lifecycle fix as Profile, Messages and Network.
    final provider = context.read<SubscriptionProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.load(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();

    return SubscriptionBillingBody(
      data: SubscriptionTabData(
        subscription: provider.subscription,
        billingProfile: provider.billingProfile,
        payments: provider.completedPayments,
        refunds: provider.refunds,
        totalBilled: provider.totalBilled,
        historyFailed: provider.historyFailed,
        subscriptionFailed: provider.subscriptionFailed,
      ),
      loading: provider.loading,
    );
  }
}

/// The screen's visuals, separated from the provider that feeds them so the
/// layout is testable without an [AuthProvider] (which needs a live Supabase
/// client).
class SubscriptionBillingBody extends StatefulWidget {
  final SubscriptionTabData data;
  final bool loading;

  const SubscriptionBillingBody({
    super.key,
    required this.data,
    required this.loading,
  });

  @override
  State<SubscriptionBillingBody> createState() =>
      _SubscriptionBillingBodyState();
}

class _SubscriptionBillingBodyState extends State<SubscriptionBillingBody> {
  SubscriptionTab _tab = SubscriptionTab.overview;

  void _openUpgrade() {
    Navigator.of(context).pushNamed(AppConstants.upgradeScreen);
  }

  void _openPolicies() {
    Navigator.of(context).push(
      PremiumPageRoute(builder: (_) => const BillingPoliciesScreen()),
    );
  }

  void _selectTab(SubscriptionTab tab) {
    if (tab == SubscriptionTab.policies) {
      _openPolicies();
      return;
    }
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DashboardHeaderBar(title: 'Subscription & Billing'),
              const SizedBox(height: 18),
              _CurrentPlanCard(
                data: widget.data,
                loading: widget.loading,
                onUpgrade: _openUpgrade,
              ),
              const SizedBox(height: 14),
              _TabStrip(selected: _tab, onSelect: _selectTab),
              const SizedBox(height: 4),
              Text(
                'Swipe or scroll to see more tabs →',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: AppColors.textHint,
                ),
              ),
              _buildTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab() {
    final data = widget.data;

    switch (_tab) {
      case SubscriptionTab.overview:
        return OverviewTab(data: data);
      case SubscriptionTab.billing:
        return BillingTab(
          data: data,
          onUpgrade: _openUpgrade,
          onCancel: () => openSectionPlaceholder(context, 'Cancel Subscription'),
          onSaveDetails: () => openSectionPlaceholder(context, 'Edit Billing Details'),
        );
      case SubscriptionTab.payments:
        return PaymentsTab(data: data);
      case SubscriptionTab.features:
        return FeaturesTab(data: data, onUpgrade: _openUpgrade);
      case SubscriptionTab.invoices:
        return InvoicesTab(
          data: data,
          onDownload: (_) => openSectionPlaceholder(context, 'Download Invoice'),
        );
      case SubscriptionTab.usage:
        return UsageTab(data: data);
      case SubscriptionTab.security:
        return SecurityTab(
          data: data,
          onUpgrade: _openUpgrade,
          onComparePlans: _openUpgrade,
          onPolicies: _openPolicies,
          onContactSupport: () => openSectionPlaceholder(context, 'Contact Support'),
          onManagePaymentMethod: () => openSectionPlaceholder(context, 'Payment Methods'),
        );
      case SubscriptionTab.refunds:
        return RefundsTab(data: data, onViewPlans: _openUpgrade);
      case SubscriptionTab.help:
        return HelpTab(
          onPolicies: _openPolicies,
          onContactSupport: () => openSectionPlaceholder(context, 'Contact Support'),
          onRaiseTicket: () => openSectionPlaceholder(context, 'Raise a Ticket'),
        );
      case SubscriptionTab.policies:
        // Never selected — _selectTab navigates instead. Kept exhaustive so a
        // new tab cannot be added without handling it here.
        return const SizedBox.shrink();
    }
  }
}

/// The plan summary card: plan, status chips, price and renewal.
class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionTabData data;
  final bool loading;
  final VoidCallback onUpgrade;

  const _CurrentPlanCard({
    required this.data,
    required this.loading,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The design places the price/renewal block beside the plan block.
          // That pairing needs roughly 280 dp of card width; below that the two
          // compete for the same row and the plan name gets squeezed to an
          // ellipsis, so they stack instead. The wide layout is unchanged at
          // every normal device width.
          LayoutBuilder(
            builder: (context, constraints) {
              final planBlock = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _planDetails()),
                ],
              );

              if (constraints.maxWidth < 280) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    planBlock,
                    const SizedBox(height: AppConstants.spacingM),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _priceBlock(CrossAxisAlignment.start),
                        ),
                        const SizedBox(width: AppConstants.spacingS),
                        Expanded(
                          child: _renewalBlock(CrossAxisAlignment.end),
                        ),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _planDetails()),
                  const SizedBox(width: AppConstants.spacingS),
                  // Bounded so a long amount can never push the row past the
                  // card; the value scales down rather than clipping.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 104),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _priceBlock(CrossAxisAlignment.end),
                        const SizedBox(height: 6),
                        _renewalBlock(CrossAxisAlignment.end),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppConstants.spacingM),
          AppActionButton(
            label: 'Upgrade',
            height: 40,
            trailingIcon: Icons.chevron_right,
            onTap: onUpgrade,
          ),
        ],
      ),
    );
  }

  Widget _planDetails() {
    final sub = data.subscription;
    final failed = data.subscriptionFailed;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'CURRENT PLAN',
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.textHint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          loading ? 'Loading…' : (failed ? 'Unavailable' : sub.planLabel),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.heading1.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        if (!loading && !failed) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StatusChip(sub.status, solid: true),
              _StatusChip(sub.billingCycle),
              _StatusChip(
                sub.autoRenew ? 'Auto-renew on' : 'Auto-renew off',
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _priceBlock(CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _MicroLabel('PRICE'),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == CrossAxisAlignment.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            loading ? '—' : '${data.priceLabel}/mo',
            maxLines: 1,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _renewalBlock(CrossAxisAlignment align) {
    final renewal = data.subscription.renewalLabel;

    return Column(
      crossAxisAlignment: align,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _MicroLabel('RENEWAL'),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: align == CrossAxisAlignment.end
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            loading ? '—' : (renewal ?? 'N/A'),
            maxLines: 1,
            style: AppTextStyles.body.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MicroLabel extends StatelessWidget {
  final String text;

  const _MicroLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textHint,
      ),
    );
  }
}

/// 20 dp status pill — solid primary for the subscription status, outlined for
/// the supporting facts.
class _StatusChip extends StatelessWidget {
  final String text;
  final bool solid;

  const _StatusChip(this.text, {this.solid = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: solid ? AppColors.primary : null,
        borderRadius: BorderRadius.circular(AppConstants.pillRadius),
        border: solid ? null : Border.all(color: AppColors.hairline),
      ),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: solid ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}

/// Horizontally scrolling tab strip with the design's right-edge fade.
class _TabStrip extends StatelessWidget {
  final SubscriptionTab selected;
  final ValueChanged<SubscriptionTab> onSelect;

  const _TabStrip({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Stack(
        children: [
          ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 2),
            children: [
              for (final tab in SubscriptionTab.values) ...[
                if (tab != SubscriptionTab.values.first)
                  const SizedBox(width: 6),
                _TabPill(
                  tab: tab,
                  active: tab == selected,
                  onTap: () => onSelect(tab),
                ),
              ],
            ],
          ),
          // Fades the strip out at the right edge so it reads as scrollable.
          Positioned(
            right: 0,
            top: 0,
            bottom: 2,
            child: IgnorePointer(
              child: Container(
                width: 28,
                alignment: Alignment.centerRight,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x00F4F4F8), AppColors.background],
                  ),
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPill extends StatelessWidget {
  final SubscriptionTab tab;
  final bool active;
  final VoidCallback onTap;

  const _TabPill({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tab.label,
      button: true,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryLight : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tab.icon,
                size: 15,
                color: active ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
              Text(
                tab.label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
