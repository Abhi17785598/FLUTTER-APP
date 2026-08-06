import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/post_property_provider.dart';
import '../listing_constants.dart';
import '../portal_kit.dart';
import '../portal_theme.dart';
import '../widgets/project_tag_selector.dart';

/// Step 2 — reproduction of the portal's `BasicInfoStep.tsx`.
///
/// Render order, copy, placeholders, label icons and required markers are taken
/// from source. The portal branches on all 15 category x listingType
/// combinations, but every branch for a given category renders the same tree —
/// listing type does not vary this step — so the category switch below is the
/// whole of that logic.
///
/// Single intentional deviation: the Google Maps location picker is omitted
/// (the app has no map implementation). Its section, heading, position and
/// spacing are kept, and no field is reordered because of it.
class BasicInfoStep extends StatefulWidget {
  const BasicInfoStep({super.key});

  @override
  State<BasicInfoStep> createState() => _BasicInfoStepState();
}

class _BasicInfoStepState extends State<BasicInfoStep> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _pgPropertyName;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _stateField;
  late final TextEditingController _pincode;
  late final TextEditingController _landmark;

  @override
  void initState() {
    super.initState();
    final p = context.read<PostPropertyProvider>();
    _title = TextEditingController(text: p.title);
    _description = TextEditingController(text: p.description);
    _pgPropertyName = TextEditingController(text: p.text('pgPropertyName'));
    _address = TextEditingController(text: p.location);
    _city = TextEditingController(text: p.city);
    _stateField = TextEditingController(text: p.state);
    _pincode = TextEditingController(text: p.pincode);
    _landmark = TextEditingController(text: p.landmark);
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _pgPropertyName,
      _address,
      _city,
      _stateField,
      _pincode,
      _landmark,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  PostPropertyProvider get _p => context.read<PostPropertyProvider>();

  /// `formData.propertyType` as the portal spells it.
  static String _portalType(PropertyCategory? c) => switch (c) {
        PropertyCategory.land => 'land',
        PropertyCategory.residential => 'residential',
        PropertyCategory.commercial => 'commercial',
        PropertyCategory.pg => 'pg/Co-living',
        PropertyCategory.other => 'others',
        null => '',
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();
    final type = _portalType(provider.category);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalStepHeader(
          icon: 'file-text',
          title: 'Basic Information',
          subtitle: 'Essential details about your property',
          // badge2 (propertyType) renders before badge (listingType).
          badge2: type.isEmpty ? null : type,
          badge: provider.listingIntent?.name,
        ),

        // The step's white card: border-orange-100/70, shadow-sm,
        // rounded-2xl, p-4.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PortalTheme.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PortalTheme.headerBorder),
            boxShadow: PortalTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Category block (space-y-4) ───────────────────────────
              // The portal's `grid-cols-1 md:grid-cols-2` (3 for commercial)
              // is a single column at mobile width, so these stack in the
              // portal's own source order.
              _headline(provider),
              const SizedBox(height: 16),

              if (provider.category == PropertyCategory.land) ...[
                _landType(provider),
                const SizedBox(height: 16),
              ] else if (provider.category == PropertyCategory.residential) ...[
                _residentialSubType(provider),
                const SizedBox(height: 16),
              ] else if (provider.category == PropertyCategory.commercial) ...[
                _commercialSubType(provider),
                const SizedBox(height: 16),
                _furnishingType(provider),
                const SizedBox(height: 16),
              ] else if (provider.category == PropertyCategory.pg) ...[
                ..._pgFields(provider),
              ],
              // 'others' adds nothing between Headline and Description.

              _descriptionBlock(provider),

              // LocationDetails carries `mt-4` in the portal.
              const SizedBox(height: 16),
              _locationDetails(),

              // space-y-3 between the category block and the project tag.
              const SizedBox(height: 12),
              _projectTag(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Headline ────────────────────────────────────────────────────────────

  Widget _headline(PostPropertyProvider p) {
    final placeholder = switch (p.category) {
      PropertyCategory.land => 'e.g., 2 Acre Agricultural Land in Green Valley',
      PropertyCategory.commercial =>
        'e.g., Premium Office Space in Business District',
      PropertyCategory.pg => 'e.g., Luxury Boys PG near University',
      _ => 'e.g., Modern 3BHK Apartment in Downtown',
    };

    return PortalField(
      label: 'Property Headline',
      required: true,
      child: PortalTextField(
        controller: _title,
        hint: placeholder,
        prefix: const PortalIconTint('type', color: PortalTheme.iconBlue),
        onChanged: (v) => _p.setTitle(v),
      ),
    );
  }

  // ── Description ─────────────────────────────────────────────────────────

  Widget _descriptionBlock(PostPropertyProvider p) {
    final placeholder = switch (p.category) {
      PropertyCategory.land =>
        'Describe the land - soil type, water availability, road connectivity, nearby facilities...',
      PropertyCategory.commercial =>
        'Describe the commercial space - floor area, parking, facilities, foot traffic...',
      PropertyCategory.residential =>
        'Describe the residential space - floor area, parking, facilities, foot traffic...',
      PropertyCategory.pg =>
        'Describe the PG/Co-living space - environment, nearby facilities, special amenities...',
      PropertyCategory.other =>
        'Describe the other property - floor area, parking, facilities, foot traffic...',
      null => '',
    };

    return PortalField(
      label: 'Property Description',
      required: true,
      child: PortalTextField(
        controller: _description,
        hint: placeholder,
        maxLines: 2, // rows={2}
        prefix: const PortalIconTint('align-left', color: PortalTheme.iconPrimary),
        onChanged: (v) => _p.setDescription(v),
      ),
    );
  }

  // ── Land ────────────────────────────────────────────────────────────────

  Widget _landType(PostPropertyProvider p) {
    final subtype = p.text('landSubtype');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PortalLabelledSelect(
          label: 'Subtype',
          required: true,
          icon: 'layers',
          iconColor: PortalTheme.iconPrimary, // was text-orange-500
          value: subtype,
          placeholder: 'Select subtype',
          options: kLandSubtypes,
          onChanged: (v) {
            // The portal clears landType whenever the subtype changes.
            _p.setText('landSubtype', v);
            _p.setText('landType', '');
          },
        ),
        if (subtype == 'land') ...[
          const SizedBox(height: 8), // mt-2
          PortalField(
            label: 'Land Use Type',
            required: true,
            child: PortalSelect(
              value: p.text('landType'),
              placeholder: 'Select Land Use Type',
              options: kLandTypeOptions,
              onChanged: (v) => _p.setText('landType', v),
            ),
          ),
        ],
        if (subtype == 'plot') ...[
          const SizedBox(height: 8),
          PortalField(
            label: 'Plot Type',
            required: true,
            child: PortalSelect(
              value: p.text('landType'),
              placeholder: 'Select Plot Type',
              options: kPlotTypeOptions,
              onChanged: (v) => _p.setText('landType', v),
            ),
          ),
        ],
      ],
    );
  }

  // ── Residential ─────────────────────────────────────────────────────────

  Widget _residentialSubType(PostPropertyProvider p) => PortalLabelledSelect(
        label: 'Property Type',
        required: true,
        icon: 'home',
        iconColor: PortalTheme.iconGreen, // text-green-500
        value: p.residentialSubType,
        placeholder: 'Select property type',
        groups: [
          for (final g in kResidentialSubTypeGroups) (g.label, g.options),
        ],
        onChanged: (v) => _p.setResidentialSubType(v),
      );

  // ── Commercial ──────────────────────────────────────────────────────────

  /// Verbatim from the inline array in `CommercialSubType`.
  static const List<String> _commercialSubTypes = [
    'Office Space',
    'Shop',
    'Showroom',
    'Co-working Space',
    'Warehouse',
    'Godown',
    'Factory',
    'Industrial Shed',
    'Business Center',
    'Retail Space',
    'Food Court Space',
    'Hotel',
    'Restaurant Space',
    'Commercial Building',
  ];

  Widget _commercialSubType(PostPropertyProvider p) => PortalLabelledSelect(
        label: 'Commercial Property Type',
        required: true,
        icon: 'building-2',
        iconColor: PortalTheme.iconIndigo, // text-indigo-500
        value: p.text('commercialSubType'),
        placeholder: 'Select property type',
        options: _commercialSubTypes,
        onChanged: (v) {
          // The portal writes BOTH keys from this one select.
          _p.setText('commercialSubType', v);
          _p.setText('commercialType', v);
        },
      );

  Widget _furnishingType(PostPropertyProvider p) => PortalLabelledSelect(
        label: 'Furnishing Type',
        required: true,
        icon: 'home',
        iconColor: PortalTheme.success, // text-emerald-500
        value: p.furnishingType,
        placeholder: 'Select furnishing type',
        options: const ['Raw', 'Semi-Furnished', 'Fully-Furnished'],
        onChanged: (v) => _p.setFurnishingType(v),
      );

  // ── PG ──────────────────────────────────────────────────────────────────

  List<Widget> _pgFields(PostPropertyProvider p) => [
        PortalLabelledSelect(
          label: 'Property Type',
          required: true,
          icon: 'bed-double',
          iconColor: PortalTheme.iconRed, // text-pink-500
          value: p.text('pgPropertyType'),
          placeholder: 'Select property type',
          options: kPgPropertyTypes,
          onChanged: (v) => _p.setText('pgPropertyType', v),
        ),
        const SizedBox(height: 16),
        PortalLabelledSelect(
          label: 'Building Type',
          required: true,
          icon: 'building',
          iconColor: PortalTheme.iconTeal, // text-teal-500
          value: p.text('buildingType'),
          placeholder: 'Select building type',
          options: kBuildingTypeOptions,
          onChanged: (v) => _p.setText('buildingType', v),
        ),
        const SizedBox(height: 16),
        PortalField(
          label: 'PG / Property Name',
          required: true,
          child: PortalTextField(
            controller: _pgPropertyName,
            hint: 'e.g., Zolo Stays, Stanza Living...',
            onChanged: (v) => _p.setText('pgPropertyName', v),
          ),
        ),
        const SizedBox(height: 16),
        PortalLabelledSelect(
          label: 'Property Status',
          required: true,
          icon: 'circle-dot',
          iconColor: PortalTheme.iconTeal, // text-cyan-500
          value: p.text('propertyStatus'),
          placeholder: 'Select status',
          options: const ['Available', 'Occupied', 'Immediate Move-In'],
          onChanged: (v) => _p.setText('propertyStatus', v),
        ),
        const SizedBox(height: 16),
      ];

  // ── Location Details ────────────────────────────────────────────────────

  Widget _locationDetails() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PortalSectionDivider(
            icon: 'map-pin',
            title: 'Location Details',
            iconBg: PortalTheme.accentSurface, // bg-blue-100
            iconColor: PortalTheme.iconBlue, // text-blue-600
          ),
          // The portal renders a Google Maps picker in the left third of this
          // grid. Omitted — the app has no map implementation. The section,
          // its heading, position and spacing are unchanged, and no field
          // below is reordered because of the omission.
          PortalField(
            label: 'Property Address',
            required: true,
            child: PortalTextField(
              controller: _address,
              hint:
                  'Type to search property address (Google Maps auto-complete)...',
              onChanged: (v) => _p.setLocation(v),
            ),
          ),
          const SizedBox(height: 16),
          PortalLabelledField(
            label: 'City',
            required: true,
            icon: 'map',
            iconColor: PortalTheme.success, // text-emerald-500
            child: PortalTextField(
              controller: _city,
              hint: 'Type city name',
              onChanged: (v) => _p.setCity(v),
            ),
          ),
          const SizedBox(height: 16),
          PortalLabelledField(
            label: 'State',
            required: true,
            icon: 'globe',
            iconColor: PortalTheme.iconBlue, // text-blue-500
            child: PortalTextField(
              controller: _stateField,
              hint: 'State',
              onChanged: (v) => _p.setState(v),
            ),
          ),
          const SizedBox(height: 16),
          PortalLabelledField(
            label: 'Pincode',
            required: true,
            icon: 'hash',
            iconColor: PortalTheme.iconMuted, // text-slate-500
            child: PortalTextField(
              controller: _pincode,
              hint: 'Pincode',
              keyboardType: TextInputType.number,
              onChanged: (v) => _p.setPincode(v),
            ),
          ),
          const SizedBox(height: 16),
          PortalLabelledField(
            label: 'Landmark',
            required: true,
            icon: 'landmark',
            iconColor: PortalTheme.iconRed, // text-rose-500
            child: PortalTextField(
              controller: _landmark,
              hint: 'Famous landmark nearby',
              onChanged: (v) => _p.setLandmark(v),
            ),
          ),
        ],
      );

  // ── Builder Project tag ─────────────────────────────────────────────────

  Widget _projectTag() => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PortalSectionDivider(
            icon: 'building-2',
            title: 'Builder Project (Optional)',
          ),
          ProjectTagSelector(),
        ],
      );
}
