import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/wizard_kit.dart';
import '../../../providers/post_property_provider.dart';
import '../listing_constants.dart';

/// Step 6: RERA status, available legal documents, facing and bank approvals
/// (shared) — plus Commercial-specific approvals/licenses and PG-specific
/// house rules & legal approvals. Mirrors the React LegalDetailsStep.
class LegalDetailsStep extends StatefulWidget {
  const LegalDetailsStep({super.key});

  @override
  State<LegalDetailsStep> createState() => _LegalDetailsStepState();
}

class _LegalDetailsStepState extends State<LegalDetailsStep> {
  /// Land record flags, keyed by their canonical React metadata names
  /// (the land fillMetadata block, PropertyWizard.tsx:1576).
  static const List<(String, String)> _kLandLegalFlags = [
    ('mutationAvailable', 'Mutation Available'),
    ('registryAvailable', 'Registry Available'),
    ('pattaAvailable', 'Patta Available'),
    ('khataAvailable', 'Khata Available'),
    ('jamabandiAvailable', 'Jamabandi Available'),
    ('courtCasePending', 'Court Case Pending'),
    ('bankLoanApproved', 'Bank Loan Approved'),
  ];

  late final TextEditingController _ownerNameController;

  static const _facingOptions = [
    'East', 'West', 'North', 'South', 'North-East', 'North-West', 'South-East', 'South-West',
  ];

  static const _commercialApprovals = [
    ('fireNoc', 'Fire NOC / License'),
    ('tradeLicenseAvailable', 'Trade License'),
    ('foodLicense', 'Food License'),
    ('pollutionClearance', 'Pollution Clearance'),
    ('industrialApproval', 'Industrial Approval'),
    ('propertyTaxPaid', 'Property Tax Paid'),
    ('approvedByAuthority', 'Approved by Authority'),
  ];

  static const _pgHouseRules = [
    ('studentsAllowed', 'Students Allowed'),
    ('workingProfessionalsAllowed', 'Working Professionals Allowed'),
    ('maleAllowed', 'Male Allowed'),
    ('femaleAllowed', 'Female Allowed'),
    ('couplesAllowed', 'Couples Allowed'),
    ('foreignNationalsAllowed', 'Foreign Nationals Allowed'),
    ('petsAllowedPg', 'Pets Allowed'),
    ('visitorsAllowedPg', 'Visitors Allowed'),
  ];

  late final TextEditingController _reraNumberController;
  late final TextEditingController _approvedByBanksController;
  late final TextEditingController _quietHoursController;

  @override
  void initState() {
    super.initState();
    _ownerNameController = TextEditingController(
        text: context.read<PostPropertyProvider>().text('ownerName'));
    final provider = context.read<PostPropertyProvider>();
    _reraNumberController = TextEditingController(text: provider.reraNumber);
    _approvedByBanksController =
        TextEditingController(text: provider.approvedByBanks.join(', '));
    _quietHoursController = TextEditingController(text: provider.text('quietHours'));
  }

  @override
  void dispose() {
    _ownerNameController.dispose();
    _reraNumberController.dispose();
    _approvedByBanksController.dispose();
    _quietHoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();
    final isCommercial = provider.category == PropertyCategory.commercial;
    final isPg = provider.category == PropertyCategory.pg;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Land ownership + legal status. React renders these only for land
        // (LegalDetailsStep.tsx) and its rules require ownershipType and
        // ownerName for that category; Flutter had no land block at all, so
        // both rules fired with nothing on screen to satisfy them.
        if (provider.category == PropertyCategory.land) ...[
          WizardCard(
            icon: Icons.gavel_outlined,
            title: 'Land Ownership',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                WizardField(
                  label: 'Ownership Type *',
                  child: WizardChipGroup(
                    options: kLandOwnershipTypes,
                    selected: provider.text('ownershipType').isEmpty
                        ? null
                        : provider.text('ownershipType'),
                    onSelected: (v) => context
                        .read<PostPropertyProvider>()
                        .setText('ownershipType', v),
                  ),
                ),
                const WizardDivider(),
                WizardField(
                  label: 'Owner Name *',
                  child: WizardTextField(
                    controller: _ownerNameController,
                    hint: 'As recorded on the title',
                    onChanged: (v) => context
                        .read<PostPropertyProvider>()
                        .setText('ownerName', v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          WizardCard(
            icon: Icons.fact_check_outlined,
            title: 'Land Records & Status',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final flag in _kLandLegalFlags)
                  WizardCheckboxTile(
                    label: flag.$2,
                    value: provider.boolVal(flag.$1),
                    onChanged: (v) => context
                        .read<PostPropertyProvider>()
                        .setBoolVal(flag.$1, v),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        WizardCard(
          icon: Icons.verified_outlined,
          title: 'RERA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardCheckboxTile(
                label: 'RERA Registered',
                value: provider.reraRegistered,
                onChanged: (v) =>
                    context.read<PostPropertyProvider>().setReraRegistered(v),
              ),
              if (provider.reraRegistered) ...[
                const WizardDivider(),
                WizardField(
                  label: 'RERA Number',
                  child: WizardTextField(
                    controller: _reraNumberController,
                    hint: 'e.g., P12345678',
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setReraNumber(v),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.description_outlined,
          title: 'Available Documents & Status',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WizardCheckboxTile(
                label: 'Sale Deed',
                value: provider.saleDeed,
                onChanged: (v) => context.read<PostPropertyProvider>().setSaleDeed(v),
              ),
              WizardCheckboxTile(
                label: 'Registry Copy',
                value: provider.registryCopy,
                onChanged: (v) => context.read<PostPropertyProvider>().setRegistryCopy(v),
              ),
              WizardCheckboxTile(
                label: 'NOC Available',
                value: provider.nocAvailable,
                onChanged: (v) => context.read<PostPropertyProvider>().setNocAvailable(v),
              ),
              WizardCheckboxTile(
                label: 'Encumbrance Free',
                value: provider.encumbranceFree,
                onChanged: (v) =>
                    context.read<PostPropertyProvider>().setEncumbranceFree(v),
              ),
              WizardCheckboxTile(
                label: 'Loan Approved',
                value: provider.loanApproved,
                onChanged: (v) => context.read<PostPropertyProvider>().setLoanApproved(v),
              ),
              WizardCheckboxTile(
                label: 'Property Approved',
                value: provider.propertyApproved,
                onChanged: (v) =>
                    context.read<PostPropertyProvider>().setPropertyApproved(v),
              ),
            ],
          ),
        ),
        if (isCommercial) ...[
          const SizedBox(height: 20),
          WizardCard(
            icon: Icons.gavel_outlined,
            title: 'Commercial Approvals & Licenses',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _commercialApprovals.map((t) {
                return WizardCheckboxTile(
                  label: t.$2,
                  value: provider.boolVal(t.$1),
                  onChanged: (v) => context.read<PostPropertyProvider>().setBoolVal(t.$1, v),
                );
              }).toList(),
            ),
          ),
        ],
        if (isPg) ...[
          const SizedBox(height: 20),
          WizardCard(
            icon: Icons.rule_outlined,
            title: 'PG & Co-Living House Rules',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _pgHouseRules.map((t) {
                    return WizardCheckboxTile(
                      label: t.$2,
                      value: provider.boolVal(t.$1),
                      onChanged: (v) =>
                          context.read<PostPropertyProvider>().setBoolVal(t.$1, v),
                    );
                  }).toList(),
                ),
                const WizardDivider(),
                WizardField(
                  label: 'Quiet Hours / Gate Closing Time',
                  child: WizardTextField(
                    controller: _quietHoursController,
                    hint: 'e.g., 10:00 PM to 6:00 AM',
                    onChanged: (v) {
                      final p = context.read<PostPropertyProvider>();
                      p.setText('quietHours', v);
                      p.setText('pgGateClosingTime', v);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          WizardCard(
            icon: Icons.shield_outlined,
            title: 'PG Legal Approvals',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                WizardCheckboxTile(
                  label: 'Hostel / PG License',
                  value: provider.boolVal('hostelLicense'),
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setBoolVal('hostelLicense', v),
                ),
                WizardCheckboxTile(
                  label: 'Building Approval / OC',
                  value: provider.boolVal('buildingApproval'),
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setBoolVal('buildingApproval', v),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.explore_outlined,
          title: 'Facing & Bank Approvals',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Property Facing',
                child: WizardChipGroup(
                  options: _facingOptions,
                  selected: provider.facing,
                  onSelected: (v) => context.read<PostPropertyProvider>().setFacing(v),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Approved By Banks',
                child: WizardTextField(
                  controller: _approvedByBanksController,
                  hint: 'e.g., SBI, HDFC',
                  onChanged: (v) => context.read<PostPropertyProvider>().setApprovedByBanks(
                        v.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
