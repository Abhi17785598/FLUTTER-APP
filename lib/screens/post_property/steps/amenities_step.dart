import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/widgets/wizard_kit.dart';
import '../../../providers/post_property_provider.dart';

/// Step 5: utilities/parking/key-facilities for Residential/Land/Other/PG-base,
/// or the full Commercial amenities section (usage, business info, features,
/// washrooms, parking, utilities & licenses) for Commercial — plus a PG-only
/// amenities & safety block appended regardless of the base branch. Mirrors
/// the React AmenitiesStep.
class AmenitiesStep extends StatefulWidget {
  const AmenitiesStep({super.key});

  @override
  State<AmenitiesStep> createState() => _AmenitiesStepState();
}

class _AmenitiesStepState extends State<AmenitiesStep> {
  static const _electricityOptions = ['Full', 'Partial', 'None'];
  static const _waterOptions = ['24 Hours', '12 Hours', 'Rare'];

  static const _suitableForOptions = [
    'Office', 'Retail', 'Restaurant', 'Clinic', 'Salon', 'Gym', 'Warehouse',
    'Manufacturing', 'Startup', 'IT Company', 'Franchise',
  ];

  static const _officeFeatures = [
    'Reception Area', 'Waiting Area', 'Conference Room', 'Conference Hall',
    'Meeting Room', 'Open Workspace', 'Cafeteria', 'Biometric Entry',
  ];

  static const _retailFeatures = [
    'Glass Frontage', 'Display Area', 'Signage Space', 'Dock Height',
    'Truck Parking', 'Loading/Unloading Area', 'Crane Facility',
    'Storage Racks', 'Ventilation',
  ];

  static const _buildingAmenities = [
    'Service Lift', 'Escalator', 'Security Guard', 'CCTV', 'Fire Fighting System',
    'Fire Exit', 'Fiber Connectivity', 'Intercom', 'Solar Backup', 'ATM',
  ];

  static const _utilityLicenseToggles = [
    ('electricityAvailability', 'Electricity Available'),
    ('electricityChargesExtra', 'Electricity Charges Extra'),
    ('waterChargesExtra', 'Water Charges Extra'),
    ('fireLicense', 'Fire License'),
    ('tradeLicense', 'Trade License'),
    ('foodLicense', 'Food License (FSSAI)'),
    ('pollutionClearance', 'Pollution Clearance'),
    ('industrialApproval', 'Industrial Approval'),
  ];

  static const _parkingToggles = [
    ('visitorParking', 'Visitor Parking'),
    ('reservedParking', 'Reserved Parking'),
    ('bikeParking', 'Bike Parking'),
    ('carParking', 'Car Parking'),
    ('truckParking', 'Truck Parking'),
    ('loadingVehicleAccess', 'Loading Vehicle Access'),
  ];

  static const _pgAmenityOptions = [
    'Common Area', 'Dining Area', 'Living Area', 'Library', 'Gym/Fitness Center',
    'Swimming Pool', 'Indoor Games', 'Outdoor Sports Area', 'Power Backup (100%)',
    'Power Backup (Partial)', 'Water Purifier (RO)', 'Lift', 'Parking (2-Wheeler)',
    'Parking (4-Wheeler)',
  ];

  static const _pgSafetyToggles = [
    ('cctvCoverage', 'CCTV Coverage'),
    ('biometricAccess', 'Biometric Access'),
    ('policeVerificationRequired', 'Police Verification Required'),
    ('visitorEntryRegister', 'Visitor Entry Register'),
  ];

  late final TextEditingController _coveredParkingController;
  late final TextEditingController _openParkingController;
  late final TextEditingController _liftsController;
  late final TextEditingController _businessTypeController;
  late final TextEditingController _washroomsController;
  late final TextEditingController _westernSeatsController;
  late final TextEditingController _indianSeatsController;
  late final TextEditingController _totalParkingController;

  @override
  void initState() {
    super.initState();
    final p = context.read<PostPropertyProvider>();
    _coveredParkingController = TextEditingController(text: p.coveredParking);
    _openParkingController = TextEditingController(text: p.openParking);
    _liftsController = TextEditingController(text: p.numberOfLifts);
    _businessTypeController = TextEditingController(text: p.text('businessType'));
    _washroomsController = TextEditingController(text: p.text('washrooms'));
    _westernSeatsController = TextEditingController(text: p.text('westernSeats'));
    _indianSeatsController = TextEditingController(text: p.text('indianSeats'));
    _totalParkingController = TextEditingController(text: p.text('totalParking'));
  }

  @override
  void dispose() {
    _coveredParkingController.dispose();
    _openParkingController.dispose();
    _liftsController.dispose();
    _businessTypeController.dispose();
    _washroomsController.dispose();
    _westernSeatsController.dispose();
    _indianSeatsController.dispose();
    _totalParkingController.dispose();
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
        if (isCommercial) _buildCommercialSections(context, provider) else _buildDefaultSection(context, provider),
        if (isPg) ...[
          const SizedBox(height: 20),
          _buildPgAmenitiesSection(context, provider),
        ],
      ],
    );
  }

  Widget _buildDefaultSection(BuildContext context, PostPropertyProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardCard(
          icon: Icons.bolt_outlined,
          title: 'Utilities',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Electricity Backup',
                child: WizardChipGroup(
                  options: _electricityOptions,
                  selected: provider.electricityBackup,
                  onSelected: (v) =>
                      context.read<PostPropertyProvider>().setElectricityBackup(v),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Water Availability',
                child: WizardChipGroup(
                  options: _waterOptions,
                  selected: provider.waterAvailability,
                  onSelected: (v) =>
                      context.read<PostPropertyProvider>().setWaterAvailability(v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.local_parking_outlined,
          title: 'Parking & Lifts',
          child: Row(
            children: [
              Expanded(
                child: WizardField(
                  label: 'Covered Parking',
                  child: WizardTextField(
                    controller: _coveredParkingController,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setCoveredParking(v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Open Parking',
                  child: WizardTextField(
                    controller: _openParkingController,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setOpenParking(v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Lifts Available',
                  child: WizardTextField(
                    controller: _liftsController,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setNumberOfLifts(v),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.checklist_outlined,
          title: 'Key Facilities',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              WizardCheckboxTile(
                label: 'Gas Pipeline',
                value: provider.gasPipeline,
                onChanged: (v) => context.read<PostPropertyProvider>().setGasPipeline(v),
              ),
              WizardCheckboxTile(
                label: 'Internet Available',
                value: provider.internetAvailability,
                onChanged: (v) =>
                    context.read<PostPropertyProvider>().setInternetAvailability(v),
              ),
              WizardCheckboxTile(
                label: 'Solar Power',
                value: provider.solarPower,
                onChanged: (v) => context.read<PostPropertyProvider>().setSolarPower(v),
              ),
              WizardCheckboxTile(
                label: 'Security / Guard',
                value: provider.guardRoom,
                onChanged: (v) => context.read<PostPropertyProvider>().setGuardRoom(v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommercialSections(BuildContext context, PostPropertyProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardCard(
          icon: Icons.business_center_outlined,
          title: 'Suitable For (Usage Details)',
          child: WizardMultiChipGroup(
            options: _suitableForOptions,
            selected: provider.listVal('suitableFor'),
            onChanged: (v) => context.read<PostPropertyProvider>().setListVal('suitableFor', v),
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.storefront_outlined,
          title: 'Current Business Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardCheckboxTile(
                label: 'Current Business Running',
                value: provider.boolVal('currentBusinessRunning'),
                onChanged: (v) => context
                    .read<PostPropertyProvider>()
                    .setBoolVal('currentBusinessRunning', v),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Business Type',
                child: WizardTextField(
                  controller: _businessTypeController,
                  hint: 'e.g., IT Services, Retail Outlet',
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setText('businessType', v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.domain_outlined,
          title: 'Commercial & Building Features',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Office Features',
                child: WizardMultiChipGroup(
                  options: _officeFeatures,
                  selected: provider.listVal('officeFeatures'),
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setListVal('officeFeatures', v),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Retail & Warehouse Features',
                child: WizardMultiChipGroup(
                  options: _retailFeatures,
                  selected: provider.listVal('retailFeatures'),
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setListVal('retailFeatures', v),
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Building Amenities',
                child: WizardMultiChipGroup(
                  options: _buildingAmenities,
                  selected: provider.listVal('amenities'),
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setListVal('amenities', v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.wc_outlined,
          title: 'Washroom Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: WizardField(
                      label: 'Total Washrooms',
                      child: WizardTextField(
                        controller: _washroomsController,
                        hint: '0',
                        keyboardType: TextInputType.number,
                        onChanged: (v) =>
                            context.read<PostPropertyProvider>().setText('washrooms', v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WizardField(
                      label: 'Western Seats',
                      child: WizardTextField(
                        controller: _westernSeatsController,
                        hint: '0',
                        keyboardType: TextInputType.number,
                        onChanged: (v) =>
                            context.read<PostPropertyProvider>().setText('westernSeats', v),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: WizardField(
                      label: 'Indian Seats',
                      child: WizardTextField(
                        controller: _indianSeatsController,
                        hint: '0',
                        keyboardType: TextInputType.number,
                        onChanged: (v) =>
                            context.read<PostPropertyProvider>().setText('indianSeats', v),
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
                    label: 'Male Washroom',
                    value: provider.boolVal('maleWashroom'),
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setBoolVal('maleWashroom', v),
                  ),
                  WizardCheckboxTile(
                    label: 'Female Washroom',
                    value: provider.boolVal('femaleWashroom'),
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setBoolVal('femaleWashroom', v),
                  ),
                  WizardCheckboxTile(
                    label: 'Common Washroom',
                    value: provider.boolVal('commonWashroom'),
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setBoolVal('commonWashroom', v),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.local_parking_outlined,
          title: 'Parking Details',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Total Parking Spaces',
                child: WizardTextField(
                  controller: _totalParkingController,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setText('totalParking', v),
                ),
              ),
              const WizardDivider(),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _parkingToggles.map((t) {
                  return WizardCheckboxTile(
                    label: t.$2,
                    value: provider.boolVal(t.$1),
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setBoolVal(t.$1, v),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        WizardCard(
          icon: Icons.verified_outlined,
          title: 'Utilities, Licenses & Approvals',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _utilityLicenseToggles.map((t) {
              return WizardCheckboxTile(
                label: t.$2,
                value: provider.boolVal(t.$1),
                onChanged: (v) => context.read<PostPropertyProvider>().setBoolVal(t.$1, v),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPgAmenitiesSection(BuildContext context, PostPropertyProvider provider) {
    return WizardCard(
      icon: Icons.home_work_outlined,
      title: 'PG & Co-Living Amenities',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WizardMultiChipGroup(
            options: _pgAmenityOptions,
            selected: provider.listVal('pgAmenities'),
            onChanged: (v) => context.read<PostPropertyProvider>().setListVal('pgAmenities', v),
          ),
          const WizardDivider(),
          WizardField(
            label: 'Safety & Security',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pgSafetyToggles.map((t) {
                return WizardCheckboxTile(
                  label: t.$2,
                  value: provider.boolVal(t.$1),
                  onChanged: (v) => context.read<PostPropertyProvider>().setBoolVal(t.$1, v),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
