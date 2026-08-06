import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/wizard_kit.dart';
import '../../../providers/post_property_provider.dart';

/// Step 4: property condition, construction age, availability status,
/// furnishing type and available items — with Commercial-specific option
/// sets and a PG-specific Food & Housekeeping block. Mirrors the React
/// FurnishingStep (labelled "Condition" in the stepper).
class ConditionStep extends StatelessWidget {
  const ConditionStep({super.key});

  static const _conditionsDefault = [
    'New', 'Resale', 'Under Construction', 'Ready to Move', 'Off-Plan', 'Renovated', 'Other',
  ];

  static const _conditionsCommercial = [
    'New', 'Resale', 'Under Construction', 'Ready to Move',
    'Off-Plan', 'Bare Shell', 'Warm Shell', 'Fully Furnished', 'Other',
  ];

  static const _constructionAges = [
    ('newly_constructed', 'Newly Constructed'),
    ('0-2_years', '0-2 Years'),
    ('2-5_years', '2-5 Years'),
    ('5-10_years', '5-10 Years'),
    ('10+_years', '> 10 Years'),
  ];

  static const _availabilityStatuses = ['Available', 'Sold Out', 'Rented'];

  static const _furnishingTypesDefault = ['Furnished', 'Semi-Furnished', 'Unfurnished'];

  static const _furnishingTypesCommercial = [
    'Furnished', 'Semi-Furnished', 'Unfurnished', 'Bare Shell', 'Warm Shell',
  ];

  static const _availableItemsResidential = [
    'Bed', 'Sofa', 'Wardrobe', 'Modular Kitchen', 'AC', 'Fan', 'Geyser',
    'Refrigerator', 'Washing Machine', 'TV', 'Desks', 'Chairs',
  ];

  static const _availableItemsCommercial = [
    'Air Conditioner', 'Central AC', 'Modular Workstations', 'Workstations',
    'Tables', 'Chairs', 'Reception Desk', 'Meeting Room Setup', 'Pantry',
    'Server Room', 'Storage Area', 'Cabinets', 'False Ceiling',
  ];

  static const _mealOptions = ['Breakfast', 'Lunch', 'Dinner', 'Tea / Snacks'];

  static const _cleaningFrequencies = ['Daily', 'Alternate Days', 'Weekly', 'On Demand'];

  static const _linenFrequencies = ['Daily', 'Alternate Days', 'Weekly', 'Fortnightly'];

  static String? _constructionAgeLabel(String? code) {
    for (final entry in _constructionAges) {
      if (entry.$1 == code) return entry.$2;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();
    final isCommercial = provider.category == PropertyCategory.commercial;
    final isPg = provider.category == PropertyCategory.pg;

    final conditions = isCommercial ? _conditionsCommercial : _conditionsDefault;
    final furnishingTypes =
        isCommercial ? _furnishingTypesCommercial : _furnishingTypesDefault;
    final availableItemOptions =
        isCommercial ? _availableItemsCommercial : _availableItemsResidential;
    final itemsBagKey = isCommercial ? 'furnishedItems' : null;

    final showAvailableItems = provider.furnishingType == 'Furnished' ||
        provider.furnishingType == 'Semi-Furnished';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Building condition, commercial only — both fields live inside the
        // nested buildingInventory object (ConditionStep.tsx spreads into it)
        // and both are required by the rules for this category.
        if (provider.category == PropertyCategory.commercial) ...[
          const _BuildingConditionCard(),
          const SizedBox(height: 20),
        ],

        WizardCard(
          icon: Icons.fact_check_outlined,
          title: 'Condition & Availability',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Property Condition',
                child: WizardChipGroup(
                  options: conditions,
                  selected: provider.propertyCondition,
                  onSelected: (v) => context
                      .read<PostPropertyProvider>()
                      .setPropertyCondition(v),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Construction Age',
                child: WizardChipGroup(
                  options: _constructionAges.map((e) => e.$2).toList(),
                  selected: _constructionAgeLabel(provider.constructionAge),
                  onSelected: (label) {
                    final code = _constructionAges
                        .firstWhere((e) => e.$2 == label)
                        .$1;
                    context.read<PostPropertyProvider>().setConstructionAge(code);
                  },
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Availability Status',
                child: WizardChipGroup(
                  options: _availabilityStatuses,
                  selected: provider.availabilityStatus,
                  onSelected: (v) => context
                      .read<PostPropertyProvider>()
                      .setAvailabilityStatus(v),
                ),
              ),
              const WizardDivider(),
              // React renders <AvailableFrom> in every ConditionStep branch
              // (ConditionStep.tsx:365-445). This step is only visible for
              // commercial, PG and others — land and residential answer the
              // same question on the Dimensions step — so without it those
              // three categories had a required field with no input anywhere
              // and could never leave this step.
              const _AvailableFromField(),
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.chair_outlined,
          title: 'Furnishing',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Furnishing Type *',
                child: WizardChipGroup(
                  options: furnishingTypes,
                  selected: provider.furnishingType,
                  onSelected: (v) =>
                      context.read<PostPropertyProvider>().setFurnishingType(v),
                ),
              ),
              if (showAvailableItems) ...[
                const WizardDivider(),
                WizardField(
                  label: 'Available Items',
                  child: WizardMultiChipGroup(
                    options: availableItemOptions,
                    selected: itemsBagKey == null
                        ? provider.availableItems
                        : provider.listVal(itemsBagKey),
                    onChanged: (items) {
                      final p = context.read<PostPropertyProvider>();
                      if (itemsBagKey == null) {
                        p.setAvailableItems(items);
                      } else {
                        p.setListVal(itemsBagKey, items);
                      }
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isPg) ...[
          const SizedBox(height: 20),
          WizardCard(
            icon: Icons.restaurant_outlined,
            title: 'Food & Services',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    WizardCheckboxTile(
                      label: 'Veg Food Available',
                      value: provider.boolVal('vegFoodPg'),
                      onChanged: (v) =>
                          context.read<PostPropertyProvider>().setBoolVal('vegFoodPg', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Non-Veg Food Available',
                      value: provider.boolVal('nonVegFoodPg'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('nonVegFoodPg', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Self-Cooking Allowed',
                      value: provider.boolVal('selfCookingAllowed'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('selfCookingAllowed', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Shared Kitchen',
                      value: provider.boolVal('sharedKitchen'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('sharedKitchen', v),
                    ),
                  ],
                ),
                const WizardDivider(),
                WizardField(
                  label: 'Meals Included',
                  child: WizardMultiChipGroup(
                    options: _mealOptions,
                    selected: provider.listVal('mealsIncluded'),
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setListVal('mealsIncluded', v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          WizardCard(
            icon: Icons.cleaning_services_outlined,
            title: 'Housekeeping',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    WizardCheckboxTile(
                      label: 'Laundry Service',
                      value: provider.boolVal('laundryService'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('laundryService', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Cleaning Service',
                      value: provider.boolVal('cleaningService'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('cleaningService', v),
                    ),
                    WizardCheckboxTile(
                      label: 'Daily Cleaning',
                      value: provider.boolVal('dailyCleaning'),
                      onChanged: (v) => context
                          .read<PostPropertyProvider>()
                          .setBoolVal('dailyCleaning', v),
                    ),
                  ],
                ),
                const WizardDivider(),
                WizardField(
                  label: 'Room Cleaning Frequency',
                  child: WizardChipGroup(
                    options: _cleaningFrequencies,
                    selected: provider.text('roomCleaningFrequency').isEmpty
                        ? null
                        : provider.text('roomCleaningFrequency'),
                    onSelected: (v) => context
                        .read<PostPropertyProvider>()
                        .setText('roomCleaningFrequency', v),
                  ),
                ),
                const WizardDivider(),
                WizardField(
                  label: 'Linen Change Frequency',
                  child: WizardChipGroup(
                    options: _linenFrequencies,
                    selected: provider.text('linenChangeFrequency').isEmpty
                        ? null
                        : provider.text('linenChangeFrequency'),
                    onSelected: (v) => context
                        .read<PostPropertyProvider>()
                        .setText('linenChangeFrequency', v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Commercial building condition. Separate stateful widget so [ConditionStep]
/// can stay stateless while Building Age still gets a proper controller.
class _BuildingConditionCard extends StatefulWidget {
  const _BuildingConditionCard();

  @override
  State<_BuildingConditionCard> createState() => _BuildingConditionCardState();
}

class _BuildingConditionCardState extends State<_BuildingConditionCard> {
  /// Verbatim from the ownershipTypeBuilding select in ConditionStep.tsx —
  /// three options, NOT the four the property-condition select offers.
  static const List<String> _kBuildingOwnershipTypes = [
    'Freehold',
    'Leasehold',
    'Co-ownership',
  ];

  late final TextEditingController _buildingAgeController;

  @override
  void initState() {
    super.initState();
    _buildingAgeController = TextEditingController(
      text: context
          .read<PostPropertyProvider>()
          .buildingInventoryText('buildingAge'),
    );
  }

  @override
  void dispose() {
    _buildingAgeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();

    return WizardCard(
      icon: Icons.apartment_outlined,
      title: 'Building Condition',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WizardField(
            label: 'Building Age *',
            child: WizardTextField(
              controller: _buildingAgeController,
              hint: 'e.g., 5 years',
              onChanged: (v) => context
                  .read<PostPropertyProvider>()
                  .setBuildingInventoryValue('buildingAge', v),
            ),
          ),
          const WizardDivider(),
          WizardField(
            label: 'Building Ownership Type *',
            child: WizardChipGroup(
              options: _kBuildingOwnershipTypes,
              selected:
                  provider.buildingInventoryText('ownershipTypeBuilding').isEmpty
                      ? null
                      : provider.buildingInventoryText('ownershipTypeBuilding'),
              onSelected: (v) => context
                  .read<PostPropertyProvider>()
                  .setBuildingInventoryValue('ownershipTypeBuilding', v),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Available From *" — the checkbox/date pair React uses identically on the
/// Dimensions and Condition steps: ticking Immediately stores the literal
/// `'Immediately'`, otherwise a date is picked, and the date box is hidden
/// while Immediately is set.
class _AvailableFromField extends StatelessWidget {
  const _AvailableFromField();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostPropertyProvider>();
    final d = p.availableFrom;
    final text = d == null
        ? 'Select a date'
        : '${d.year.toString().padLeft(4, '0')}-'
            '${d.month.toString().padLeft(2, '0')}-'
            '${d.day.toString().padLeft(2, '0')}';

    return WizardField(
      label: 'Available From *',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WizardCheckboxTile(
            label: 'Immediately',
            value: p.availableImmediately,
            onChanged: (v) => context
                .read<PostPropertyProvider>()
                .setAvailableImmediately(v),
          ),
          if (!p.availableImmediately) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: d ?? now,
                  firstDate: DateTime(now.year - 1),
                  lastDate: DateTime(now.year + 20),
                );
                if (picked != null && context.mounted) {
                  context.read<PostPropertyProvider>().setAvailableFrom(picked);
                }
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      text,
                      style: AppTextStyles.body.copyWith(
                        color: d == null
                            ? AppColors.textHint
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
