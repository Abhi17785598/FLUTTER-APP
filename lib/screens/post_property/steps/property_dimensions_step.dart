import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/wizard_kit.dart';
import '../../../providers/post_property_provider.dart';

/// Step 3: total/carpet area (all categories) plus per-category dimension
/// fields — Residential (BHK/bedrooms/bathrooms/floors), Commercial
/// (plot/floor/unit details), PG (structure, capacity, room & bed details).
/// Land and Other only use the shared area fields, matching the React source
/// (no dedicated dimension fields render for those categories).
class PropertyDimensionsStep extends StatefulWidget {
  const PropertyDimensionsStep({super.key});

  @override
  State<PropertyDimensionsStep> createState() => _PropertyDimensionsStepState();
}

class _PropertyDimensionsStepState extends State<PropertyDimensionsStep> {
  static const _bhkTypes = ['1 RK', '1 BHK', '2 BHK', '3 BHK', '4+ BHK'];
  static const _areaUnits = [
    ('sq_ft', 'Sq Ft'),
    ('sq_yd', 'Sq Yd'),
    ('sq_m', 'Sq M'),
  ];
  static const _propertyOnOptions = [
    'Basement', 'Ground Floor', 'Upper Ground', 'First Floor', 'Second Floor+'
  ];
  static const _buildingClassOptions = ['Grade A', 'Grade B', 'Grade C'];
  static const _facingOptions = [
    'East', 'West', 'North', 'South', 'North-East', 'North-West', 'South-East', 'South-West'
  ];
  static const _roomTypes = [
    'Single Sharing', 'Double Sharing', 'Triple Sharing', 'Four Sharing', 'Dormitory', 'Private Room'
  ];
  static const _bedTypes = ['Single Bed', 'Double Bed', 'Bunk Bed'];
  static const _pgRoomFeatures = [
    ('attachedBathroom', 'Attached Bathroom'),
    ('balconyPg', 'Balcony'),
    ('acPg', 'AC'),
    ('fanPg', 'Fan'),
    ('tvPg', 'TV'),
    ('wifiPg', 'WiFi'),
    ('studyTablePg', 'Study Table'),
    ('chairPg', 'Chair'),
    ('wardrobePg', 'Wardrobe'),
    ('bedIncluded', 'Bed Included'),
    ('mattressIncluded', 'Mattress Included'),
    ('curtainsPg', 'Curtains'),
    ('refrigeratorPg', 'Refrigerator'),
  ];

  late final TextEditingController _areaController;
  late final TextEditingController _carpetAreaController;
  late final TextEditingController _bedroomsController;
  late final TextEditingController _bathroomsController;
  late final TextEditingController _balconiesController;
  late final TextEditingController _floorNoController;
  late final TextEditingController _totalFloorsController;

  // Commercial controllers
  late final TextEditingController _superBuiltUpAreaController;
  late final TextEditingController _plotAreaController;
  late final TextEditingController _frontWidthController;
  late final TextEditingController _depthController;
  late final TextEditingController _floorNumberController;
  late final TextEditingController _totalFloorsCommercialController;
  late final TextEditingController _unitNumberController;
  late final TextEditingController _ceilingHeightController;
  late final TextEditingController _loadingCapacityController;

  // PG controllers
  late final TextEditingController _constructionAgeController;
  late final TextEditingController _pgTotalRoomsController;
  late final TextEditingController _pgTotalBedsController;
  late final TextEditingController _pgOccupiedBedsController;
  late final TextEditingController _pgAvailableBedsController;

  @override
  void initState() {
    super.initState();
    final p = context.read<PostPropertyProvider>();
    _areaController = TextEditingController(text: p.area);
    _carpetAreaController = TextEditingController(text: p.carpetArea);
    _bedroomsController = TextEditingController(text: p.bedrooms);
    _bathroomsController = TextEditingController(text: p.bathrooms);
    _balconiesController = TextEditingController(text: p.balconies);
    _floorNoController = TextEditingController(text: p.floorNo);
    _totalFloorsController = TextEditingController(text: p.totalFloors);

    _superBuiltUpAreaController = TextEditingController(text: p.text('superBuiltUpArea'));
    _plotAreaController = TextEditingController(text: p.text('plotArea'));
    _frontWidthController = TextEditingController(text: p.text('frontWidth'));
    _depthController = TextEditingController(text: p.text('depth'));
    _floorNumberController = TextEditingController(text: p.text('floorNumber'));
    _totalFloorsCommercialController = TextEditingController(text: p.text('totalFloorsCommercial'));
    _unitNumberController = TextEditingController(text: p.text('unitNumber'));
    _ceilingHeightController = TextEditingController(text: p.text('ceilingHeight'));
    _loadingCapacityController = TextEditingController(text: p.text('loadingCapacity'));

    _constructionAgeController = TextEditingController(text: p.constructionAge ?? '');
    _pgTotalRoomsController = TextEditingController(text: p.text('pgTotalRooms'));
    _pgTotalBedsController = TextEditingController(text: p.text('pgTotalBedsCapacity'));
    _pgOccupiedBedsController = TextEditingController(text: p.text('pgOccupiedBeds'));
    _pgAvailableBedsController = TextEditingController(text: p.text('pgAvailableBeds'));
  }

  @override
  void dispose() {
    _areaController.dispose();
    _carpetAreaController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _balconiesController.dispose();
    _floorNoController.dispose();
    _totalFloorsController.dispose();
    _superBuiltUpAreaController.dispose();
    _plotAreaController.dispose();
    _frontWidthController.dispose();
    _depthController.dispose();
    _floorNumberController.dispose();
    _totalFloorsCommercialController.dispose();
    _unitNumberController.dispose();
    _ceilingHeightController.dispose();
    _loadingCapacityController.dispose();
    _constructionAgeController.dispose();
    _pgTotalRoomsController.dispose();
    _pgTotalBedsController.dispose();
    _pgOccupiedBedsController.dispose();
    _pgAvailableBedsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();
    final category = provider.category;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WizardCard(
          icon: Icons.straighten_outlined,
          title: 'Area',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WizardField(
                label: 'Total / Built-up Area *',
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: WizardTextField(
                        controller: _areaController,
                        hint: 'e.g., 1500',
                        keyboardType: TextInputType.number,
                        onChanged: (v) => context.read<PostPropertyProvider>().setArea(v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _UnitDropdown(
                        value: provider.areaUnit,
                        units: _areaUnits,
                        onChanged: (v) =>
                            context.read<PostPropertyProvider>().setAreaUnit(v),
                      ),
                    ),
                  ],
                ),
              ),
              const WizardDivider(),
              WizardField(
                label: 'Carpet Area',
                child: WizardTextField(
                  controller: _carpetAreaController,
                  hint: 'e.g., 1200',
                  keyboardType: TextInputType.number,
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setCarpetArea(v),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (category == PropertyCategory.residential || category == null)
          _buildResidentialCard(context, provider),
        if (category == PropertyCategory.commercial)
          _buildCommercialCard(context, provider),
        if (category == PropertyCategory.pg) ...[
          _buildPgStructureCard(context, provider),
          const SizedBox(height: 20),
          _buildPgRoomCard(context, provider),
        ],
      ],
    );
  }

  Widget _buildResidentialCard(BuildContext context, PostPropertyProvider provider) {
    return WizardCard(
      icon: Icons.meeting_room_outlined,
      title: 'Layout',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WizardField(
            label: 'BHK Type *',
            child: WizardChipGroup(
              options: _bhkTypes,
              selected: provider.bhkType,
              onSelected: (v) => context.read<PostPropertyProvider>().setBhkType(v),
            ),
          ),
          const WizardDivider(),
          Row(
            children: [
              Expanded(
                child: WizardField(
                  label: 'Bedrooms *',
                  child: WizardTextField(
                    controller: _bedroomsController,
                    hint: '3',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => context.read<PostPropertyProvider>().setBedrooms(v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Bathrooms *',
                  child: WizardTextField(
                    controller: _bathroomsController,
                    hint: '2',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => context.read<PostPropertyProvider>().setBathrooms(v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Balconies',
                  child: WizardTextField(
                    controller: _balconiesController,
                    hint: '1',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => context.read<PostPropertyProvider>().setBalconies(v),
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
                  label: 'Floor No',
                  child: WizardTextField(
                    controller: _floorNoController,
                    hint: 'e.g., 4',
                    onChanged: (v) => context.read<PostPropertyProvider>().setFloorNo(v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Total Floors',
                  child: WizardTextField(
                    controller: _totalFloorsController,
                    hint: 'e.g., 12',
                    onChanged: (v) => context.read<PostPropertyProvider>().setTotalFloors(v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommercialCard(BuildContext context, PostPropertyProvider provider) {
    return WizardCard(
      icon: Icons.apartment_outlined,
      title: 'Commercial Dimensions',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: WizardField(
                  label: 'Super Built-up Area',
                  child: WizardTextField(
                    controller: _superBuiltUpAreaController,
                    hint: 'e.g., 1800',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('superBuiltUpArea', v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Plot Area',
                  child: WizardTextField(
                    controller: _plotAreaController,
                    hint: 'e.g., 2000',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('plotArea', v),
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
                  label: 'Front Width (ft)',
                  child: WizardTextField(
                    controller: _frontWidthController,
                    hint: 'e.g., 30',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('frontWidth', v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Depth (ft)',
                  child: WizardTextField(
                    controller: _depthController,
                    hint: 'e.g., 50',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('depth', v),
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
                  label: 'Floor Number',
                  child: WizardTextField(
                    controller: _floorNumberController,
                    hint: 'e.g., Ground, 1st',
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('floorNumber', v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Total Floors',
                  child: WizardTextField(
                    controller: _totalFloorsCommercialController,
                    hint: 'e.g., 5',
                    onChanged: (v) => context
                        .read<PostPropertyProvider>()
                        .setText('totalFloorsCommercial', v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Unit Number',
                  child: WizardTextField(
                    controller: _unitNumberController,
                    hint: 'e.g., Shop 12',
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('unitNumber', v),
                  ),
                ),
              ),
            ],
          ),
          const WizardDivider(),
          WizardField(
            label: 'Property On',
            child: WizardChipGroup(
              options: _propertyOnOptions,
              selected: provider.text('propertyOn').isEmpty ? null : provider.text('propertyOn'),
              onSelected: (v) => context.read<PostPropertyProvider>().setText('propertyOn', v),
            ),
          ),
          const WizardDivider(),
          WizardField(
            label: 'Building Class',
            child: WizardChipGroup(
              options: _buildingClassOptions,
              selected: provider.text('buildingClass').isEmpty
                  ? null
                  : provider.text('buildingClass'),
              onSelected: (v) =>
                  context.read<PostPropertyProvider>().setText('buildingClass', v),
            ),
          ),
          const WizardDivider(),
          Row(
            children: [
              Expanded(
                child: WizardField(
                  label: 'Ceiling Height (ft)',
                  child: WizardTextField(
                    controller: _ceilingHeightController,
                    hint: 'e.g., 12',
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('ceilingHeight', v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Loading Capacity (tons)',
                  child: WizardTextField(
                    controller: _loadingCapacityController,
                    hint: 'e.g., 5',
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('loadingCapacity', v),
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
                label: 'Corner Property',
                value: provider.boolVal('cornerProperty'),
                onChanged: (v) =>
                    context.read<PostPropertyProvider>().setBoolVal('cornerProperty', v),
              ),
              WizardCheckboxTile(
                label: 'Main Road Facing',
                value: provider.boolVal('mainRoadFacing'),
                onChanged: (v) =>
                    context.read<PostPropertyProvider>().setBoolVal('mainRoadFacing', v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPgStructureCard(BuildContext context, PostPropertyProvider provider) {
    return WizardCard(
      icon: Icons.apartment_outlined,
      title: 'PG Structure & Capacity',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: WizardField(
                  label: 'Total Floors',
                  child: WizardTextField(
                    controller: _totalFloorsController,
                    hint: 'e.g., 4',
                    onChanged: (v) => context.read<PostPropertyProvider>().setTotalFloors(v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Floor Number',
                  child: WizardTextField(
                    controller: _floorNoController,
                    hint: 'e.g., 2',
                    onChanged: (v) => context.read<PostPropertyProvider>().setFloorNo(v),
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
                  label: 'Building Age (Years)',
                  child: WizardTextField(
                    controller: _constructionAgeController,
                    hint: 'e.g., 5',
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setConstructionAge(v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Facing',
                  child: WizardChipGroup(
                    options: _facingOptions,
                    selected: provider.facing,
                    onSelected: (v) => context.read<PostPropertyProvider>().setFacing(v),
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
                  label: 'Total Rooms',
                  child: WizardTextField(
                    controller: _pgTotalRoomsController,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('pgTotalRooms', v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Total Beds Capacity',
                  child: WizardTextField(
                    controller: _pgTotalBedsController,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => context
                        .read<PostPropertyProvider>()
                        .setText('pgTotalBedsCapacity', v),
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
                  label: 'Occupied Beds',
                  child: WizardTextField(
                    controller: _pgOccupiedBedsController,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('pgOccupiedBeds', v),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: WizardField(
                  label: 'Available Beds',
                  child: WizardTextField(
                    controller: _pgAvailableBedsController,
                    hint: '0',
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        context.read<PostPropertyProvider>().setText('pgAvailableBeds', v),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPgRoomCard(BuildContext context, PostPropertyProvider provider) {
    return WizardCard(
      icon: Icons.bed_outlined,
      title: 'Room & Bed Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WizardField(
            label: 'Room Types',
            child: WizardMultiChipGroup(
              options: _roomTypes,
              selected: provider.listVal('roomTypes'),
              onChanged: (v) => context.read<PostPropertyProvider>().setListVal('roomTypes', v),
            ),
          ),
          const WizardDivider(),
          WizardField(
            label: 'Bed Types',
            child: WizardMultiChipGroup(
              options: _bedTypes,
              selected: provider.listVal('bedType'),
              onChanged: (v) => context.read<PostPropertyProvider>().setListVal('bedType', v),
            ),
          ),
          const WizardDivider(),
          WizardField(
            label: 'Room Features',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _pgRoomFeatures.map((f) {
                return WizardCheckboxTile(
                  label: f.$2,
                  value: provider.boolVal(f.$1),
                  onChanged: (v) =>
                      context.read<PostPropertyProvider>().setBoolVal(f.$1, v),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitDropdown extends StatelessWidget {
  final String value;
  final List<(String, String)> units;
  final ValueChanged<String> onChanged;

  const _UnitDropdown({
    required this.value,
    required this.units,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: units
              .map((u) => DropdownMenuItem(value: u.$1, child: Text(u.$2)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
