import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../providers/post_property_provider.dart';
import '../listing_area_units.dart';
import '../listing_constants.dart';
import '../portal_kit.dart';
import '../portal_theme.dart';

/// Step 3 — reproduction of the portal's `PropertyDimensionsStep.tsx`.
///
/// The portal enumerates all 15 category x listingType branches, but the tree
/// only varies by category, plus a single `isRent` flag inside the land block:
///
///   land        LandArea -> LandDimensions(isRent) -> AvailableFrom
///   residential ResidentialapartmentDimensions | ResidentialhouseDimension
///               -> AvailableFrom
///   commercial  CommercialDimensions
///   pg          Area -> PgDimensions
///   others      Area
///
/// Two intentional deviations, both nested-array editors with no data model in
/// this app — see the class docs on [_FloorWiseRoomDetails] and
/// [_BuildingFloorInventory]. Their headings, position and spacing are kept and
/// nothing is reordered around them, the same treatment the Google Maps picker
/// got in Step 2.
class PropertyDimensionsStep extends StatefulWidget {
  const PropertyDimensionsStep({super.key});

  @override
  State<PropertyDimensionsStep> createState() => _PropertyDimensionsStepState();
}

/// The land side dimensions, in the portal's render order
/// (`['front', 'back', 'right', 'left'].map(...)`). Each pairs with a
/// `<name>Unit` key.
const List<String> _kLandSides = ['front', 'back', 'right', 'left'];

/// `buildingInventory.buildingType`, verbatim from the select.
const List<String> _kCommercialBuildingTypes = [
  'Corporate Tower',
  'IT Park',
  'Individual Building',
  'Business Center',
  'Commercial Complex',
  'Mixed Use',
];

/// PG `facing`, verbatim from the inline array in `PgDimensions`.
const List<String> _kPgFacing = [
  'East',
  'West',
  'North',
  'South',
  'North-East',
  'North-West',
  'South-East',
  'South-West',
];

/// Land side dimensions and height restriction spell their units out.
const Map<String, String> _kSideUnitLabels = {
  'ft': 'Feet',
  'm': 'Meters',
  'yards': 'Yards',
};

/// The commercial plot-area select is hardcoded in the portal rather than
/// coming from `getAreaUnitsForPropertyType`, and it says `sq_yd` where the
/// shared table says `sq_yards`. Reproduced literally.
const Map<String, String> _kPlotAreaUnitLabels = {
  'sq_ft': 'Square Feet',
  'sq_yd': 'Square Yards',
  'sq_mtr': 'Square Meters',
  'acres': 'Acres',
};

// Field-icon accents. The portal gives each field a differently-coloured label
// icon so a long form stays scannable; that hierarchy is kept, but the hues are
// the app's ([PortalTheme] -> AppColors), not the portal's Tailwind palette.
// Several distinct Tailwind hues collapse onto one app token — the app has a
// smaller palette by design.
const Color _cArea = PortalTheme.iconBlue; // was blue-500
const Color _cAreaAlt = PortalTheme.iconPrimary; // was purple/violet/fuchsia
const Color _cLayout = PortalTheme.iconIndigo; // was indigo-500
const Color _cRooms = PortalTheme.iconRed; // was pink-500 / rose-500
const Color _cWater = PortalTheme.iconTeal; // was cyan-500 / teal-500
const Color _cAir = PortalTheme.iconBlue; // was sky-500
const Color _cFloors = PortalTheme.iconMuted; // was slate-500
const Color _cLand = PortalTheme.iconGreen; // was green-500
const Color _cDate = PortalTheme.success; // was emerald-500
const Color _cDoc = PortalTheme.iconPrimary; // was orange-500 / amber-500

/// `value.replace(/[^\d.]/g, '')` on the area inputs.
final List<TextInputFormatter> _kNumericish = [
  FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
];

class _PropertyDimensionsStepState extends State<PropertyDimensionsStep> {
  // Named provider fields.
  late final TextEditingController _area;
  late final TextEditingController _carpetArea;
  late final TextEditingController _builtUpArea;
  late final TextEditingController _bedrooms;
  late final TextEditingController _bathrooms;
  late final TextEditingController _balconies;
  late final TextEditingController _floorNo;
  late final TextEditingController _totalFloors;

  // Land — metadata bag.
  late final Map<String, TextEditingController> _sides;
  late final TextEditingController _surveyNumber;
  late final TextEditingController _fsiFarAllowed;
  late final TextEditingController _floorAllowed;
  late final TextEditingController _heightRestriction;

  // Commercial — metadata bag and the nested buildingInventory object.
  late final TextEditingController _buildingName;
  late final TextEditingController _buildingCode;
  late final TextEditingController _totalFloorsBuilding;
  late final TextEditingController _plotArea;
  late final TextEditingController _superBuiltUpArea;

  @override
  void initState() {
    super.initState();
    final p = context.read<PostPropertyProvider>();

    _area = TextEditingController(text: p.area);
    _carpetArea = TextEditingController(text: p.carpetArea);
    _builtUpArea = TextEditingController(text: p.text('builtUpArea'));
    _bedrooms = TextEditingController(text: p.bedrooms);
    _bathrooms = TextEditingController(text: p.bathrooms);
    _balconies = TextEditingController(text: p.balconies);
    _floorNo = TextEditingController(text: p.floorNo);
    _totalFloors = TextEditingController(text: p.totalFloors);

    _sides = {
      for (final s in _kLandSides) s: TextEditingController(text: p.text(s)),
    };
    _surveyNumber = TextEditingController(text: p.text('surveyNumber'));
    _fsiFarAllowed = TextEditingController(text: p.text('fsiFarAllowed'));
    _floorAllowed = TextEditingController(text: p.text('floorAllowed'));
    _heightRestriction = TextEditingController(
      text: p.text('heightRestriction'),
    );

    _buildingName = TextEditingController(
      text: p.buildingInventoryText('buildingName'),
    );
    _buildingCode = TextEditingController(
      text: p.buildingInventoryText('buildingCode'),
    );
    _totalFloorsBuilding = TextEditingController(
      text: p.buildingInventoryText('totalFloorsBuilding'),
    );
    _plotArea = TextEditingController(text: p.text('plotArea'));
    _superBuiltUpArea = TextEditingController(text: p.text('superBuiltUpArea'));
  }

  @override
  void dispose() {
    for (final c in [
      _area,
      _carpetArea,
      _builtUpArea,
      _bedrooms,
      _bathrooms,
      _balconies,
      _floorNo,
      _totalFloors,
      ..._sides.values,
      _surveyNumber,
      _fsiFarAllowed,
      _floorAllowed,
      _heightRestriction,
      _buildingName,
      _buildingCode,
      _totalFloorsBuilding,
      _plotArea,
      _superBuiltUpArea,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostPropertyProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PortalStepHeader(
          icon: 'ruler',
          title: 'Dimensions & Layout',
          subtitle: 'Specify the physical size and layout.',
          badge2: p.category?.name.toUpperCase(),
          badge: p.listingIntent?.name.toUpperCase(),
        ),
        Container(
          padding: const EdgeInsets.all(16), // p-4
          decoration: BoxDecoration(
            color: PortalTheme.cardSurface,
            borderRadius: BorderRadius.circular(16), // rounded-2xl
            border: Border.all(color: PortalTheme.headerBorder),
            boxShadow: PortalTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _body(p),
          ),
        ),
      ],
    );
  }

  List<Widget> _body(PostPropertyProvider p) => switch (p.category) {
    PropertyCategory.land => [
      ..._landArea(p),
      ..._landDimensions(p),
      ..._availableFrom(p),
    ],
    PropertyCategory.residential => [
      if (kApartmentSubtypes.contains(p.residentialSubType ?? ''))
        ..._apartmentDimensions(p)
      else
        ..._houseDimensions(p),
      ..._availableFrom(p),
    ],
    PropertyCategory.commercial => _commercialDimensions(p),
    PropertyCategory.pg => [..._areaBlock(p), ..._pgDimensions(p)],
    _ => _areaBlock(p),
  };

  // ------------------------------------------------------------------ pieces

  /// The `flex gap-2` pairing of a value input with its unit select.
  Widget _withUnit({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    String? hint,
    Widget? prefix,
    required String unit,
    required List<(String, String)> units,
    required ValueChanged<String> onUnitChanged,
    required double unitWidth,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final labels = {for (final u in units) u.$1: u.$2};
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: PortalTextField(
            controller: controller,
            hint: hint,
            prefix: prefix,
            onChanged: onChanged,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
          ),
        ),
        const SizedBox(width: 8), // gap-2
        PortalSelect(
          value: unit,
          placeholder: '',
          options: [for (final u in units) u.$1],
          labelFor: (v) => labels[v] ?? v,
          triggerWidth: unitWidth,
          onChanged: onUnitChanged,
        ),
      ],
    );
  }

  /// `gap-3` between the cells of a `grid-cols-1` block, which is what every
  /// `md:grid-cols-N` on this step collapses to at mobile width.
  List<Widget> _stack(List<Widget> fields, {double top = 0}) => [
    if (top > 0) SizedBox(height: top),
    for (int i = 0; i < fields.length; i++) ...[
      if (i > 0) const SizedBox(height: 12),
      fields[i],
    ],
  ];

  // ------------------------------------------------------------------- Area

  /// `Area` — PG and Others. Note the Total Area label icon is `Square` while
  /// its input prefix is `Ruler`; they differ in the portal.
  List<Widget> _areaBlock(PostPropertyProvider p) {
    final units = areaUnitsFor(p.category, p.areaUnit);
    return _stack([
      PortalLabelledField(
        label: 'Total Area',
        required: true,
        icon: 'square',
        iconColor: _cArea,
        child: _withUnit(
          controller: _area,
          hint: 'e.g. 1500',
          prefix: const PortalIconTint('ruler', color: _cAreaAlt),
          inputFormatters: _kNumericish,
          onChanged: p.setArea,
          unit: p.areaUnit,
          units: units,
          onUnitChanged: p.setAreaUnit,
          unitWidth: 128, // w-32
        ),
      ),
      PortalLabelledField(
        label: 'Carpet Area',
        icon: 'maximize-2',
        iconColor: _cAreaAlt,
        child: _withUnit(
          controller: _carpetArea,
          hint: 'e.g. 1200',
          prefix: const PortalIconTint('maximize-2', color: _cAreaAlt),
          inputFormatters: _kNumericish,
          onChanged: p.setCarpetArea,
          unit: p.areaUnit,
          units: units,
          onUnitChanged: p.setAreaUnit,
          unitWidth: 128,
        ),
      ),
    ]);
  }

  // --------------------------------------------------------------- Land area

  List<Widget> _landArea(PostPropertyProvider p) => _stack([
    PortalLabelledField(
      // The portal ternaries on propertyType; this component only renders
      // for land, so the land wording is the live branch.
      label: 'Total Land Area',
      required: true,
      icon: 'square',
      iconColor: _cArea,
      child: _withUnit(
        controller: _area,
        hint: 'e.g. 1500',
        prefix: const PortalIconTint('square', color: _cArea),
        inputFormatters: _kNumericish,
        onChanged: p.setArea,
        unit: p.areaUnit,
        units: areaUnitsFor(p.category, p.areaUnit),
        onUnitChanged: p.setAreaUnit,
        unitWidth: 128,
      ),
    ),
  ]);

  // --------------------------------------------------------- Land dimensions

  List<Widget> _landDimensions(PostPropertyProvider p) {
    final bool isRent = p.listingIntent == ListingIntent.rent;
    return [
      if (isRent)
        ..._stack(top: 8, [
          PortalLabelledSelect(
            label: 'Land Use / Master Plan',
            icon: 'layout-grid',
            iconColor: _cLayout,
            value: p.text('landUseMasterPlan'),
            placeholder: 'Select',
            options: kLandUseMasterPlanOptions,
            onChanged: (v) => p.setText('landUseMasterPlan', v),
          ),
        ]),

      const PortalBlockHeading('Land Specification'),

      ..._stack(top: 8, [
        for (final side in _kLandSides)
          PortalLabelledField(
            // `capitalize` applied to the raw key.
            label: '${side[0].toUpperCase()}${side.substring(1)}',
            icon: 'move',
            iconColor: _cWater,
            child: _withUnit(
              controller: _sides[side]!,
              prefix: const PortalIconTint('move', color: _cWater),
              inputFormatters: _kNumericish,
              onChanged: (v) => p.setText(side, v),
              unit: p.text('${side}Unit').isEmpty
                  ? kLandSideDimensionUnits.first
                  : p.text('${side}Unit'),
              units: [
                for (final u in kLandSideDimensionUnits)
                  (u, _kSideUnitLabels[u] ?? u),
              ],
              onUnitChanged: (v) => p.setText('${side}Unit', v),
              unitWidth: 80, // w-20
            ),
          ),
      ]),

      ..._stack(top: 16, [
        PortalLabelledField(
          // id="surveyNumber", labelled "Khasra Number".
          label: 'Khasra Number',
          icon: 'file-digit',
          iconColor: _cDoc,
          child: PortalTextField(
            controller: _surveyNumber,
            prefix: const PortalIconTint('file-digit', color: _cWater),
            inputFormatters: _kNumericish,
            onChanged: (v) => p.setText('surveyNumber', v),
          ),
        ),
      ]),

      ..._stack(top: 16, [
        PortalLabelledField(
          label: 'FSI/FAR Allowed',
          icon: 'bar-chart-2',
          iconColor: _cWater,
          child: PortalTextField(
            controller: _fsiFarAllowed,
            prefix: const PortalIconTint('bar-chart-2', color: _cWater),
            inputFormatters: _kNumericish,
            onChanged: (v) => p.setText('fsiFarAllowed', v),
          ),
        ),
        PortalLabelledField(
          label: 'Floor Allowed',
          icon: 'layers',
          iconColor: _cFloors,
          child: PortalTextField(
            controller: _floorAllowed,
            prefix: const PortalIconTint('layers', color: _cFloors),
            // The portal runs `/\D/g` here (digits only, no decimal) —
            // unlike the other land fields, which allow `.`.
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) => p.setText('floorAllowed', v),
          ),
        ),
        PortalLabelledField(
          label: 'Height Restriction',
          icon: 'arrow-up-from-line',
          iconColor: _cRooms,
          child: _withUnit(
            controller: _heightRestriction,
            prefix: const PortalIconTint('arrow-up-from-line', color: _cRooms),
            inputFormatters: _kNumericish,
            onChanged: (v) => p.setText('heightRestriction', v),
            unit: p.text('heightRestrictionUnit').isEmpty
                ? kHeightRestrictionUnits.first
                : p.text('heightRestrictionUnit'),
            units: [
              for (final u in kHeightRestrictionUnits)
                (u, _kSideUnitLabels[u] ?? u),
            ],
            onUnitChanged: (v) => p.setText('heightRestrictionUnit', v),
            unitWidth: 80,
          ),
        ),
        PortalLabelledField(
          label: 'Soil Type',
          icon: 'sprout',
          iconColor: _cLand,
          // `<SelectValue />` with no placeholder prop — the trigger reads
          // blank until a soil type is picked.
          child: PortalSelect(
            value: p.text('soilType'),
            placeholder: '',
            options: kLandSoilTypes,
            onChanged: (v) => p.setText('soilType', v),
          ),
        ),
      ]),
    ];
  }

  // ------------------------------------------------------ Residential layouts

  Widget _bhkTypeField(PostPropertyProvider p) => PortalLabelledSelect(
    label: 'BHK Type',
    required: true,
    icon: 'layout-grid',
    iconColor: _cLayout,
    value: p.bhkType,
    placeholder: 'Select',
    options: kBhkTypes,
    onChanged: p.setBhkType,
  );

  /// Bedrooms and Bathrooms — the label icon and the prefix icon differ in
  /// colour in the portal (pink/cyan on the labels, blue on both prefixes).
  List<Widget> _bedBathFields(PostPropertyProvider p) => [
    PortalLabelledField(
      label: 'Bedrooms',
      required: true,
      icon: 'bed-double',
      iconColor: _cRooms,
      child: PortalTextField(
        controller: _bedrooms,
        prefix: const PortalIconTint('bed-double', color: _cArea),
        keyboardType: TextInputType.number,
        onChanged: p.setBedrooms,
      ),
    ),
    PortalLabelledField(
      label: 'Bathrooms',
      required: true,
      icon: 'bath',
      iconColor: _cWater,
      child: PortalTextField(
        controller: _bathrooms,
        prefix: const PortalIconTint('bath', color: _cArea),
        keyboardType: TextInputType.number,
        onChanged: p.setBathrooms,
      ),
    ),
  ];

  Widget _balconiesField(PostPropertyProvider p) => PortalLabelledField(
    label: 'Balconies',
    icon: 'wind',
    iconColor: _cAir,
    child: PortalTextField(
      controller: _balconies,
      prefix: const PortalIconTint('wind', color: _cArea),
      keyboardType: TextInputType.number,
      onChanged: p.setBalconies,
    ),
  );

  Widget _totalFloorsField(PostPropertyProvider p) => PortalLabelledField(
    label: 'Total Floors',
    icon: 'layers',
    iconColor: _cFloors,
    child: PortalTextField(
      controller: _totalFloors,
      prefix: const PortalIconTint('layers', color: _cFloors),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: p.setTotalFloors,
    ),
  );

  Widget _propertyConditionField(PostPropertyProvider p) =>
      PortalLabelledSelect(
        label: 'Property Condition',
        icon: 'gauge',
        iconColor: _cAreaAlt,
        value: p.propertyCondition,
        placeholder: 'Select',
        options: kPropertyConditions,
        onChanged: p.setPropertyCondition,
      );

  /// `ResidentialapartmentDimensions` — Flat, Independent / Builder Floor and
  /// Studio / Service Apartment.
  List<Widget> _apartmentDimensions(PostPropertyProvider p) {
    final units = areaUnitsFor(p.category, p.areaUnit);
    return [
      ..._stack(top: 8, [
        PortalLabelledField(
          label: 'Total Area',
          required: true,
          icon: 'square',
          iconColor: _cArea,
          child: _withUnit(
            controller: _area,
            hint: 'e.g. 1500',
            prefix: const PortalIconTint('square', color: _cArea),
            inputFormatters: _kNumericish,
            onChanged: p.setArea,
            unit: p.areaUnit,
            units: units,
            onUnitChanged: p.setAreaUnit,
            unitWidth: 128,
          ),
        ),
        PortalLabelledField(
          label: 'Carpet Area',
          icon: 'maximize-2',
          iconColor: _cAreaAlt,
          child: _withUnit(
            controller: _carpetArea,
            hint: 'e.g. 1200',
            prefix: const PortalIconTint('maximize-2', color: _cAreaAlt),
            inputFormatters: _kNumericish,
            onChanged: p.setCarpetArea,
            unit: p.areaUnit,
            units: units,
            onUnitChanged: p.setAreaUnit,
            unitWidth: 128,
          ),
        ),
        _bhkTypeField(p),
        ..._bedBathFields(p),
      ]),
      ..._stack(top: 8, [
        _balconiesField(p),
        PortalLabelledField(
          label: 'Floor No',
          icon: 'arrow-up',
          iconColor: _cDoc,
          child: PortalTextField(
            controller: _floorNo,
            prefix: const PortalIconTint('arrow-up', color: _cDoc),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: p.setFloorNo,
          ),
        ),
        _totalFloorsField(p),
        _propertyConditionField(p),
      ]),
    ];
  }

  /// `ResidentialhouseDimension` — every other residential subtype. Plot Area
  /// and Build Up Area replace Total Area, and there is no Floor No.
  List<Widget> _houseDimensions(PostPropertyProvider p) {
    final units = areaUnitsFor(p.category, p.areaUnit);
    return [
      ..._stack([
        PortalLabelledField(
          label: 'Plot Area',
          required: true,
          icon: 'square',
          iconColor: _cArea,
          child: _withUnit(
            controller: _area,
            hint: 'e.g. 1500',
            prefix: const PortalIconTint('square', color: _cArea),
            inputFormatters: _kNumericish,
            onChanged: p.setArea,
            unit: p.areaUnit,
            units: units,
            onUnitChanged: p.setAreaUnit,
            unitWidth: 128,
          ),
        ),
        PortalLabelledField(
          label: 'Build Up Area',
          icon: 'maximize-2',
          iconColor: _cAreaAlt,
          child: _withUnit(
            controller: _builtUpArea,
            hint: 'e.g. 1200',
            prefix: const PortalIconTint('maximize-2', color: _cAreaAlt),
            inputFormatters: _kNumericish,
            onChanged: (v) => p.setText('builtUpArea', v),
            unit: p.areaUnit,
            units: units,
            onUnitChanged: p.setAreaUnit,
            unitWidth: 128,
          ),
        ),
        PortalLabelledField(
          label: 'Carpet Area',
          icon: 'maximize-2',
          iconColor: _cAreaAlt,
          child: _withUnit(
            controller: _carpetArea,
            hint: 'e.g. 1200',
            prefix: const PortalIconTint('maximize-2', color: _cAreaAlt),
            inputFormatters: _kNumericish,
            onChanged: p.setCarpetArea,
            unit: p.areaUnit,
            units: units,
            onUnitChanged: p.setAreaUnit,
            unitWidth: 128,
          ),
        ),
      ]),
      ..._stack(top: 8, [_bhkTypeField(p), ..._bedBathFields(p)]),
      ..._stack(top: 8, [
        _balconiesField(p),
        _totalFloorsField(p),
        _propertyConditionField(p),
      ]),
    ];
  }

  // --------------------------------------------------- Commercial dimensions

  List<Widget> _commercialDimensions(PostPropertyProvider p) => [
    const PortalBlockHeading('Building Level Details'),
    ..._stack(top: 8, [
      PortalLabelledField(
        label: 'Building Name',
        required: true,
        icon: 'building-2',
        iconColor: _cLayout,
        child: PortalTextField(
          controller: _buildingName,
          hint: 'Enter building name',
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
          ],
          onChanged: (v) => p.setBuildingInventoryValue('buildingName', v),
        ),
      ),
      PortalLabelledField(
        // id="buildingCode", labelled "Building Number".
        label: 'Building Number',
        required: true,
        icon: 'hash',
        iconColor: _cFloors,
        child: PortalTextField(
          controller: _buildingCode,
          hint: 'Enter building Number',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) => p.setBuildingInventoryValue('buildingCode', v),
        ),
      ),
      // The one label on this step the portal gives no icon.
      PortalLabelledSelect(
        label: 'Building Type',
        required: true,
        value: p.buildingInventoryText('buildingType'),
        placeholder: 'Select building type',
        options: _kCommercialBuildingTypes,
        onChanged: (v) => p.setBuildingInventoryValue('buildingType', v),
      ),
    ]),
    ..._stack(top: 8, [
      PortalLabelledField(
        label: 'Total Floors',
        required: true,
        icon: 'layers',
        iconColor: _cFloors,
        child: PortalTextField(
          controller: _totalFloorsBuilding,
          hint: 'e.g. 10',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (v) =>
              p.setBuildingInventoryValue('totalFloorsBuilding', v),
        ),
      ),
    ]),
    const PortalBlockHeading('Area Details'),
    ..._stack(top: 8, [
      PortalLabelledField(
        label: 'Plot Area',
        required: true,
        icon: 'square',
        iconColor: _cArea,
        child: _withUnit(
          controller: _plotArea,
          hint: 'e.g. 2000',
          prefix: const PortalIconTint('square', color: _cArea),
          inputFormatters: _kNumericish,
          onChanged: (v) => p.setText('plotArea', v),
          unit: p.text('plotAreaUnit').isEmpty
              ? kPlotAreaUnits.first
              : p.text('plotAreaUnit'),
          units: [
            for (final u in kPlotAreaUnits) (u, _kPlotAreaUnitLabels[u] ?? u),
          ],
          onUnitChanged: (v) => p.setText('plotAreaUnit', v),
          unitWidth: 112, // w-28
        ),
      ),
      PortalLabelledField(
        label: 'Super Built-up Area',
        required: true,
        icon: 'maximize',
        iconColor: _cAreaAlt,
        child: _withUnit(
          controller: _superBuiltUpArea,
          hint: 'e.g. 1800',
          prefix: const PortalIconTint('maximize', color: _cAreaAlt),
          inputFormatters: _kNumericish,
          // Commercial has no separate Total Area box, so the portal keeps
          // `area` — the figure shown on cards — in step with this one.
          onChanged: (v) {
            p.setText('superBuiltUpArea', v);
            p.setArea(v);
          },
          unit: p.areaUnit,
          units: areaUnitsFor(PropertyCategory.commercial, p.areaUnit),
          onUnitChanged: p.setAreaUnit,
          unitWidth: 112,
        ),
      ),
    ]),
    const PortalBlockHeading('Floor-wise Inventory Management'),
    const _BuildingFloorInventory(),
  ];

  // ----------------------------------------------------------- PG dimensions

  List<Widget> _pgDimensions(PostPropertyProvider p) => [
    const PortalBlockHeading('PG Structure & Capacity'),
    ..._stack(top: 8, [
      _totalFloorsField(p),
      // No label icon in the portal.
      PortalLabelledSelect(
        label: 'Facing',
        value: p.facing,
        placeholder: 'Select',
        options: _kPgFacing,
        onChanged: p.setFacing,
      ),
      PortalLabelledField(
        label: 'Total Rooms',
        // Derived, not typed: the sum of every floor's room count.
        child: PortalReadOnlyBox('${p.totalRoomsAcrossFloors}'),
      ),
    ]),
    _FloorWiseRoomDetails(totalFloors: p.totalFloors),
  ];

  // --------------------------------------------------------- Available from

  List<Widget> _availableFrom(PostPropertyProvider p) => _stack(top: 8, [
    PortalLabelledField(
      label: 'Available From',
      required: true,
      icon: 'calendar-days',
      iconColor: _cDate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalCheckbox(
            value: p.availableImmediately,
            label: 'Immediately',
            onChanged: p.setAvailableImmediately,
          ),
          if (!p.availableImmediately) ...[
            const SizedBox(height: 8), // gap-2
            _DateField(value: p.availableFrom, onChanged: p.setAvailableFrom),
          ],
        ],
      ),
    ),
  ]);
}

/// `<Input type="date">` with the calendar prefix the portal puts inside it.
/// Tapping
/// opens the platform date picker instead of typing into the field — the one
/// concession mobile forces on a date input.
class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final d = value;
    final text = d == null
        ? ''
        : '${d.year.toString().padLeft(4, '0')}-'
              '${d.month.toString().padLeft(2, '0')}-'
              '${d.day.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: d ?? now,
          firstDate: DateTime(now.year - 1),
          lastDate: DateTime(now.year + 20),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        height: PortalTheme.inputHeight,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: PortalTheme.cardSurface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: PortalTheme.cardBorder),
        ),
        child: Row(
          children: [
            const PortalIconTint('calendar-days', color: _cDoc),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                text.isEmpty ? 'yyyy-mm-dd' : text,
                style: text.isEmpty
                    ? PortalTheme.inputText.copyWith(
                        color: PortalTheme.radioIdle,
                      )
                    : PortalTheme.inputText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PG `floorWiseRoomDetails[].rooms[].roomType`, verbatim from the portal's
/// inline array in `FloorWiseRoomDetails`.
const List<String> _kPgRoomTypes = [
  'Single Sharing',
  'Double Sharing',
  'Triple Sharing',
  'Four Sharing',
  'Dormitory',
  'Private Room',
];

/// Reproduction of the portal's `FloorWiseRoomDetails` editor
/// (PropertyDimensionsStep.tsx:61-192).
///
/// One card per floor (1..Total Floors): a "Total Rooms" input that
/// regenerates that floor's `rooms[]` array on change — preserving each
/// existing room's type by room number — and, once rooms exist, a "Room
/// Type" select per room. Bound to
/// [PostPropertyProvider.setFloorTotalRooms]/[PostPropertyProvider.setFloorRoomType],
/// which write straight into `floorWiseRoomDetails`.
class _FloorWiseRoomDetails extends StatefulWidget {
  const _FloorWiseRoomDetails({required this.totalFloors});

  final String totalFloors;

  @override
  State<_FloorWiseRoomDetails> createState() => _FloorWiseRoomDetailsState();
}

class _FloorWiseRoomDetailsState extends State<_FloorWiseRoomDetails> {
  final Map<int, TextEditingController> _roomsControllers = {};

  TextEditingController _controllerFor(int floorNumber, int totalRooms) {
    return _roomsControllers.putIfAbsent(
      floorNumber,
      () => TextEditingController(text: totalRooms == 0 ? '' : '$totalRooms'),
    );
  }

  @override
  void dispose() {
    for (final c in _roomsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostPropertyProvider>();
    final int numFloors = int.tryParse(widget.totalFloors) ?? 0;
    if (numFloors == 0) return const SizedBox.shrink();

    // Floors removed by lowering Total Floors lose their controller, so
    // raising it again starts that floor fresh rather than resurrecting
    // stale typed text.
    _roomsControllers.removeWhere((floor, c) {
      if (floor <= numFloors) return false;
      c.dispose();
      return true;
    });

    return Padding(
      padding: const EdgeInsets.only(top: 24), // mt-6
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PortalBlockHeading(
            'Floor-wise Room Details',
            subtitle: 'Specify room details for each floor',
          ),
          for (var floorNumber = 1; floorNumber <= numFloors; floorNumber++)
            _floorCard(p, floorNumber),
        ],
      ),
    );
  }

  Widget _floorCard(PostPropertyProvider p, int floorNumber) {
    final entry = p.floorRoomDetails(floorNumber);
    final totalRooms = (entry?['totalRooms'] as int?) ?? 0;
    final rooms =
        (entry?['rooms'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PortalTheme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PortalTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PortalIconTint('layers', color: _cFloors),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Floor $floorNumber',
                  style: PortalTheme.inputLabel.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text('Total Rooms:', style: PortalTheme.blockSubtitle),
              const SizedBox(width: 6),
              SizedBox(
                width: 56,
                child: PortalTextField(
                  controller: _controllerFor(floorNumber, totalRooms),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) =>
                      p.setFloorTotalRooms(floorNumber, int.tryParse(v) ?? 0),
                ),
              ),
            ],
          ),
          if (totalRooms > 0) ...[
            const SizedBox(height: 10),
            Text('Room Types:', style: PortalTheme.blockSubtitle),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var roomNumber = 1; roomNumber <= totalRooms; roomNumber++)
                  SizedBox(
                    width: 168,
                    child: Row(
                      children: [
                        Text(
                          'Room $roomNumber:',
                          style: PortalTheme.inputLabel,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: PortalSelect(
                            value:
                                (rooms.firstWhere(
                                      (r) => r['roomNumber'] == roomNumber,
                                      orElse: () => const <String, dynamic>{},
                                    )['roomType']
                                    as String?) ??
                                'Single Sharing',
                            placeholder: 'Single Sharing',
                            options: _kPgRoomTypes,
                            onChanged: (v) =>
                                p.setFloorRoomType(floorNumber, roomNumber, v),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// `buildingInventory.floors[].floorFacing`, verbatim from the portal's
/// inline `SelectItem` list in `BuildingFloorInventory` (Step 1).
const List<String> _kBuildingFloorFacing = ['North', 'South', 'East', 'West'];

/// Reproduction of the portal's `BuildingFloorInventory` editor
/// (PropertyDimensionsStep.tsx:852-1170), adapted from its three-screen
/// push/pop stepper (floor list -> office list -> office detail screen) to a
/// mobile-appropriate accordion: one card per floor with its own fields
/// (Step 1) and, once "Number of Offices" is set, an expandable mini-card per
/// office (Steps 2+3 combined) — matching every other section of this step,
/// which is a single scroll, not a sub-wizard.
///
/// Bound to [PostPropertyProvider.setBuildingFloorField] /
/// [PostPropertyProvider.setBuildingNumberOfCompanies] /
/// [PostPropertyProvider.setBuildingOfficeField], which write straight into
/// `buildingInventory.floors[]` — already included in every save via the
/// existing `{...provider.buildingInventory}` spread in `_buildMetadata`.
///
/// The office detail form covers its five identifying/contact/financial
/// fields (Office Name, Office Number, Contact Person, Phone Number, Monthly
/// Rent); the portal's further ~30 optional facility-inventory fields per
/// office (workstations, washrooms, pantry, power, security, IT, furniture,
/// parking) are not collected here. Nothing is lost for web-created listings:
/// [PostPropertyProvider.setBuildingOfficeField] only ever touches the one
/// field it is passed, so every other key already on a company object
/// (created on the web, or by [PostPropertyProvider._blankOffice] for a new
/// one) survives untouched through edits.
class _BuildingFloorInventory extends StatefulWidget {
  const _BuildingFloorInventory();

  @override
  State<_BuildingFloorInventory> createState() =>
      _BuildingFloorInventoryState();
}

class _BuildingFloorInventoryState extends State<_BuildingFloorInventory> {
  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _expandedOffices = {};

  TextEditingController _ctrl(String key, String initial) {
    return _controllers.putIfAbsent(
      key,
      () => TextEditingController(text: initial),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PostPropertyProvider>();
    final int totalFloors =
        int.tryParse(p.buildingInventoryText('totalFloorsBuilding')) ?? 0;

    if (totalFloors == 0) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: PortalTheme.cardSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: PortalTheme.cardBorder),
        ),
        child: Text(
          'Please enter Total Floors in Building Level Details to manage '
          'floor-wise inventory',
          textAlign: TextAlign.center,
          style: PortalTheme.blockSubtitle,
        ),
      );
    }

    // Controllers (and their accordion state) for floors/offices removed by
    // lowering a count are dropped, so raising it again starts fresh rather
    // than resurrecting stale typed text.
    final validFloorKeys = List.generate(totalFloors, (i) => '${i + 1}:');
    _controllers.removeWhere((key, c) {
      if (validFloorKeys.any((k) => key.startsWith(k))) return false;
      c.dispose();
      return true;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var floorNumber = 1; floorNumber <= totalFloors; floorNumber++)
          _floorCard(p, floorNumber),
      ],
    );
  }

  Widget _floorCard(PostPropertyProvider p, int floorNumber) {
    final entry = p.buildingFloorEntry(floorNumber);
    String text(String field) => entry?[field]?.toString() ?? '';
    final numberOfCompanies = int.tryParse(text('numberOfCompanies')) ?? 0;
    final companies = (entry?['companies'] as List?) ?? const [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PortalTheme.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PortalTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const PortalIconTint('layers', color: _cFloors),
              const SizedBox(width: 6),
              Text(
                'Floor $floorNumber',
                style: PortalTheme.inputLabel.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PortalLabelledField(
                  label: 'Floor Name',
                  child: PortalTextField(
                    controller: _ctrl(
                      '$floorNumber:floorName',
                      text('floorName'),
                    ),
                    hint: 'e.g. Ground Floor',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z\s]')),
                    ],
                    onChanged: (v) =>
                        p.setBuildingFloorField(floorNumber, 'floorName', v),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PortalLabelledField(
                  label: 'Floor Area (Sq Ft)',
                  child: PortalTextField(
                    controller: _ctrl(
                      '$floorNumber:floorArea',
                      text('floorArea'),
                    ),
                    hint: 'e.g. 5000',
                    keyboardType: TextInputType.number,
                    inputFormatters: _kNumericish,
                    onChanged: (v) =>
                        p.setBuildingFloorField(floorNumber, 'floorArea', v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PortalLabelledField(
                  label: 'Super Built-up Area (Sq Ft)',
                  child: PortalTextField(
                    controller: _ctrl(
                      '$floorNumber:superBuiltUpArea',
                      text('superBuiltUpArea'),
                    ),
                    hint: 'e.g. 6000',
                    keyboardType: TextInputType.number,
                    inputFormatters: _kNumericish,
                    onChanged: (v) => p.setBuildingFloorField(
                      floorNumber,
                      'superBuiltUpArea',
                      v,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PortalLabelledField(
                  label: 'Occupancy %',
                  child: PortalTextField(
                    controller: _ctrl(
                      '$floorNumber:floorOccupancyPercentage',
                      text('floorOccupancyPercentage'),
                    ),
                    hint: 'e.g. 75',
                    keyboardType: TextInputType.number,
                    inputFormatters: _kNumericish,
                    onChanged: (v) => p.setBuildingFloorField(
                      floorNumber,
                      'floorOccupancyPercentage',
                      v,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          PortalLabelledField(
            label: 'Floor Facing',
            child: PortalSelect(
              value: text('floorFacing').isEmpty ? null : text('floorFacing'),
              placeholder: 'Select facing',
              options: _kBuildingFloorFacing,
              onChanged: (v) =>
                  p.setBuildingFloorField(floorNumber, 'floorFacing', v),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              PortalCheckbox(
                value: entry?['commonReceptionAvailable'] == true,
                label: 'Common Reception',
                onChanged: (v) => p.setBuildingFloorField(
                  floorNumber,
                  'commonReceptionAvailable',
                  v,
                ),
              ),
              PortalCheckbox(
                value: entry?['commonWashroomAvailable'] == true,
                label: 'Common Washroom',
                onChanged: (v) => p.setBuildingFloorField(
                  floorNumber,
                  'commonWashroomAvailable',
                  v,
                ),
              ),
              PortalCheckbox(
                value: entry?['commonPantryAvailable'] == true,
                label: 'Common Pantry',
                onChanged: (v) => p.setBuildingFloorField(
                  floorNumber,
                  'commonPantryAvailable',
                  v,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: PortalTheme.cardBorder)),
            ),
            child: PortalLabelledField(
              label: 'Number of Offices on this Floor',
              child: SizedBox(
                width: 100,
                child: PortalTextField(
                  controller: _ctrl(
                    '$floorNumber:numberOfCompanies',
                    text('numberOfCompanies'),
                  ),
                  hint: 'e.g. 3',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (v) => p.setBuildingNumberOfCompanies(
                    floorNumber,
                    int.tryParse(v) ?? 0,
                  ),
                ),
              ),
            ),
          ),
          for (var i = 0; i < numberOfCompanies && i < companies.length; i++)
            _officeCard(
              p,
              floorNumber,
              i,
              (companies[i] as Map?) ?? const <String, dynamic>{},
            ),
        ],
      ),
    );
  }

  Widget _officeCard(
    PostPropertyProvider p,
    int floorNumber,
    int companyIndex,
    Map office,
  ) {
    String text(String field) => office[field]?.toString() ?? '';
    final key = '$floorNumber:$companyIndex';
    final expanded = _expandedOffices.contains(key);
    final name = text('companyName');

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: PortalTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() {
              if (expanded) {
                _expandedOffices.remove(key);
              } else {
                _expandedOffices.add(key);
              }
            }),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Office ${companyIndex + 1}',
                        style: PortalTheme.inputLabel.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        name.isEmpty ? 'Not filled yet' : name,
                        style: PortalTheme.blockSubtitle,
                      ),
                    ],
                  ),
                ),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: PortalTheme.slate400,
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 10),
            PortalLabelledField(
              label: 'Office Name',
              required: true,
              child: PortalTextField(
                controller: _ctrl('$key:companyName', text('companyName')),
                onChanged: (v) => p.setBuildingOfficeField(
                  floorNumber,
                  companyIndex,
                  'companyName',
                  v,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PortalLabelledField(
                    label: 'Office Number',
                    child: PortalTextField(
                      controller: _ctrl(
                        '$key:officeNumber',
                        text('officeNumber'),
                      ),
                      onChanged: (v) => p.setBuildingOfficeField(
                        floorNumber,
                        companyIndex,
                        'officeNumber',
                        v,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PortalLabelledField(
                    label: 'Contact Person',
                    child: PortalTextField(
                      controller: _ctrl(
                        '$key:contactPerson',
                        text('contactPerson'),
                      ),
                      onChanged: (v) => p.setBuildingOfficeField(
                        floorNumber,
                        companyIndex,
                        'contactPerson',
                        v,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PortalLabelledField(
                    label: 'Phone Number',
                    child: PortalTextField(
                      controller: _ctrl(
                        '$key:phoneNumber',
                        text('phoneNumber'),
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (v) => p.setBuildingOfficeField(
                        floorNumber,
                        companyIndex,
                        'phoneNumber',
                        v,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PortalLabelledField(
                    label: 'Monthly Rent',
                    child: PortalTextField(
                      controller: _ctrl(
                        '$key:monthlyRent',
                        text('monthlyRent'),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: _kNumericish,
                      onChanged: (v) => p.setBuildingOfficeField(
                        floorNumber,
                        companyIndex,
                        'monthlyRent',
                        v,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
