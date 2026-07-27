import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/wizard_kit.dart';
import '../../../providers/post_property_provider.dart';

/// Step 2 of the Post Property wizard: category-specific sub-type, title,
/// description, address, price, and availability date. Mirrors the React
/// BasicInfoStep's shared + per-category fields.
class BasicInfoStep extends StatefulWidget {
  const BasicInfoStep({super.key});

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  static const _residentialSubTypes = [
    'Apartment', 'Flat', 'Villa', 'Independent House', 'Builder Floor',
    'Studio Apartment', 'Residential Plot', 'Penthouse', 'Farm House',
    'Duplex House', 'Triplex House', 'Row House', 'Bungalow',
    'Service Apartment', 'Residential Land', 'Gated Community House',
  ];

  static const _commercialSubTypes = [
    'Office Space', 'Shop', 'Showroom', 'Co-working Space', 'Warehouse',
    'Godown', 'Factory', 'Industrial Shed', 'Commercial Land',
    'Business Center', 'Retail Space', 'Food Court Space', 'Hotel',
    'Restaurant Space', 'Commercial Building',
  ];

  static const _pgPropertyTypes = [
    'Boys PG', 'Girls PG', 'Co-ed PG', 'Co-living Space',
    'Student Housing', 'Working Professional PG', 'Hostel', 'Service Apartment',
  ];

  static const _pgBuildingTypes = [
    'Apartment', 'Independent House', 'Villa', 'Hostel Building',
    'Gated Community Society', 'Others',
  ];

  static const _pgPropertyStatuses = ['Available', 'Occupied', 'Immediate Move-In'];

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _landmarkController;
  late final TextEditingController _priceController;
  late final TextEditingController _pgPropertyNameController;
  late final TextEditingController _landTypeController;
  late final TextEditingController _soilTypeController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<PostPropertyProvider>();
    _titleController = TextEditingController(text: provider.title);
    _descriptionController = TextEditingController(text: provider.description);
    _locationController = TextEditingController(text: provider.location);
    _cityController = TextEditingController(text: provider.city);
    _stateController = TextEditingController(text: provider.state);
    _pincodeController = TextEditingController(text: provider.pincode);
    _landmarkController = TextEditingController(text: provider.landmark);
    _priceController = TextEditingController(text: provider.price);
    _pgPropertyNameController = TextEditingController(text: provider.text('pgPropertyName'));
    _landTypeController = TextEditingController(text: provider.text('landType'));
    _soilTypeController = TextEditingController(text: provider.text('soilType'));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _landmarkController.dispose();
    _priceController.dispose();
    _pgPropertyNameController.dispose();
    _landTypeController.dispose();
    _soilTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickAvailableFrom() async {
    final provider = context.read<PostPropertyProvider>();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: provider.availableFrom ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      provider.setAvailableFrom(picked);
    }
  }

  String _priceLabel(ListingIntent? intent) {
    switch (intent) {
      case ListingIntent.rent:
        return 'Monthly Rent (₹)';
      case ListingIntent.lease:
        return 'Lease Amount (₹)';
      case ListingIntent.sell:
      default:
        return 'Expected Price (₹)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();
    final category = provider.category;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (category != null) ...[
          _buildCategorySpecificCard(provider, category),
          const SizedBox(height: 20),
        ],
        WizardCard(
          icon: Icons.badge_outlined,
          title: 'Property Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Property Title',
                child: WizardTextField(
                  controller: _titleController,
                  hint: 'e.g., Luxury 3BHK in Bandra',
                  onChanged: (v) => context.read<PostPropertyProvider>().setTitle(v),
                ),
              ),
              if (category != PropertyCategory.pg) ...[
                const WizardDivider(),
                WizardField(
                  label: _priceLabel(provider.listingIntent),
                  child: WizardTextField(
                    controller: _priceController,
                    hint: 'e.g., 3500000',
                    prefixIcon: Icons.currency_rupee,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => context.read<PostPropertyProvider>().setPrice(v),
                  ),
                ),
              ],
              const WizardDivider(),
              WizardField(
                label: 'Available From',
                child: GestureDetector(
                  onTap: _pickAvailableFrom,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          provider.availableFrom == null
                              ? 'Select a date'
                              : '${provider.availableFrom!.day}/${provider.availableFrom!.month}/${provider.availableFrom!.year}',
                          style: AppTextStyles.body.copyWith(
                            color: provider.availableFrom == null
                                ? AppColors.textHint
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Description',
                child: WizardTextField(
                  controller: _descriptionController,
                  hint: 'Describe your property...',
                  maxLines: 4,
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setDescription(v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.location_on_outlined,
          title: 'Location Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Property Address',
                child: WizardTextField(
                  controller: _locationController,
                  hint: 'e.g., Bandra West, Mumbai',
                  prefixIcon: Icons.location_on_outlined,
                  onChanged: (v) => context.read<PostPropertyProvider>().setLocation(v),
                ),
              ),
              const WizardDivider(),
              Row(
                children: [
                  Expanded(
                    child: WizardField(
                      label: 'City',
                      child: WizardTextField(
                        controller: _cityController,
                        hint: 'e.g., Mumbai',
                        onChanged: (v) => context.read<PostPropertyProvider>().setCity(v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WizardField(
                      label: 'State',
                      child: WizardTextField(
                        controller: _stateController,
                        hint: 'e.g., Maharashtra',
                        onChanged: (v) => context.read<PostPropertyProvider>().setState(v),
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
                      label: 'Pincode',
                      child: WizardTextField(
                        controller: _pincodeController,
                        hint: 'e.g., 400050',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => context.read<PostPropertyProvider>().setPincode(v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WizardField(
                      label: 'Landmark',
                      child: WizardTextField(
                        controller: _landmarkController,
                        hint: 'Nearby landmark',
                        onChanged: (v) => context.read<PostPropertyProvider>().setLandmark(v),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySpecificCard(
      PostPropertyProvider provider, PropertyCategory category) {
    switch (category) {
      case PropertyCategory.residential:
        return WizardCard(
          icon: Icons.home_work_outlined,
          title: 'Property Type',
          child: WizardField(
            label: 'Property Type *',
            child: WizardChipGroup(
              options: _residentialSubTypes,
              selected: provider.residentialSubType,
              onSelected: (v) =>
                  context.read<PostPropertyProvider>().setResidentialSubType(v),
            ),
          ),
        );
      case PropertyCategory.commercial:
        return WizardCard(
          icon: Icons.store_outlined,
          title: 'Commercial Property Type',
          child: WizardField(
            label: 'Commercial Property Type *',
            child: WizardChipGroup(
              options: _commercialSubTypes,
              selected: provider.text('commercialSubType').isEmpty
                  ? null
                  : provider.text('commercialSubType'),
              onSelected: (v) {
                final p = context.read<PostPropertyProvider>();
                p.setText('commercialSubType', v);
                p.setText('commercialType', v);
              },
            ),
          ),
        );
      case PropertyCategory.pg:
        return WizardCard(
          icon: Icons.night_shelter_outlined,
          title: 'PG Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Property Type *',
                child: WizardChipGroup(
                  options: _pgPropertyTypes,
                  selected: provider.text('pgPropertyType').isEmpty
                      ? null
                      : provider.text('pgPropertyType'),
                  onSelected: (v) =>
                      context.read<PostPropertyProvider>().setText('pgPropertyType', v),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Building Type *',
                child: WizardChipGroup(
                  options: _pgBuildingTypes,
                  selected: provider.text('buildingType').isEmpty
                      ? null
                      : provider.text('buildingType'),
                  onSelected: (v) =>
                      context.read<PostPropertyProvider>().setText('buildingType', v),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'PG / Property Name *',
                child: WizardTextField(
                  controller: _pgPropertyNameController,
                  hint: 'e.g., Zolo Stays, Stanza Living...',
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setText('pgPropertyName', v),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Property Status *',
                child: WizardChipGroup(
                  options: _pgPropertyStatuses,
                  selected: provider.text('propertyStatus').isEmpty
                      ? null
                      : provider.text('propertyStatus'),
                  onSelected: (v) =>
                      context.read<PostPropertyProvider>().setText('propertyStatus', v),
                ),
              ),
            ],
          ),
        );
      case PropertyCategory.land:
        return WizardCard(
          icon: Icons.landscape_outlined,
          title: 'Land Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Land Type',
                child: WizardTextField(
                  controller: _landTypeController,
                  hint: 'e.g., Agricultural, Residential Plot, Commercial',
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setText('landType', v),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Soil Type',
                child: WizardTextField(
                  controller: _soilTypeController,
                  hint: 'e.g., Clay, Sandy, Loamy',
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setText('soilType', v),
                ),
              ),
            ],
          ),
        );
      case PropertyCategory.other:
        return const SizedBox.shrink();
    }
  }
}
