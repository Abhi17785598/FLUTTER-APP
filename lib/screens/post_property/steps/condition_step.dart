import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
