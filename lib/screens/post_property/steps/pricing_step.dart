import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/wizard_kit.dart';
import '../../../providers/post_property_provider.dart';

/// Step 7: pricing terms beyond the headline price already captured in Basic
/// Info — rate/deposit/maintenance/booking/lock-in, negotiability toggles and
/// brokerage (shared), plus Commercial investment/lease-term fields and
/// PG rent/sale/lease-specific fields. Mirrors the React PricingStep.
class PricingStep extends StatefulWidget {
  const PricingStep({super.key});

  @override
  State<PricingStep> createState() => _PricingStepState();
}

class _PricingStepState extends State<PricingStep> {
  static const _lockInOptions = ['None', '3 Months', '6 Months', '1 Year', '2 Years'];

  late final TextEditingController _ratePerAreaController;
  late final TextEditingController _securityDepositController;
  late final TextEditingController _maintenanceController;
  late final TextEditingController _bookingAmountController;
  late final TextEditingController _brokerageController;

  // Commercial
  late final TextEditingController _roiEstimateController;
  late final TextEditingController _currentRentalIncomeController;
  late final TextEditingController _leaseDurationController;
  late final TextEditingController _leaseEscalationController;
  late final TextEditingController _camChargesController;
  late final TextEditingController _fitOutPeriodController;

  // PG
  late final TextEditingController _monthlyRentPerBedController;
  late final TextEditingController _monthlyRentPerRoomController;
  late final TextEditingController _foodChargesController;
  late final TextEditingController _laundryChargesController;
  late final TextEditingController _totalSalePriceController;
  late final TextEditingController _occupancyRateController;

  @override
  void initState() {
    super.initState();
    final p = context.read<PostPropertyProvider>();
    _ratePerAreaController = TextEditingController(text: p.ratePerArea);
    _securityDepositController = TextEditingController(text: p.securityDeposit);
    _maintenanceController = TextEditingController(text: p.maintenanceCharges);
    _bookingAmountController = TextEditingController(text: p.bookingAmount);
    _brokerageController = TextEditingController(text: p.brokerage);

    _roiEstimateController = TextEditingController(text: p.text('roiEstimate'));
    _currentRentalIncomeController = TextEditingController(text: p.text('currentRentalIncome'));
    _leaseDurationController = TextEditingController(text: p.text('leaseDuration'));
    _leaseEscalationController = TextEditingController(text: p.text('leaseEscalationPercent'));
    _camChargesController = TextEditingController(text: p.text('camCharges'));
    _fitOutPeriodController = TextEditingController(text: p.text('fitOutPeriod'));

    _monthlyRentPerBedController = TextEditingController(text: p.text('monthlyRentPerBed'));
    _monthlyRentPerRoomController = TextEditingController(text: p.text('monthlyRentPerRoom'));
    _foodChargesController = TextEditingController(text: p.text('foodCharges'));
    _laundryChargesController = TextEditingController(text: p.text('laundryCharges'));
    _totalSalePriceController = TextEditingController(text: p.text('totalSalePrice'));
    _occupancyRateController = TextEditingController(text: p.text('occupancyRate'));
  }

  @override
  void dispose() {
    _ratePerAreaController.dispose();
    _securityDepositController.dispose();
    _maintenanceController.dispose();
    _bookingAmountController.dispose();
    _brokerageController.dispose();
    _roiEstimateController.dispose();
    _currentRentalIncomeController.dispose();
    _leaseDurationController.dispose();
    _leaseEscalationController.dispose();
    _camChargesController.dispose();
    _fitOutPeriodController.dispose();
    _monthlyRentPerBedController.dispose();
    _monthlyRentPerRoomController.dispose();
    _foodChargesController.dispose();
    _laundryChargesController.dispose();
    _totalSalePriceController.dispose();
    _occupancyRateController.dispose();
    super.dispose();
  }

  String _priceLabel(ListingIntent? intent) {
    switch (intent) {
      case ListingIntent.rent:
        return 'Monthly Rent';
      case ListingIntent.lease:
        return 'Lease Amount';
      case ListingIntent.sell:
      default:
        return 'Expected Price';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();
    final intent = provider.listingIntent;
    final isSell = intent == ListingIntent.sell;
    final isRentOrLease = intent == ListingIntent.rent || intent == ListingIntent.lease;
    final isCommercial = provider.category == PropertyCategory.commercial;
    final isPg = provider.category == PropertyCategory.pg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.currency_rupee, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                '${_priceLabel(intent)}: ${provider.price.isEmpty ? '—' : provider.price}',
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (!isPg)
          WizardCard(
            icon: Icons.request_quote_outlined,
            title: 'Pricing Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSell) ...[
                  WizardField(
                    label: 'Rate per Sq.Ft/Unit (Optional)',
                    child: WizardTextField(
                      controller: _ratePerAreaController,
                      hint: '₹0',
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          context.read<PostPropertyProvider>().setRatePerArea(v),
                    ),
                  ),
                  const WizardDivider(),
                ],
                if (isRentOrLease) ...[
                  WizardField(
                    label: 'Security Deposit',
                    child: WizardTextField(
                      controller: _securityDepositController,
                      hint: '₹0',
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          context.read<PostPropertyProvider>().setSecurityDeposit(v),
                    ),
                  ),
                  const WizardDivider(),
                ],
                WizardField(
                  label: 'Maintenance Charges (Monthly)',
                  child: WizardTextField(
                    controller: _maintenanceController,
                    hint: '₹0',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setMaintenanceCharges(v),
                  ),
                ),
                if (isSell) ...[
                  const WizardDivider(),
                  WizardField(
                    label: 'Booking / Token Amount',
                    child: WizardTextField(
                      controller: _bookingAmountController,
                      hint: '₹0',
                      keyboardType: TextInputType.number,
                      onChanged: (v) =>
                          context.read<PostPropertyProvider>().setBookingAmount(v),
                    ),
                  ),
                ],
                if (isRentOrLease) ...[
                  const WizardDivider(),
                  WizardField(
                    label: 'Lock-in Period',
                    child: WizardChipGroup(
                      options: _lockInOptions,
                      selected: provider.lockInPeriod,
                      onSelected: (v) =>
                          context.read<PostPropertyProvider>().setLockInPeriod(v),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (isCommercial && isSell) ...[
          const SizedBox(height: 20),
          WizardCard(
            icon: Icons.trending_up_outlined,
            title: 'Investment Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WizardField(
                        label: 'ROI Estimate (%)',
                        child: WizardTextField(
                          controller: _roiEstimateController,
                          hint: 'e.g., 6%',
                          onChanged: (v) =>
                              context.read<PostPropertyProvider>().setText('roiEstimate', v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WizardField(
                        label: 'Current Rental Income',
                        child: WizardTextField(
                          controller: _currentRentalIncomeController,
                          hint: '₹/month',
                          onChanged: (v) => context
                              .read<PostPropertyProvider>()
                              .setText('currentRentalIncome', v),
                        ),
                      ),
                    ),
                  ],
                ),
                const WizardDivider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    WizardCheckboxTile(
                      label: 'Currently Tenant Occupied',
                      value: provider.boolVal('tenantOccupied'),
                      onChanged: (v) =>
                          context.read<PostPropertyProvider>().setBoolVal('tenantOccupied', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Lease Running',
                      value: provider.boolVal('leaseRunning'),
                      onChanged: (v) =>
                          context.read<PostPropertyProvider>().setBoolVal('leaseRunning', v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (isCommercial && isRentOrLease) ...[
          const SizedBox(height: 20),
          WizardCard(
            icon: Icons.article_outlined,
            title: 'Commercial Lease Terms',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WizardField(
                        label: 'Lease Duration / Min Duration',
                        child: WizardTextField(
                          controller: _leaseDurationController,
                          hint: 'e.g., 3 Years',
                          onChanged: (v) {
                            final p = context.read<PostPropertyProvider>();
                            p.setText('leaseDuration', v);
                            p.setText('minRentalDuration', v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WizardField(
                        label: 'Rent Escalation (%)',
                        child: WizardTextField(
                          controller: _leaseEscalationController,
                          hint: 'e.g., 5% after 1 year',
                          onChanged: (v) {
                            final p = context.read<PostPropertyProvider>();
                            p.setText('leaseEscalationPercent', v);
                            p.setText('rentEscalation', v);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const WizardDivider(),
                Row(
                  children: [
                    Expanded(
                      child: WizardField(
                        label: 'CAM Charges (Monthly)',
                        child: WizardTextField(
                          controller: _camChargesController,
                          hint: '₹ or ₹/sq.ft',
                          onChanged: (v) =>
                              context.read<PostPropertyProvider>().setText('camCharges', v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WizardField(
                        label: 'Fit-out Period',
                        child: WizardTextField(
                          controller: _fitOutPeriodController,
                          hint: 'e.g., 1 Month',
                          onChanged: (v) =>
                              context.read<PostPropertyProvider>().setText('fitOutPeriod', v),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (isPg && intent == ListingIntent.rent) ...[
          WizardCard(
            icon: Icons.bed_outlined,
            title: 'PG Rent Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WizardField(
                        label: 'Monthly Rent Per Bed',
                        child: WizardTextField(
                          controller: _monthlyRentPerBedController,
                          hint: '₹0',
                          keyboardType: TextInputType.number,
                          onChanged: (v) => context
                              .read<PostPropertyProvider>()
                              .setText('monthlyRentPerBed', v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WizardField(
                        label: 'Monthly Rent Per Room',
                        child: WizardTextField(
                          controller: _monthlyRentPerRoomController,
                          hint: '₹0',
                          keyboardType: TextInputType.number,
                          onChanged: (v) => context
                              .read<PostPropertyProvider>()
                              .setText('monthlyRentPerRoom', v),
                        ),
                      ),
                    ),
                  ],
                ),
                const WizardDivider(),
                Row(
                  children: [
                    Expanded(
                      child: WizardField(
                        label: 'Food Charges (if separate)',
                        child: WizardTextField(
                          controller: _foodChargesController,
                          hint: '₹0',
                          keyboardType: TextInputType.number,
                          onChanged: (v) =>
                              context.read<PostPropertyProvider>().setText('foodCharges', v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WizardField(
                        label: 'Laundry Charges (if separate)',
                        child: WizardTextField(
                          controller: _laundryChargesController,
                          hint: '₹0',
                          keyboardType: TextInputType.number,
                          onChanged: (v) => context
                              .read<PostPropertyProvider>()
                              .setText('laundryCharges', v),
                        ),
                      ),
                    ),
                  ],
                ),
                const WizardDivider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    WizardCheckboxTile(
                      label: 'Housekeeping Included',
                      value: provider.boolVal('housekeepingIncluded'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('housekeepingIncluded', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Company Tie-Up Allowed',
                      value: provider.boolVal('companyTieUp'),
                      onChanged: (v) =>
                          context.read<PostPropertyProvider>().setBoolVal('companyTieUp', v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (isPg && intent == ListingIntent.sell) ...[
          WizardCard(
            icon: Icons.sell_outlined,
            title: 'PG Sale Details',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: WizardField(
                        label: 'Total Sale Price',
                        child: WizardTextField(
                          controller: _totalSalePriceController,
                          hint: '₹0',
                          keyboardType: TextInputType.number,
                          onChanged: (v) => context
                              .read<PostPropertyProvider>()
                              .setText('totalSalePrice', v),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WizardField(
                        label: 'Current Occupancy Rate (%)',
                        child: WizardTextField(
                          controller: _occupancyRateController,
                          hint: 'e.g., 80',
                          keyboardType: TextInputType.number,
                          onChanged: (v) =>
                              context.read<PostPropertyProvider>().setText('occupancyRate', v),
                        ),
                      ),
                    ),
                  ],
                ),
                const WizardDivider(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    WizardCheckboxTile(
                      label: 'Business Included',
                      value: provider.boolVal('businessIncluded'),
                      onChanged: (v) =>
                          context.read<PostPropertyProvider>().setBoolVal('businessIncluded', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Furniture Included',
                      value: provider.boolVal('furnitureIncluded'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('furnitureIncluded', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Brand/Franchise Included',
                      value: provider.boolVal('brandFranchiseIncluded'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('brandFranchiseIncluded', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Existing Staff Included',
                      value: provider.boolVal('existingStaffIncluded'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('existingStaffIncluded', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Management Transfer',
                      value: provider.boolVal('managementTransfer'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('managementTransfer', v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (isPg && intent == ListingIntent.lease) ...[
          WizardCard(
            icon: Icons.handshake_outlined,
            title: 'PG Lease Details',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                WizardCheckboxTile(
                  label: 'Renewable Lease',
                  value: provider.boolVal('renewableLease'),
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setBoolVal('renewableLease', v),
                ),
                WizardCheckboxTile(
                  label: 'Franchise Operation Allowed',
                  value: provider.boolVal('franchiseOperationAllowed'),
                  onChanged: (v) => context
                      .read<PostPropertyProvider>()
                      .setBoolVal('franchiseOperationAllowed', v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        WizardCard(
          icon: Icons.tune_outlined,
          title: 'Other Details',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WizardCheckboxTile(
                label: 'Price is Negotiable',
                value: provider.priceNegotiable,
                onChanged: (v) =>
                    context.read<PostPropertyProvider>().setPriceNegotiable(v),
              ),
              if (isSell) ...[
                WizardCheckboxTile(
                  label: 'All Inclusive Price',
                  value: provider.allInclusivePriceToggle,
                  onChanged: (v) => context
                      .read<PostPropertyProvider>()
                      .setAllInclusivePriceToggle(v),
                ),
                WizardCheckboxTile(
                  label: 'Tax & Govt Charges Included',
                  value: provider.taxGovtChargesIncluded,
                  onChanged: (v) => context
                      .read<PostPropertyProvider>()
                      .setTaxGovtChargesIncluded(v),
                ),
                WizardCheckboxTile(
                  label: 'Loan Available',
                  value: provider.loanAvailability,
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setLoanAvailability(v),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.handshake_outlined,
          title: 'Brokerage',
          child: WizardField(
            label: 'Brokerage (if applicable)',
            child: WizardTextField(
              controller: _brokerageController,
              hint: 'e.g., 1 Month Rent or 1% of Price',
              onChanged: (v) => context.read<PostPropertyProvider>().setBrokerage(v),
            ),
          ),
        ),
      ],
    );
  }
}
