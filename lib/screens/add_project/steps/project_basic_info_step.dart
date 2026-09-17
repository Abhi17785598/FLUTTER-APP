// screens/add_project/steps/project_basic_info_step.dart
//
// Step 1 of 5 — `renderStep1` in `BuilderProjectWizard.tsx`.
//
// Four required fields: title, project type, city, description. Labels,
// placeholders and order are the reference's; the widgets are the app's existing
// `portal_kit`, so this step is indistinguishable from a Post Property step.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/project_options.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/add_project_provider.dart';
import '../../../services/geocoding_service.dart';
import '../../../widgets/address_autocomplete_field.dart';
import '../../../widgets/location_picker_map.dart';
import '../../post_property/portal_kit.dart';
import '../../post_property/portal_theme.dart';
import '../project_field_keys.dart';

class ProjectBasicInfoStep extends StatefulWidget {
  const ProjectBasicInfoStep({super.key});

  @override
  State<ProjectBasicInfoStep> createState() => _ProjectBasicInfoStepState();
}

class _ProjectBasicInfoStepState extends State<ProjectBasicInfoStep> {
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _addressLine1;
  late final TextEditingController _stateField;
  late final TextEditingController _pincode;
  late final TextEditingController _landmark;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    // Seeded once from the provider so a restored draft, or an edit, opens
    // pre-filled. The provider stays the source of truth from here on.
    final draft = context.read<AddProjectProvider>().draft;
    _title = TextEditingController(text: draft.title);
    _location = TextEditingController(text: draft.location);
    _addressLine1 = TextEditingController(text: draft.addressLine1);
    _stateField = TextEditingController(text: draft.state);
    _pincode = TextEditingController(text: draft.pincode);
    _landmark = TextEditingController(text: draft.landmark);
    _description = TextEditingController(text: draft.description);
    // Keeps the provider in sync with every keystroke, not only with a
    // picked suggestion — `AddressAutocompleteField` has no `onChanged` of
    // its own, so free typing (e.g. a city Places doesn't suggest) must
    // still reach `provider.setLocation` the same way it did through the
    // plain text field this replaced.
    _location.addListener(_syncLocationToProvider);
  }

  @override
  void dispose() {
    _location.removeListener(_syncLocationToProvider);
    for (final c in [
      _title,
      _location,
      _addressLine1,
      _stateField,
      _pincode,
      _landmark,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncLocationToProvider() {
    context.read<AddProjectProvider>().setLocation(_location.text);
  }

  /// Fills every location field a resolved place carries — the map pin and
  /// the City search both feed this. Each field keeps its existing value when
  /// the geocode result doesn't resolve it (same "keep the existing value"
  /// rule the Post Property step's `_onLocationSelected` follows), and the
  /// coordinates are only forwarded once a pin has actually been dropped.
  void _applyGeocodedLocation(
    double? lat,
    double? lng,
    GeocodedAddress? address,
  ) {
    final city = address?.city?.trim() ?? '';
    final line1 = address?.addressLine1?.trim() ?? '';
    final state = address?.state?.trim() ?? '';
    final pincode = address?.pincode?.trim() ?? '';
    final landmark = address?.landmark?.trim() ?? '';

    setState(() {
      if (city.isNotEmpty) _location.text = city;
      if (line1.isNotEmpty) _addressLine1.text = line1;
      if (state.isNotEmpty) _stateField.text = state;
      if (pincode.isNotEmpty) _pincode.text = pincode;
      if (landmark.isNotEmpty) _landmark.text = landmark;
    });

    final provider = context.read<AddProjectProvider>();
    provider.setLocation(_location.text);
    provider.setAddressLine1(_addressLine1.text);
    provider.setState(_stateField.text);
    provider.setPincode(_pincode.text);
    provider.setLandmark(_landmark.text);
    if (lat != null && lng != null) {
      provider.setLatitude(lat);
      provider.setLongitude(lng);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AddProjectProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalStepHeader(
          icon: 'building',
          title: 'Basic Info',
          subtitle: 'Tell buyers what this project is and where it is',
        ),
        const SizedBox(height: 20),

        if (provider.stepIssues.isNotEmpty) ...[
          PortalValidationSummary(
            messages: provider.stepIssues
                .map((issue) => issue.message)
                .toList(),
          ),
          const SizedBox(height: 16),
        ],

        PortalCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PortalLabelledField(
                label: 'Project Title',
                required: true,
                icon: 'building',
                child: PortalTextField(
                  controller: _title,
                  hint: 'e.g. Green Valley Heights',
                  hasError: provider.hasIssue(kProjectTitle),
                  onChanged: provider.setTitle,
                ),
              ),
              const SizedBox(height: 16),

              PortalLabelledSelect(
                label: 'Project Type',
                required: true,
                icon: 'layers',
                value: provider.draft.projectType.isEmpty
                    ? null
                    : provider.draft.projectType,
                placeholder: 'Select project type',
                options: kProjectTypes.map((o) => o.value).toList(),
                onChanged: provider.setProjectType,
              ),
              const SizedBox(height: 16),

              // Project address, ahead of City — the reference's order
              // (`BuilderProjectWizard.tsx`'s Location Details block renders
              // Project Address first, then City/State/Pincode/Landmark).
              // Auto-filled by the map picker below, same as every other
              // field in this block, but freely editable on top of that.
              PortalLabelledField(
                label: 'Project Address',
                icon: 'map-pin',
                child: PortalTextField(
                  controller: _addressLine1,
                  hint: 'Street address, plot number, etc.',
                  onChanged: provider.setAddressLine1,
                ),
              ),
              const SizedBox(height: 16),

              // The reference labels this field "City", though the column is
              // `location` — kept, because the validation summary says "City".
              PortalLabelledField(
                label: 'City',
                required: true,
                icon: 'map-pin',
                helper:
                    'Tap the map or search an address to auto-fill the city, '
                    'address, state, pincode and landmark.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocationPickerMap(
                      onLocationSelected: _applyGeocodedLocation,
                    ),
                    const SizedBox(height: 10),
                    AddressAutocompleteField(
                      controller: _location,
                      maxLines: 1,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: PortalTheme.cardSurface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        hintText: 'e.g. Pune',
                        hintStyle: PortalTheme.inputText.copyWith(
                          color: AppColors.textHint,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: provider.hasIssue(kProjectLocation)
                                ? PortalTheme.fieldError
                                : PortalTheme.cardBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(
                            color: provider.hasIssue(kProjectLocation)
                                ? PortalTheme.fieldError
                                : PortalTheme.cardBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                      onPlaceSelected: (address, lat, lng) =>
                          _applyGeocodedLocation(lat, lng, address),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // State, Pincode and Landmark, in the reference's order,
              // auto-filled by the same map picker above.
              PortalLabelledField(
                label: 'State',
                icon: 'globe',
                child: PortalTextField(
                  controller: _stateField,
                  hint: 'State',
                  onChanged: provider.setState,
                ),
              ),
              const SizedBox(height: 16),

              PortalLabelledField(
                label: 'Pincode',
                icon: 'hash',
                child: PortalTextField(
                  controller: _pincode,
                  hint: 'Pincode',
                  keyboardType: TextInputType.number,
                  onChanged: provider.setPincode,
                ),
              ),
              const SizedBox(height: 16),

              PortalLabelledField(
                label: 'Landmark',
                icon: 'landmark',
                child: PortalTextField(
                  controller: _landmark,
                  hint: 'Famous landmark nearby',
                  onChanged: provider.setLandmark,
                ),
              ),
              const SizedBox(height: 16),

              PortalLabelledField(
                label: 'Description',
                required: true,
                icon: 'file-text',
                helper:
                    'Describe the project, its location advantages and what '
                    'makes it worth a visit.',
                child: PortalTextField(
                  controller: _description,
                  hint: 'Tell buyers about this project…',
                  maxLines: 5,
                  hasError: provider.hasIssue(kProjectDescription),
                  onChanged: provider.setDescription,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Maps a stored `project_type` to its label for [PortalSelect].
///
/// Declared here rather than inline so the select and the review step read the
/// same way.
String projectTypeOptionLabel(String value) => projectTypeLabel(value);
