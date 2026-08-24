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
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    // Seeded once from the provider so a restored draft, or an edit, opens
    // pre-filled. The provider stays the source of truth from here on.
    final draft = context.read<AddProjectProvider>().draft;
    _title = TextEditingController(text: draft.title);
    _location = TextEditingController(text: draft.location);
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
    for (final c in [_title, _location, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncLocationToProvider() {
    context.read<AddProjectProvider>().setLocation(_location.text);
  }

  /// Fills the City field from a resolved place — the map pin and the
  /// address search both feed this, matching the "typing an address suggests
  /// the city" behaviour, since this step only collects a city, not a full
  /// address. Falls back to leaving the field untouched when the geocode
  /// result carries no city (same "keep the existing value" rule the Post
  /// Property step follows).
  void _applyGeocodedCity(GeocodedAddress? address) {
    final city = address?.city?.trim() ?? '';
    if (city.isEmpty) return;
    _location.text = city;
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

              // The reference labels this field "City", though the column is
              // `location` — kept, because the validation summary says "City".
              PortalLabelledField(
                label: 'City',
                required: true,
                icon: 'map-pin',
                helper:
                    'Tap the map or search an address to auto-fill the city.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocationPickerMap(
                      onLocationSelected: (lat, lng, address) =>
                          _applyGeocodedCity(address),
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
                          _applyGeocodedCity(address),
                    ),
                  ],
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
