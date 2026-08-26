// screens/add_project/project_validation_rules.dart
//
// The builder project wizard's required-field rules.
//
// A direct port of `propcid/src/lib/validation/projectRules.ts`, including its
// step keys, its labels and its cross-field unit check. The reference's own
// header explains why it is this strict: before those rules existed, "401 of 401
// project rows had NULL latitude/longitude and most had NULL numeric ranges".
//
// The engine is NOT re-implemented. `isBlank`, `positiveNumber`,
// `nonNegativeNumber` and `validPhone` in
// `screens/post_property/listing_validators.dart` are already character-for-
// character ports of the same `requiredFields.ts` that `projectRules.ts` imports,
// and `ListingIssue` is already the `FieldIssue` shape. Reusing them is what keeps
// the two wizards gating identically on the same input.
import '../post_property/listing_validation_rules.dart'
    show ListingIssue, RuleValidator;
import '../post_property/listing_validators.dart';
import '../../services/project_service.dart';
import 'project_field_keys.dart';

/// Reads one field off a draft. The equivalent of the reference indexing a flat
/// `ProjectFormShape`.
typedef ProjectFieldReader = Object? Function(ProjectDraft draft);

/// One required-field declaration. Mirrors `FieldRule<ProjectFormShape>`.
class ProjectRule {
  const ProjectRule({
    required this.field,
    required this.label,
    required this.get,
    this.validate,
  });

  /// Field key — also the identity the step body uses to highlight an input.
  final String field;

  /// Human label shown in the error summary.
  final String label;

  /// Reads the value from the draft.
  final ProjectFieldReader get;

  /// Extra format check, run only when the value is present.
  final RuleValidator? validate;
}

/// The wizard's five steps, in order. `STEPS` in
/// `BuilderProjectWizard.tsx:251-257`.
enum ProjectStep { basic, details, media, amenities, review }

/// `STEPS[i].key` — the string the reference keys its rule table by.
String projectStepKey(ProjectStep step) => switch (step) {
  ProjectStep.basic => 'basic',
  ProjectStep.details => 'details',
  ProjectStep.media => 'media',
  ProjectStep.amenities => 'amenities',
  ProjectStep.review => 'review',
};

/// `STEPS[i].title`.
String projectStepTitle(ProjectStep step) => switch (step) {
  ProjectStep.basic => 'Basic Info',
  ProjectStep.details => 'Project Details',
  ProjectStep.media => 'Contact & Media',
  ProjectStep.amenities => 'Amenities',
  ProjectStep.review => 'Review & Submit',
};

/// The lucide glyph per step, from the reference's `icon` on each `STEPS` entry:
/// Building, MapPin, Phone, Sparkles, ShieldCheck.
String projectStepIcon(ProjectStep step) => switch (step) {
  ProjectStep.basic => 'building',
  ProjectStep.details => 'map-pin',
  ProjectStep.media => 'phone',
  ProjectStep.amenities => 'sparkles',
  ProjectStep.review => 'shield-check',
};

/// `basicRules` — projectRules.ts:44-49.
final List<ProjectRule> _basicRules = [
  ProjectRule(field: kProjectTitle, label: 'Project title', get: _readTitle),
  ProjectRule(field: kProjectType, label: 'Project type', get: _readType),
  // The reference labels `location` "City", not "Location".
  ProjectRule(field: kProjectLocation, label: 'City', get: _readLocation),
  ProjectRule(
    field: kProjectDescription,
    label: 'Description',
    get: _readDescription,
    // Not part of the React port — added on explicit request so a listing
    // can't ship with a single-word description.
    validate: minWordCount(20, 'Description'),
  ),
];

/// `detailRules` — projectRules.ts:51-61.
final List<ProjectRule> _detailRules = [
  ProjectRule(
    field: kProjectTotalUnits,
    label: 'Total units',
    get: _readTotalUnits,
    validate: positiveNumber('Total units'),
  ),
  // Non-negative, not positive: a sold-out project has 0 available.
  ProjectRule(
    field: kProjectAvailableUnits,
    label: 'Available units',
    get: _readAvailableUnits,
    validate: nonNegativeNumber('Available units'),
  ),
  ProjectRule(
    field: kProjectPriceMin,
    label: 'Price range (min)',
    get: _readPriceMin,
    validate: positiveNumber('Price range (min)'),
  ),
  ProjectRule(
    field: kProjectPriceMax,
    label: 'Price range (max)',
    get: _readPriceMax,
    validate: positiveNumber('Price range (max)'),
  ),
  ProjectRule(
    field: kProjectAreaMin,
    label: 'Area (min)',
    get: _readAreaMin,
    // Not part of the React port — added on explicit request so a minimum
    // area can't be listed at a couple of square feet.
    validate: minNumber(100, 'Area (min)'),
  ),
  ProjectRule(
    field: kProjectAreaMax,
    label: 'Area (max)',
    get: _readAreaMax,
    validate: positiveNumber('Area (max)'),
  ),
  const ProjectRule(
    field: kProjectCompletionDate,
    label: 'Completion date',
    get: _readCompletionDate,
  ),
  const ProjectRule(
    field: kProjectPossessionDate,
    label: 'Possession date',
    get: _readPossessionDate,
  ),
  const ProjectRule(
    field: kProjectReraNumber,
    label: 'RERA number',
    get: _readRera,
    validate: validRera,
  ),
];

/// `mediaRules` — projectRules.ts:63-71.
///
/// Every one of these is required, including the brochure PDF and at least one
/// video. That is the reference's rule, kept as decision D5.
final List<ProjectRule> _mediaRules = [
  const ProjectRule(
    field: kProjectWebsiteUrl,
    label: 'Website URL',
    get: _readWebsite,
  ),
  ProjectRule(
    field: kProjectContactNumber,
    label: 'Contact number',
    get: _readContact,
    validate: validPhone,
  ),
  const ProjectRule(
    field: kProjectLogoUrl,
    label: 'Project logo',
    get: _readLogo,
  ),
  // The reference names `map_images` "Master plan layout".
  const ProjectRule(
    field: kProjectMapImages,
    label: 'Master plan layout',
    get: _readMapImages,
  ),
  const ProjectRule(
    field: kProjectBrochureUrl,
    label: 'Project brochure (PDF)',
    get: _readBrochure,
  ),
  const ProjectRule(
    field: kProjectOtherImages,
    label: 'Project images',
    get: _readOtherImages,
  ),
  const ProjectRule(
    field: kProjectVideosUrls,
    label: 'Project videos',
    get: _readVideos,
  ),
];

/// `amenityRules` — projectRules.ts:73.
const List<ProjectRule> _amenityRules = [
  ProjectRule(
    field: kProjectAmenities,
    label: 'At least one amenity',
    get: _readAmenities,
  ),
];

/// `PROJECT_STEP_RULES` — projectRules.ts:76-82. Review has no rules of its own;
/// it re-runs every earlier step.
Map<ProjectStep, List<ProjectRule>> get projectStepRules => {
  ProjectStep.basic: _basicRules,
  ProjectStep.details: _detailRules,
  ProjectStep.media: _mediaRules,
  ProjectStep.amenities: _amenityRules,
  ProjectStep.review: const [],
};

/// Cross-field checks on the Details step that no single [ProjectRule] can
/// express, since each needs two fields at once. Both are only evaluated once
/// their inputs are present — an incomplete pair is already caught by the
/// per-field required checks above.
///
/// - "You cannot have more units available than exist" was previously only
///   checked in [validateAllProjectSteps], so leaving the Details step with
///   Available > Total was silently accepted until the final submit. Folding
///   it into [validateProjectStep] means it now blocks Continue immediately,
///   same as every other Details field.
/// - Possession before Completion is a new check, not part of the React
///   port, added on explicit request.
List<ListingIssue> _crossFieldDetailIssues(ProjectDraft draft) {
  final issues = <ListingIssue>[];

  final total = draft.totalUnits;
  final available = draft.availableUnits;
  if (total != null && available != null && available > total) {
    issues.add(
      const ListingIssue(
        kProjectAvailableUnits,
        'Available units',
        'Available units cannot exceed total units.',
      ),
    );
  }

  final completion = DateTime.tryParse(draft.completionDate);
  final possession = DateTime.tryParse(draft.possessionDate);
  if (completion != null &&
      possession != null &&
      possession.isBefore(completion)) {
    issues.add(
      const ListingIssue(
        kProjectPossessionDate,
        'Possession date',
        'Possession date cannot be earlier than the completion date.',
      ),
    );
  }

  return issues;
}

/// Unmet requirements for one step. `validateProjectStep` — projectRules.ts:84.
///
/// A rule fires when the value [isBlank]; a present value is then handed to
/// [ProjectRule.validate] if it has one. Same order as `collectIssues`, plus
/// [_crossFieldDetailIssues] on the Details step.
List<ListingIssue> validateProjectStep(ProjectStep step, ProjectDraft draft) {
  final issues = <ListingIssue>[];

  for (final rule in projectStepRules[step] ?? const <ProjectRule>[]) {
    final value = rule.get(draft);

    if (isBlank(value)) {
      issues.add(
        ListingIssue(rule.field, rule.label, '${rule.label} is required.'),
      );
      continue;
    }

    final message = rule.validate?.call(value);
    if (message != null) {
      issues.add(ListingIssue(rule.field, rule.label, message));
    }
  }

  if (step == ProjectStep.details) {
    issues.addAll(_crossFieldDetailIssues(draft));
  }

  return issues;
}

/// The first step that fails, or null when the whole form is valid.
///
/// `validateAllProjectSteps` — projectRules.ts:87-107. The cross-field checks
/// are folded into [validateProjectStep] itself now, so this loop alone is
/// enough to surface them.
ProjectValidationFailure? validateAllProjectSteps(ProjectDraft draft) {
  const order = ProjectStep.values;

  for (var i = 0; i < order.length; i++) {
    final issues = validateProjectStep(order[i], draft);
    if (issues.isNotEmpty) {
      return ProjectValidationFailure(
        step: order[i],
        stepIndex: i,
        issues: issues,
      );
    }
  }

  return null;
}

/// Which step failed, where it sits, and why.
class ProjectValidationFailure {
  const ProjectValidationFailure({
    required this.step,
    required this.stepIndex,
    required this.issues,
  });

  final ProjectStep step;
  final int stepIndex;
  final List<ListingIssue> issues;
}

// ── Field readers ─────────────────────────────────────────────────────────
//
// Top-level functions rather than closures so the rule tables can stay `const`
// where nothing else in them is computed.

Object? _readTitle(ProjectDraft d) => d.title;
Object? _readType(ProjectDraft d) => d.projectType;
Object? _readLocation(ProjectDraft d) => d.location;
Object? _readDescription(ProjectDraft d) => d.description;
Object? _readTotalUnits(ProjectDraft d) => d.totalUnits;
Object? _readAvailableUnits(ProjectDraft d) => d.availableUnits;
Object? _readPriceMin(ProjectDraft d) => d.priceRangeMin;
Object? _readPriceMax(ProjectDraft d) => d.priceRangeMax;
Object? _readAreaMin(ProjectDraft d) => d.areaSqftMin;
Object? _readAreaMax(ProjectDraft d) => d.areaSqftMax;
Object? _readCompletionDate(ProjectDraft d) => d.completionDate;
Object? _readPossessionDate(ProjectDraft d) => d.possessionDate;
Object? _readRera(ProjectDraft d) => d.reraNumber;
Object? _readWebsite(ProjectDraft d) => d.websiteUrl;
Object? _readContact(ProjectDraft d) => d.contactNumber;
Object? _readLogo(ProjectDraft d) => d.logoUrl;
Object? _readMapImages(ProjectDraft d) => d.mapImages;
Object? _readBrochure(ProjectDraft d) => d.brochureUrl;
Object? _readOtherImages(ProjectDraft d) => d.otherImages;
Object? _readVideos(ProjectDraft d) => d.videosUrls;
Object? _readAmenities(ProjectDraft d) => d.amenities;
