// core/constants/project_options.dart
//
// The builder project vocabularies. Every value here is a database value, not a
// label — the labels are what the user reads and are never stored.
//
// NOTHING IN THIS FILE MAY BE INVENTED
// -----------------------------------
// [kProjectTypes] is simultaneously the `project_type` CHECK constraint
// (`20250905144708_cc6b51bd…sql:7`) and the portal's `PROJECT_TYPES`
// (`BuilderProjectWizard.tsx:56-65`) — the two agree, and a value absent from
// either is rejected by Postgres with a `23514`. [kProjectStatuses] is the
// `status` CHECK from the same line 9. [kCommonAmenities] is
// `COMMON_AMENITIES` (`:67-72`) — suggestions only; `amenities` is a free `text[]`
// and the wizard lets the user add their own.
import 'package:flutter/foundation.dart';

/// One selectable value: what is stored, and what is shown.
@immutable
class ProjectOption {
  const ProjectOption(this.value, this.label);

  /// The database value.
  final String value;

  /// The label rendered to the user.
  final String label;
}

/// `project_type` — the CHECK constraint's eight values, in the portal's order.
const List<ProjectOption> kProjectTypes = [
  ProjectOption('plotted_development', 'Plotted Development'),
  ProjectOption('group_housing', 'Group Housing'),
  ProjectOption('integrated_township', 'Integrated Township'),
  ProjectOption('gated_community_plots_villas', 'Gated Community with Plots/Villas'),
  ProjectOption('farm_houses', 'Farm Houses'),
  ProjectOption('service_apartment', 'Service Apartments'),
  ProjectOption('commercial_spaces', 'Commercial Spaces'),
  ProjectOption('office_spaces', 'Office Spaces'),
];

/// `status` — the CHECK constraint's four values. `active` is the column default
/// and the only one the public read policy exposes
/// (`USING (status = 'active')`), so a project moved off `active` disappears from
/// every public surface.
const List<ProjectOption> kProjectStatuses = [
  ProjectOption('active', 'Active'),
  ProjectOption('under_construction', 'Under Construction'),
  ProjectOption('completed', 'Completed'),
  ProjectOption('inactive', 'Inactive'),
];

/// The 19 amenity suggestions, verbatim and in the portal's order.
const List<String> kCommonAmenities = [
  'Swimming Pool',
  'Gymnasium',
  'Clubhouse',
  'Children Play Area',
  'Landscaped Gardens',
  'Security',
  '24/7 Power Backup',
  'Parking',
  'Elevator',
  'Sports Complex',
  'Community Hall',
  'Jogging Track',
  'Senior Citizen Park',
  'Library',
  'Shopping Complex',
  'School',
  'Hospital',
  'ATM',
  'Restaurant',
];

/// The label for a stored `project_type`, or the raw value when unrecognised.
///
/// Falls back rather than throwing: a value written by a future portal migration
/// should still render on a card instead of taking the screen down.
String projectTypeLabel(String? value) {
  if (value == null || value.isEmpty) return '';
  for (final option in kProjectTypes) {
    if (option.value == value) return option.label;
  }
  return value.replaceAll('_', ' ');
}

/// The label for a stored `status`, or the raw value when unrecognised.
String projectStatusLabel(String? value) {
  if (value == null || value.isEmpty) return '';
  for (final option in kProjectStatuses) {
    if (option.value == value) return option.label;
  }
  return value.replaceAll('_', ' ');
}

/// True when [value] is a legal `project_type`.
///
/// Used by the review step before submit, so an impossible value is caught here
/// rather than as a `23514` from Postgres.
bool isValidProjectType(String? value) =>
    kProjectTypes.any((option) => option.value == value);

/// True when [value] is a legal `status`.
bool isValidProjectStatus(String? value) =>
    kProjectStatuses.any((option) => option.value == value);
