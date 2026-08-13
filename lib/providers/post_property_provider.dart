import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/tagged_project.dart';
import '../screens/post_property/listing_validation_rules.dart';
import '../screens/post_property/listing_validators.dart';
import '../screens/post_property/listing_value_aliases.dart';
import '../services/property_service.dart';

/// `metadata.pgHouseRules` sub-key -> the provider flag it hydrates into.
/// Mirrors PropertyService's write-side map; the names differ on each side of
/// the colon, so neither direction is derivable from the other.
const Map<String, String> _kPgHouseRuleSources = {
  'visitorEntry': 'pgVisitorEntry',
  'nonVegFood': 'pgNonVegFood',
  'oppositeGender': 'pgOppositeGender',
  'smoking': 'pgSmoking',
  'drinking': 'pgDrinking',
  'loudMusic': 'pgLoudMusic',
  'party': 'pgParty',
};

enum PropertyCategory { residential, commercial, land, pg, other }

enum ListingIntent { sell, rent, lease }

/// A locally-selected media file with its display category. No upload is
/// performed anywhere in this provider — files stay local until a backend
/// integration phase wires up Supabase Storage.
class MediaItem {
  final XFile file;
  final String category;

  const MediaItem({required this.file, required this.category});
}

/// A photo already stored against the listing, paired with its category.
///
/// React models this as `existingMediaUrls: { url, category }[]` and rebuilds
/// it on edit by zipping `media_urls` against `metadata.mediaCategories` by
/// index (PropertyWizard.tsx:1287). Flutter previously kept only the URLs, so
/// every existing photo's category was lost the moment a listing was edited.
class MediaRef {
  final String url;
  final String category;

  const MediaRef({required this.url, required this.category});

  MediaRef copyWith({String? category}) =>
      MediaRef(url: url, category: category ?? this.category);

  @override
  bool operator ==(Object other) =>
      other is MediaRef && other.url == url && other.category == category;

  @override
  int get hashCode => Object.hash(url, category);
}

/// Wizard state for the "Post Property" flow.
///
/// Implements the full 9-step frontend flow (type selection, basic info,
/// dimensions, condition, amenities, legal, pricing, media & contact, review)
/// across all 5 property categories (Residential, Commercial, Land, PG,
/// Other), per the field set / validation rules / conditional logic of the
/// React PropertyWizard (source of truth). No media upload, no Supabase
/// writes, no submission — those remain for a later backend-integration pass.
///
/// The ~50 shared/residential fields are typed properties (as built in
/// earlier sprints). The much larger set of category-specific long-tail
/// fields (Commercial/Land/PG only, ~100 fields, mostly simple text/bool/list
/// toggles with no extra behavior) are stored in typed bags keyed by the same
/// field name used in the React source — this keeps them traceable 1:1 back
/// to the source of truth without ~100 near-duplicate getter/setter pairs.
class PostPropertyProvider extends ChangeNotifier {
  /// Steps visible for the current category. React rebuilds this array on every
  /// render from `propertyType` (PropertyWizard.tsx:1350); Flutter derives it
  /// the same way, so land shows 6 steps + Review and residential 7 + Review
  /// instead of a fixed nine.
  List<WizardStep> get visibleSteps => visibleStepsFor(_category);

  /// Number of steps in the current flow. No longer a constant: it changes with
  /// the category, which is the whole point of T3.
  int get totalSteps => visibleSteps.length;

  /// The step the user is currently on, resolved through [visibleSteps].
  WizardStep get currentWizardStep {
    final steps = visibleSteps;
    final int i = _currentStep.clamp(0, steps.length - 1);
    return steps[i];
  }

  int _currentStep = 0;
  bool _isSubmitting = false;

  // ── Step 1: Type Selection ────────────────────────────────────────────
  PropertyCategory? _category;
  ListingIntent? _listingIntent;

  // ── Step 2: Basic Info (shared) ───────────────────────────────────────
  String _title = '';
  String _description = '';
  String _location = '';
  double? _latitude;
  double? _longitude;
  String _city = '';
  String _state = '';
  String _pincode = '';
  String _landmark = '';
  String _price = '';
  DateTime? _availableFrom;

  // React keeps one string in `formData.availableFrom`: '' until answered, then
  // either the literal 'Immediately' or a yyyy-MM-dd date. A `DateTime?` cannot
  // tell "Immediately" apart from "not answered yet", so the Immediately case
  // gets its own flag. Both null and false means unanswered, which is what the
  // `availableFrom` listing rule tests.
  bool _availableImmediately = false;
  String? _residentialSubType;

  // ── Step 3: Dimensions (shared/residential) ───────────────────────────
  String _area = '';
  String _areaUnit = 'sq_ft';
  String _carpetArea = '';
  String? _bhkType;
  String _bedrooms = '';
  String _bathrooms = '';
  String _balconies = '';
  String _floorNo = '';
  String _totalFloors = '';

  // ── Step 4: Condition (shared) ────────────────────────────────────────
  String? _propertyCondition;
  String? _constructionAge;
  String? _availabilityStatus;
  String? _furnishingType;
  List<String> _availableItems = [];

  // ── Step 5: Amenities (shared/residential) ────────────────────────────
  String? _electricityBackup;
  String? _waterAvailability;
  String _coveredParking = '';
  String _openParking = '';
  String _numberOfLifts = '';
  bool _gasPipeline = false;
  bool _internetAvailability = false;
  bool _solarPower = false;
  bool _guardRoom = false;

  // ── Step 6: Legal (shared) ────────────────────────────────────────────
  bool _reraRegistered = false;
  String _reraNumber = '';
  bool _saleDeed = false;
  bool _registryCopy = false;
  bool _nocAvailable = false;
  bool _encumbranceFree = false;
  bool _loanApproved = false;
  bool _propertyApproved = false;
  String? _facing;
  List<String> _approvedByBanks = [];

  // ── Step 7: Pricing (shared) ──────────────────────────────────────────
  String _ratePerArea = '';
  String _securityDeposit = '';
  String _maintenanceCharges = '';
  String _bookingAmount = '';
  String? _lockInPeriod;
  bool _priceNegotiable = false;
  bool _allInclusivePriceToggle = false;
  bool _taxGovtChargesIncluded = false;
  bool _loanAvailability = false;
  String _brokerage = '';

  // ── Commercial building inventory (nested object) ─────────────────────
  //
  // React models this as one nested `formData.buildingInventory` object and
  // spreads into it on every edit. Phase 0 deliberately left nested objects
  // out of the `_text`/`_bool`/`_list` bag — they have no slot there — and
  // deferred real editing support to this phase.
  //
  // Stored whole rather than flattened so that sub-keys Flutter has no input
  // for (the floor-wise and company-wise blocks, and ~30 optional facility
  // flags) survive a round-trip untouched instead of being dropped the first
  // time a web-created listing is edited in the app.
  Map<String, dynamic> _buildingInventory = {};

  // Lists of objects skipped by hydration (see _hydrateBagFromMetadata), kept
  // so read-only derived displays have something to read. Never written back —
  // the update-time metadata merge is what preserves them.
  final Map<String, List<dynamic>> _preservedLists = {};

  // ── PG floor-wise room details (list of objects) ───────────────────────
  //
  // metadata.floorWiseRoomDetails is `{floorNumber, totalRooms, rooms:
  // [{roomNumber, roomType}]}[]` (PropertyWizard.tsx). Lists of objects are
  // excluded from the generic bag (see _hydrateBagFromMetadata) and land in
  // _preservedLists instead; this is a mutable copy of that entry, built in
  // initFromRawData, that the PG dimensions step actually edits. It is
  // written explicitly by PropertyService for PG listings only — every other
  // category keeps relying on the metadata merge, so nothing else changes.
  List<Map<String, dynamic>> _floorWiseRoomDetails = [];

  // ── Builder project tag (optional, any category) ──────────────────────
  String _projectId = '';
  String _projectName = '';
  String _projectLocation = '';
  String _builderName = '';

  // ── Edit mode ─────────────────────────────────────────────────────────
  String? _editingPropertyId;
  List<MediaRef> _existingMedia = [];
  String _mainDisplayMediaUrl = '';

  // ── Step 8: Media & Contact ───────────────────────────────────────────
  final List<MediaItem> _mediaItems = [];
  String _contactName = '';
  String _contactPhone = '';
  String _contactEmail = '';
  String _whatsappNumber = '';
  String _bestTimeToCall = '';
  String _hashtags = '';

  // ── Category-specific long-tail fields (Commercial/Land/PG/Other) ─────
  final Map<String, String> _text = {};
  final Map<String, bool> _bool = {};
  final Map<String, List<String>> _list = {};

  String text(String key) => _text[key] ?? '';

  void setText(String key, String value) {
    _text[key] = value;
    notifyListeners();
  }

  bool boolVal(String key) => _bool[key] ?? false;

  void setBoolVal(String key, bool value) {
    _bool[key] = value;
    notifyListeners();
  }

  List<String> listVal(String key) => _list[key] ?? const [];

  void setListVal(String key, List<String> value) {
    _list[key] = value;
    notifyListeners();
  }

  /// Read-only views of the category-specific bags, for the Review screen's
  /// generic summary rendering.
  Map<String, String> get allTextFields => Map.unmodifiable(_text);
  Map<String, bool> get allBoolFields => Map.unmodifiable(_bool);
  Map<String, List<String>> get allListFields => Map.unmodifiable(_list);

  // ── Getters ────────────────────────────────────────────────────────────
  int get currentStep => _currentStep;
  bool get isSubmitting => _isSubmitting;
  bool get isEditMode => _editingPropertyId != null;
  /// Existing photos with their categories, in `media_urls` order.
  List<MediaRef> get existingMedia => List.unmodifiable(_existingMedia);

  /// URLs only, in order — what the `media_urls` column is rebuilt from.
  List<String> get existingMediaUrls =>
      List.unmodifiable(_existingMedia.map((m) => m.url));

  /// The photo the user starred as the listing's main image. Empty means
  /// "use the first", matching React's
  /// `dbText(mainDisplayMediaUrl, allMediaUrls[0] ?? '')`.
  String get mainDisplayMediaUrl => _mainDisplayMediaUrl;
  PropertyCategory? get category => _category;
  ListingIntent? get listingIntent => _listingIntent;

  String get title => _title;
  String get description => _description;
  String get location => _location;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  String get city => _city;
  String get state => _state;
  String get pincode => _pincode;
  String get landmark => _landmark;
  String get price => _price;
  DateTime? get availableFrom => _availableFrom;

  /// True when the listing is available now — React's
  /// `formData.availableFrom === 'Immediately'`.
  bool get availableImmediately => _availableImmediately;

  /// The single string React stores, so validation and the write path agree:
  /// '' unanswered, else 'Immediately' or `yyyy-MM-dd`.
  String get availableFromValue {
    if (_availableImmediately) return 'Immediately';
    final DateTime? d = _availableFrom;
    if (d == null) return '';
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String? get residentialSubType => _residentialSubType;

  String get area => _area;
  String get areaUnit => _areaUnit;
  String get carpetArea => _carpetArea;
  String? get bhkType => _bhkType;
  String get bedrooms => _bedrooms;
  String get bathrooms => _bathrooms;
  String get balconies => _balconies;
  String get floorNo => _floorNo;
  String get totalFloors => _totalFloors;

  String? get propertyCondition => _propertyCondition;
  String? get constructionAge => _constructionAge;
  String? get availabilityStatus => _availabilityStatus;
  String? get furnishingType => _furnishingType;
  List<String> get availableItems => _availableItems;

  String? get electricityBackup => _electricityBackup;
  String? get waterAvailability => _waterAvailability;
  String get coveredParking => _coveredParking;
  String get openParking => _openParking;
  String get numberOfLifts => _numberOfLifts;
  bool get gasPipeline => _gasPipeline;
  bool get internetAvailability => _internetAvailability;
  bool get solarPower => _solarPower;
  bool get guardRoom => _guardRoom;

  bool get reraRegistered => _reraRegistered;
  String get reraNumber => _reraNumber;
  bool get saleDeed => _saleDeed;
  bool get registryCopy => _registryCopy;
  bool get nocAvailable => _nocAvailable;
  bool get encumbranceFree => _encumbranceFree;
  bool get loanApproved => _loanApproved;
  bool get propertyApproved => _propertyApproved;
  String? get facing => _facing;
  List<String> get approvedByBanks => _approvedByBanks;

  String get ratePerArea => _ratePerArea;
  String get securityDeposit => _securityDeposit;
  String get maintenanceCharges => _maintenanceCharges;
  String get bookingAmount => _bookingAmount;
  String? get lockInPeriod => _lockInPeriod;
  bool get priceNegotiable => _priceNegotiable;
  bool get allInclusivePriceToggle => _allInclusivePriceToggle;
  bool get taxGovtChargesIncluded => _taxGovtChargesIncluded;
  bool get loanAvailability => _loanAvailability;
  String get brokerage => _brokerage;

  /// The whole nested object, including sub-keys the app never edits.
  Map<String, dynamic> get buildingInventory =>
      Map.unmodifiable(_buildingInventory);

  /// A single building-inventory value, or null when unset.
  Object? buildingInventoryValue(String key) => _buildingInventory[key];

  /// PG "Total Rooms" — the portal derives it as
  /// `floorWiseRoomDetails.reduce((s, f) => s + (f.totalRooms || 0), 0)`.
  int get totalRoomsAcrossFloors {
    var sum = 0;
    for (final f in _floorWiseRoomDetails) {
      final n = f['totalRooms'];
      if (n is num) sum += n.toInt();
    }
    return sum;
  }

  /// PG per-floor room details, one entry per floor number 1..totalFloors.
  List<Map<String, dynamic>> get floorWiseRoomDetails =>
      _floorWiseRoomDetails.map((f) => Map<String, dynamic>.unmodifiable(f)).toList();

  Map<String, dynamic>? _floorEntry(int floorNumber) {
    for (final f in _floorWiseRoomDetails) {
      if (f['floorNumber'] == floorNumber) return f;
    }
    return null;
  }

  /// Room details for one floor, or `null` if that floor has no entry yet.
  Map<String, dynamic>? floorRoomDetails(int floorNumber) => _floorEntry(floorNumber);

  /// Sets a floor's total room count, mirroring the portal's
  /// `handleFloorRoomsChange`: the `rooms[]` array is regenerated to match
  /// the new count, keeping each existing room's type by room number and
  /// defaulting freshly added rooms to 'Single Sharing'.
  void setFloorTotalRooms(int floorNumber, int totalRooms) {
    final clamped = totalRooms < 0 ? 0 : totalRooms;
    var entry = _floorEntry(floorNumber);
    final List<dynamic> existingRooms =
        (entry?['rooms'] as List?) ?? const [];
    final rooms = List<Map<String, dynamic>>.generate(clamped, (i) {
      final roomNumber = i + 1;
      final existing = existingRooms.firstWhere(
        (r) => r is Map && r['roomNumber'] == roomNumber,
        orElse: () => null,
      );
      return {
        'roomNumber': roomNumber,
        'roomType': (existing is Map ? existing['roomType'] : null) ??
            'Single Sharing',
      };
    });

    if (entry == null) {
      entry = {'floorNumber': floorNumber, 'totalRooms': clamped, 'rooms': rooms};
      _floorWiseRoomDetails = [..._floorWiseRoomDetails, entry]
        ..sort((a, b) => (a['floorNumber'] as int).compareTo(b['floorNumber'] as int));
    } else {
      entry['totalRooms'] = clamped;
      entry['rooms'] = rooms;
    }
    notifyListeners();
  }

  /// Sets a single room's type on a given floor, mirroring the portal's
  /// `handleRoomTypeChange`.
  void setFloorRoomType(int floorNumber, int roomNumber, String roomType) {
    final entry = _floorEntry(floorNumber);
    if (entry == null) return;
    final rooms = (entry['rooms'] as List).cast<Map<String, dynamic>>();
    for (final r in rooms) {
      if (r['roomNumber'] == roomNumber) {
        r['roomType'] = roomType;
        break;
      }
    }
    notifyListeners();
  }

  /// Reads a building-inventory value as text, for form fields.
  String buildingInventoryText(String key) =>
      _buildingInventory[key]?.toString() ?? '';

  // ── Commercial floor-wise inventory (buildingInventory.floors[]) ──────
  //
  // Mirrors the portal's `BuildingFloorInventory` component
  // (PropertyDimensionsStep.tsx:852-956). Stored inside `_buildingInventory`
  // itself — not a separate field — so `_buildMetadata`'s existing
  // `{...provider.buildingInventory}` spread picks up floor edits with no
  // extra write path, the same way sub-keys the app never edits already
  // survive there.
  List<Map<String, dynamic>> get buildingFloors => (_buildingInventory['floors']
          as List?)
      ?.whereType<Map>()
      .map((f) => Map<String, dynamic>.from(f))
      .toList() ??
      const [];

  Map<String, dynamic>? buildingFloorEntry(int floorNumber) {
    for (final f in buildingFloors) {
      if (f['floorNumber'] == floorNumber) return f;
    }
    return null;
  }

  /// Default shape of one office, verbatim from the portal's
  /// `handleNumberOfCompaniesChange` — every key an empty string so a newly
  /// added office matches what a web-created listing's company object looks
  /// like before it is filled in.
  static Map<String, dynamic> _blankOffice() => {
        'companyName': '',
        'companyType': '',
        'industryCategory': '',
        'officeNumber': '',
        'registrationNumber': '',
        'gstNumber': '',
        'website': '',
        'email': '',
        'phoneNumber': '',
        'contactPerson': '',
        'designation': '',
        'occupiedArea': '',
        'leaseStartDate': '',
        'leaseEndDate': '',
        'monthlyRent': '',
        'securityDeposit': '',
        'lockInPeriod': '',
        'numberOfEmployees': '',
        'seatingCapacity': '',
      };

  void _writeBuildingFloors(List<Map<String, dynamic>> floors) {
    _buildingInventory = {..._buildingInventory, 'floors': floors};
    notifyListeners();
  }

  /// Sets one field on a floor's own data (not an office within it) —
  /// mirrors `handleFloorChange`. Creates the floor entry on first write.
  void setBuildingFloorField(int floorNumber, String field, Object? value) {
    final floors = buildingFloors;
    final i = floors.indexWhere((f) => f['floorNumber'] == floorNumber);
    if (i >= 0) {
      floors[i] = {...floors[i], field: value};
    } else {
      floors.add({'floorNumber': floorNumber, field: value, 'companies': []});
    }
    _writeBuildingFloors(floors);
  }

  /// Sets a floor's office count, mirroring `handleNumberOfCompaniesChange`:
  /// regenerates `companies[]` to the new length, keeping existing offices by
  /// index and defaulting new ones to [_blankOffice].
  void setBuildingNumberOfCompanies(int floorNumber, int numCompanies) {
    final clamped = numCompanies < 0 ? 0 : numCompanies;
    final floors = buildingFloors;
    final i = floors.indexWhere((f) => f['floorNumber'] == floorNumber);
    final existingCompanies =
        (i >= 0 ? floors[i]['companies'] as List? : null) ?? const [];
    final companies = List<Map<String, dynamic>>.generate(clamped, (idx) {
      if (idx < existingCompanies.length) {
        final c = existingCompanies[idx];
        return c is Map ? Map<String, dynamic>.from(c) : _blankOffice();
      }
      return _blankOffice();
    });

    if (i >= 0) {
      floors[i] = {
        ...floors[i],
        'numberOfCompanies': '$clamped',
        'companies': companies,
      };
    } else {
      floors.add({
        'floorNumber': floorNumber,
        'numberOfCompanies': '$clamped',
        'companies': companies,
      });
    }
    _writeBuildingFloors(floors);
  }

  /// Sets one field on a single office, mirroring `handleOfficeChange`. Only
  /// the field named is touched, so every other key already on that office
  /// (from a web-created listing, or from fields this editor doesn't expose)
  /// survives untouched.
  void setBuildingOfficeField(
      int floorNumber, int companyIndex, String field, Object? value) {
    final floors = buildingFloors;
    final i = floors.indexWhere((f) => f['floorNumber'] == floorNumber);
    if (i < 0) return;
    final companies =
        ((floors[i]['companies'] as List?) ?? const [])
            .map((c) => c is Map ? Map<String, dynamic>.from(c) : _blankOffice())
            .toList();
    if (companyIndex < 0 || companyIndex >= companies.length) return;
    companies[companyIndex] = {...companies[companyIndex], field: value};
    floors[i] = {...floors[i], 'companies': companies};
    _writeBuildingFloors(floors);
  }

  String get projectId => _projectId;
  String get projectName => _projectName;
  String get projectLocation => _projectLocation;
  String get builderName => _builderName;
  bool get hasProjectTag => _projectId.isNotEmpty;

  List<MediaItem> get mediaItems => List.unmodifiable(_mediaItems);
  String get contactName => _contactName;
  String get contactPhone => _contactPhone;
  String get contactEmail => _contactEmail;
  String get whatsappNumber => _whatsappNumber;
  String get bestTimeToCall => _bestTimeToCall;
  String get hashtags => _hashtags;

  // ── Validity ───────────────────────────────────────────────────────────
  //
  // T2: step gating is now driven by the ported rule table
  // (listing_validation_rules.dart), a direct translation of React's
  // propertyListingRules.ts, rather than the hand-written getters that used to
  // live here — two of which (`isStep5Valid`, `isStep6Valid`) returned `true`
  // unconditionally, so Amenities and Legal were never validated at all.

  /// Fields that were already blank when an existing listing was loaded for
  /// edit. T2 tightens validation considerably, so without this a user editing
  /// a listing created before the new rules existed could be unable to save it
  /// — and unable to fix it, since the missing value may predate the input.
  /// (final-architecture-review Q14 item 4.)
  ///
  /// Empty for new listings, so creation is validated in full.
  final Set<String> _grandfatheredBlankFields = {};

  Set<String> get grandfatheredBlankFields =>
      Set.unmodifiable(_grandfatheredBlankFields);

  /// Every unmet requirement on [step], an index into [visibleSteps].
  ///
  /// Steps hidden for the current category are not in that list at all, so
  /// their rules cannot block the user — matching React, where a hidden step's
  /// rule set is never reached by `validateAllPropertySteps`.
  List<ListingIssue> issuesForStep(int step) {
    final steps = visibleSteps;
    if (step < 0 || step >= steps.length) return const <ListingIssue>[];
    final String? key = ruleKeyForStep(steps[step]);
    if (key == null) return const <ListingIssue>[];
    return validatePropertyStep(
      key,
      ListingFormData(this),
      grandfathered: _grandfatheredBlankFields,
    );
  }

  /// The first unmet requirement on [step], or null when the step is complete.
  /// Drives the inline error the wizard shows next to a blocked Continue.
  ListingIssue? firstIssueForStep(int step) {
    final issues = issuesForStep(step);
    return issues.isEmpty ? null : issues.first;
  }

  bool isStepValid(int step) => issuesForStep(step).isEmpty;

  /// Every unmet requirement across all steps, keyed by step index — used by
  /// the review step and by submit to jump the user back to the first problem.
  Map<int, List<ListingIssue>> get allStepIssues {
    final result = <int, List<ListingIssue>>{};
    for (int i = 0; i < visibleSteps.length; i++) {
      final issues = issuesForStep(i);
      if (issues.isNotEmpty) result[i] = issues;
    }
    return result;
  }

  /// First step index with an unmet requirement, or null when all steps pass.
  int? get firstInvalidStep {
    for (int i = 0; i < visibleSteps.length; i++) {
      if (issuesForStep(i).isNotEmpty) return i;
    }
    return null;
  }

  /// Validity of a step by its identity rather than a positional index —
  /// positions now shift with the category, so index-based helpers would mean
  /// different things for land and commercial.
  bool isWizardStepValid(WizardStep step) {
    final int i = visibleSteps.indexOf(step);
    return i == -1 || isStepValid(i);
  }

  bool get isStep1Valid => isWizardStepValid(WizardStep.category);
  bool get isStep2Valid => isWizardStepValid(WizardStep.basicInfo);
  bool get isStep3Valid => isWizardStepValid(WizardStep.dimensions);
  bool get isStep4Valid => isWizardStepValid(WizardStep.condition);
  bool get isStep5Valid => isWizardStepValid(WizardStep.amenities);
  bool get isStep6Valid => isWizardStepValid(WizardStep.legal);
  bool get isStep7Valid => isWizardStepValid(WizardStep.pricing);
  bool get isStep8Valid => isWizardStepValid(WizardStep.media);
  bool get isStep9Valid => isWizardStepValid(WizardStep.review);

  bool get canGoNext => isStepValid(_currentStep);

  bool get isLastStep => _currentStep == totalSteps - 1;

  // ── Setters: Step 1-2 ──────────────────────────────────────────────────
  void setCategory(PropertyCategory category) {
    _category = category;
    _clampCurrentStep();
    notifyListeners();
  }

  /// Keeps [_currentStep] inside the visible range after the category changes.
  ///
  /// Mirrors React's clamp (PropertyWizard.tsx:1364): "Clamp currentStep if
  /// steps array shrinks (e.g. switching to land+rent removes steps)". Without
  /// it, choosing land while standing on a later step would index past the end
  /// of the shortened list.
  void _clampCurrentStep() {
    final int last = visibleSteps.length - 1;
    if (_currentStep > last) _currentStep = last;
  }

  void setListingIntent(ListingIntent intent) {
    _listingIntent = intent;
    notifyListeners();
  }

  void setTitle(String value) {
    _title = value;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void setLocation(String value) {
    _location = value;
    notifyListeners();
  }

  void setLatitude(double? value) {
    _latitude = value;
    notifyListeners();
  }

  void setLongitude(double? value) {
    _longitude = value;
    notifyListeners();
  }

  void setCity(String value) {
    _city = value;
    notifyListeners();
  }

  void setState(String value) {
    _state = value;
    notifyListeners();
  }

  void setPincode(String value) {
    _pincode = value;
    notifyListeners();
  }

  void setLandmark(String value) {
    _landmark = value;
    notifyListeners();
  }

  void setPrice(String value) {
    _price = value;
    notifyListeners();
  }

  void setAvailableFrom(DateTime? date) {
    _availableFrom = date;
    // Picking a date is the other branch of the same control, so it clears
    // Immediately — React overwrites the one string either way.
    if (date != null) _availableImmediately = false;
    notifyListeners();
  }

  void setAvailableImmediately(bool value) {
    _availableImmediately = value;
    if (value) _availableFrom = null;
    notifyListeners();
  }

  void setResidentialSubType(String value) {
    _residentialSubType = value;
    notifyListeners();
  }

  // ── Setters: Step 3 ────────────────────────────────────────────────────
  void setArea(String value) {
    _area = value;
    notifyListeners();
  }

  void setAreaUnit(String value) {
    _areaUnit = value;
    notifyListeners();
  }

  void setCarpetArea(String value) {
    _carpetArea = value;
    notifyListeners();
  }

  void setBhkType(String value) {
    _bhkType = value;
    notifyListeners();
  }

  void setBedrooms(String value) {
    _bedrooms = value;
    notifyListeners();
  }

  void setBathrooms(String value) {
    _bathrooms = value;
    notifyListeners();
  }

  void setBalconies(String value) {
    _balconies = value;
    notifyListeners();
  }

  void setFloorNo(String value) {
    _floorNo = value;
    notifyListeners();
  }

  void setTotalFloors(String value) {
    _totalFloors = value;
    notifyListeners();
  }

  // ── Setters: Step 4 ────────────────────────────────────────────────────
  void setPropertyCondition(String value) {
    _propertyCondition = value;
    notifyListeners();
  }

  void setConstructionAge(String value) {
    _constructionAge = value;
    notifyListeners();
  }

  void setAvailabilityStatus(String value) {
    _availabilityStatus = value;
    notifyListeners();
  }

  void setFurnishingType(String value) {
    _furnishingType = value;
    notifyListeners();
  }

  void setAvailableItems(List<String> items) {
    _availableItems = items;
    notifyListeners();
  }

  // ── Setters: Step 5 ────────────────────────────────────────────────────
  void setElectricityBackup(String value) {
    _electricityBackup = value;
    notifyListeners();
  }

  void setWaterAvailability(String value) {
    _waterAvailability = value;
    notifyListeners();
  }

  void setCoveredParking(String value) {
    _coveredParking = value;
    notifyListeners();
  }

  void setOpenParking(String value) {
    _openParking = value;
    notifyListeners();
  }

  void setNumberOfLifts(String value) {
    _numberOfLifts = value;
    notifyListeners();
  }

  void setGasPipeline(bool value) {
    _gasPipeline = value;
    notifyListeners();
  }

  void setInternetAvailability(bool value) {
    _internetAvailability = value;
    notifyListeners();
  }

  void setSolarPower(bool value) {
    _solarPower = value;
    notifyListeners();
  }

  void setGuardRoom(bool value) {
    _guardRoom = value;
    notifyListeners();
  }

  // ── Setters: Step 6 ────────────────────────────────────────────────────
  void setReraRegistered(bool value) {
    _reraRegistered = value;
    notifyListeners();
  }

  void setReraNumber(String value) {
    _reraNumber = value;
    notifyListeners();
  }

  void setSaleDeed(bool value) {
    _saleDeed = value;
    notifyListeners();
  }

  void setRegistryCopy(bool value) {
    _registryCopy = value;
    notifyListeners();
  }

  void setNocAvailable(bool value) {
    _nocAvailable = value;
    notifyListeners();
  }

  void setEncumbranceFree(bool value) {
    _encumbranceFree = value;
    notifyListeners();
  }

  void setLoanApproved(bool value) {
    _loanApproved = value;
    notifyListeners();
  }

  void setPropertyApproved(bool value) {
    _propertyApproved = value;
    notifyListeners();
  }

  void setFacing(String value) {
    _facing = value;
    notifyListeners();
  }

  void setApprovedByBanks(List<String> banks) {
    _approvedByBanks = banks;
    notifyListeners();
  }

  // ── Setters: Step 7 ────────────────────────────────────────────────────
  void setRatePerArea(String value) {
    _ratePerArea = value;
    notifyListeners();
  }

  void setSecurityDeposit(String value) {
    _securityDeposit = value;
    notifyListeners();
  }

  void setMaintenanceCharges(String value) {
    _maintenanceCharges = value;
    notifyListeners();
  }

  void setBookingAmount(String value) {
    _bookingAmount = value;
    notifyListeners();
  }

  void setLockInPeriod(String value) {
    _lockInPeriod = value;
    notifyListeners();
  }

  void setPriceNegotiable(bool value) {
    _priceNegotiable = value;
    notifyListeners();
  }

  void setAllInclusivePriceToggle(bool value) {
    _allInclusivePriceToggle = value;
    notifyListeners();
  }

  void setTaxGovtChargesIncluded(bool value) {
    _taxGovtChargesIncluded = value;
    notifyListeners();
  }

  void setLoanAvailability(bool value) {
    _loanAvailability = value;
    notifyListeners();
  }

  void setBrokerage(String value) {
    _brokerage = value;
    notifyListeners();
  }

  // ── Setters: builder project tag ──────────────────────────────────────

  /// Tags this listing to [project], or clears the tag when null.
  ///
  /// Verbatim port of the `onSelect` handler in BasicInfoStep.tsx:676:
  /// selecting copies the project's title / location / builder name / status
  /// onto the form (builder name and status only when the project supplies
  /// one, so a value typed by hand is not wiped); clearing resets only the id
  /// and location, deliberately LEAVING the builder name in place — a broker
  /// who typed "Prestige Group" by hand keeps it after untagging.
  void selectProject(TaggedProject? project) {
    if (project != null) {
      _projectId = project.id;
      _projectName = project.title;
      _projectLocation = project.location;
      final String? name = project.builderName;
      if (name != null && name.isNotEmpty) _builderName = name;
      final String? status = project.status;
      if (status != null && status.isNotEmpty) setText('propertyStatus', status);
    } else {
      _projectId = '';
      _projectLocation = '';
    }
    notifyListeners();
  }

  /// Free-text builder name, for listings with no project in the list.
  /// Sets one building-inventory field, leaving every other sub-key intact —
  /// the Dart equivalent of React's `{ ...formData.buildingInventory, k: v }`.
  void setBuildingInventoryValue(String key, Object? value) {
    _buildingInventory[key] = value;
    notifyListeners();
  }

  void setBuilderName(String value) {
    _builderName = value;
    notifyListeners();
  }

  // ── Setters: Step 8 ────────────────────────────────────────────────────

  /// Stars a photo as the listing's main image.
  ///
  /// Pass an empty string to clear the choice, which makes the first photo the
  /// main one — React's `dbText(mainDisplayMediaUrl, allMediaUrls[0] ?? '')`.
  void setMainDisplayMediaUrl(String url) {
    _mainDisplayMediaUrl = url;
    notifyListeners();
  }

  /// Drops an already-uploaded photo from the listing.
  ///
  /// Clears the star if it pointed at that photo, so a removed image cannot
  /// remain the main display URL.
  void removeExistingMedia(int index) {
    if (index < 0 || index >= _existingMedia.length) return;
    final removed = _existingMedia.removeAt(index);
    if (_mainDisplayMediaUrl == removed.url) _mainDisplayMediaUrl = '';
    notifyListeners();
  }

  /// Re-tags an already-uploaded photo. Categories are persisted positionally
  /// in `metadata.mediaCategories`, so this must not reorder the list.
  void setExistingMediaCategory(int index, String category) {
    if (index < 0 || index >= _existingMedia.length) return;
    _existingMedia[index] = _existingMedia[index].copyWith(category: category);
    notifyListeners();
  }

  void addMediaItem(XFile file, String category) {
    _mediaItems.add(MediaItem(file: file, category: category));
    notifyListeners();
  }

  void removeMediaItem(int index) {
    _mediaItems.removeAt(index);
    notifyListeners();
  }

  void updateMediaCategory(int index, String category) {
    final item = _mediaItems[index];
    _mediaItems[index] = MediaItem(file: item.file, category: category);
    notifyListeners();
  }

  void setContactName(String value) {
    _contactName = value;
    notifyListeners();
  }

  void setContactPhone(String value) {
    _contactPhone = value;
    notifyListeners();
  }

  void setContactEmail(String value) {
    _contactEmail = value;
    notifyListeners();
  }

  void setWhatsappNumber(String value) {
    _whatsappNumber = value;
    notifyListeners();
  }

  void setBestTimeToCall(String value) {
    _bestTimeToCall = value;
    notifyListeners();
  }

  void setHashtags(String value) {
    _hashtags = value;
    notifyListeners();
  }

  // ── Navigation ─────────────────────────────────────────────────────────
  void nextStep() {
    if (canGoNext && _currentStep < totalSteps - 1) {
      _currentStep++;
      notifyListeners();
    }
  }

  void previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      notifyListeners();
    }
  }

  /// Jumps directly to an earlier step (used by the Review screen's "Edit"
  /// links). Does not enforce [canGoNext] since it only ever moves backward
  /// to a step the user has already visited.
  void goToStep(int step) {
    if (step >= 0 && step < totalSteps && step <= _currentStep) {
      _currentStep = step;
      notifyListeners();
    }
  }

  /// Positions the wizard directly, bypassing the [canGoNext] gate.
  ///
  /// Test-only: the real navigation deliberately refuses to skip forward past
  /// an invalid step, which makes "stand on the last step, then shrink the
  /// flow" impossible to set up through the public API.
  @visibleForTesting
  void debugSetCurrentStep(int step) {
    _currentStep = step.clamp(0, totalSteps - 1);
    notifyListeners();
  }

  /// Jumps to a step by identity rather than position.
  ///
  /// Positions shift with the category now that hidden steps are removed
  /// (T3), so the Review screen's "Edit" links must name the step they mean —
  /// a hard-coded 3 is Condition for commercial but Legal for land.
  /// A step not visible for the current category is a no-op.
  void goToWizardStep(WizardStep step) {
    final int i = visibleSteps.indexOf(step);
    if (i != -1) goToStep(i);
  }

  void reset() {
    _currentStep = 0;
    _isSubmitting = false;
    _editingPropertyId = null;
    _existingMedia = [];
    _mainDisplayMediaUrl = '';
    _buildingInventory = {};
    _preservedLists.clear();
    _floorWiseRoomDetails = [];
    _projectId = '';
    _projectName = '';
    _projectLocation = '';
    _builderName = '';
    _category = null;
    _listingIntent = null;
    _title = '';
    _description = '';
    _location = '';
    _latitude = null;
    _longitude = null;
    _city = '';
    _state = '';
    _pincode = '';
    _landmark = '';
    _price = '';
    _availableFrom = null;
    _availableImmediately = false;
    _residentialSubType = null;
    _area = '';
    _areaUnit = 'sq_ft';
    _carpetArea = '';
    _bhkType = null;
    _bedrooms = '';
    _bathrooms = '';
    _balconies = '';
    _floorNo = '';
    _totalFloors = '';
    _propertyCondition = null;
    _constructionAge = null;
    _availabilityStatus = null;
    _furnishingType = null;
    _availableItems = [];
    _electricityBackup = null;
    _waterAvailability = null;
    _coveredParking = '';
    _openParking = '';
    _numberOfLifts = '';
    _gasPipeline = false;
    _internetAvailability = false;
    _solarPower = false;
    _guardRoom = false;
    _reraRegistered = false;
    _reraNumber = '';
    _saleDeed = false;
    _registryCopy = false;
    _nocAvailable = false;
    _encumbranceFree = false;
    _loanApproved = false;
    _propertyApproved = false;
    _facing = null;
    _approvedByBanks = [];
    _ratePerArea = '';
    _securityDeposit = '';
    _maintenanceCharges = '';
    _bookingAmount = '';
    _lockInPeriod = null;
    _priceNegotiable = false;
    _allInclusivePriceToggle = false;
    _taxGovtChargesIncluded = false;
    _loanAvailability = false;
    _brokerage = '';
    _mediaItems.clear();
    _contactName = '';
    _contactPhone = '';
    _contactEmail = '';
    _whatsappNumber = '';
    _bestTimeToCall = '';
    _hashtags = '';
    _text.clear();
    _bool.clear();
    _list.clear();
    notifyListeners();
  }

  /// Submits the wizard. In create mode returns the new property UUID.
  /// In edit mode performs an UPDATE and returns the existing [_editingPropertyId].
  /// Throws a human-readable String on any failure.
  Future<String> submit(PropertyService service, String userId) async {
    _isSubmitting = true;
    notifyListeners();
    try {
      if (isEditMode) {
        await service.updateProperty(_editingPropertyId!, this, userId);
        return _editingPropertyId!;
      }
      return await service.createProperty(this, userId);
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  /// Pre-fills every provider field from raw Supabase rows fetched by
  /// [PropertyService.fetchForEdit]. Calls [reset] first so no stale state
  /// bleeds through, then applies edit-mode overrides.
  void initFromRawData({
    required String editingPropertyId,
    required Map<String, dynamic> propertyRow,
    Map<String, dynamic>? subtableRow,
    Map<String, dynamic>? contactRow,
  }) {
    reset();
    _editingPropertyId = editingPropertyId;

    _category = _parseCategory(propertyRow['category']?.toString());
    _listingIntent = _parseListingIntent(propertyRow['property_type']?.toString());
    _title = propertyRow['title']?.toString() ?? '';
    _description = propertyRow['description']?.toString() ?? '';
    _location = propertyRow['location']?.toString() ?? '';
    _latitude = (propertyRow['latitude'] as num?)?.toDouble();
    _longitude = (propertyRow['longitude'] as num?)?.toDouble();
    _price = propertyRow['price']?.toString() ?? '';
    // properties.rate_per_area is a real column, not metadata — same class of
    // bug as amenities below: the metadata bag flush never sees it, so
    // without this explicit read it silently reset to '' on every edit even
    // though the value was correctly saved on create/update
    // (property_service.dart's insert/update payload).
    _ratePerArea = propertyRow['rate_per_area']?.toString() ?? '';
    // T1: map legacy Flutter enum spellings onto React's canonical values on
    // read, so a row written by an older build still matches the canonical
    // option lists (and, for area unit, still resolves to a DropdownButton
    // item). Unknown values pass through untouched rather than being guessed.
    _areaUnit = canonicalAreaUnit(propertyRow['area_unit']?.toString() ?? 'sq_ft');
    _area = propertyRow['area']?.toString() ?? '';
    final String? rawSubType = propertyRow['residential_subtype']?.toString();
    _residentialSubType =
        rawSubType == null ? null : canonicalResidentialSubtype(rawSubType);

    // The column holds React's string, so 'Immediately' round-trips as the
    // flag rather than as an unparseable date.
    final String? availableFrom = propertyRow['available_from']?.toString();
    if (availableFrom == 'Immediately') {
      _availableImmediately = true;
    } else if (availableFrom != null) {
      _availableFrom = DateTime.tryParse(availableFrom);
    }

    final Map<String, dynamic> meta =
        (propertyRow['metadata'] as Map<String, dynamic>?) ?? {};

    // Rebuild existing photos by zipping media_urls against
    // metadata.mediaCategories BY INDEX, defaulting to 'other' — a verbatim
    // port of PropertyWizard.tsx:1287. The two arrays are parallel, so a photo
    // keeps the category it was uploaded under across an edit.
    final mediaUrls = propertyRow['media_urls'];
    final mediaCategories = meta['mediaCategories'];
    if (mediaUrls is List) {
      final cats = mediaCategories is List ? mediaCategories : const [];
      _existingMedia = [
        for (int i = 0; i < mediaUrls.length; i++)
          MediaRef(
            url: mediaUrls[i].toString(),
            category: i < cats.length && cats[i] != null &&
                    cats[i].toString().isNotEmpty
                ? cats[i].toString()
                : 'other',
          ),
      ];
    }

    _mainDisplayMediaUrl =
        propertyRow['main_display_media_url']?.toString() ?? '';

    // properties.amenities is a real column, not metadata, so the bag flush
    // never sees it — hydrate it explicitly or every edit would clear the
    // listing's amenities.
    final amenitiesCol = propertyRow['amenities'];
    if (amenitiesCol is List && amenitiesCol.isNotEmpty) {
      _list['amenities'] =
          amenitiesCol.where((e) => e != null).map((e) => e.toString()).toList();
    }

    // properties.hashtags is likewise a real column outside metadata — same
    // fix as amenities/rate_per_area above. The column stores bare words
    // (PropertyService._parseHashtags strips the '#' before writing); the
    // field editor expects the '#'-prefixed, space-joined form, mirroring
    // PropertyWizard.tsx:1272's `hashtags.map(h => '#'+h).join(' ')`.
    final hashtagsCol = propertyRow['hashtags'];
    if (hashtagsCol is List && hashtagsCol.isNotEmpty) {
      _hashtags = hashtagsCol
          .where((e) => e != null && e.toString().isNotEmpty)
          .map((e) => '#$e')
          .join(' ');
    }

    // Builder project tag. React reads the column first and falls back to the
    // metadata snapshot (PropertyWizard.tsx:954) — project_id is the source of
    // truth for the link, the metadata copy exists so cards can render the
    // project without a join.
    _projectId = propertyRow['project_id']?.toString() ??
        meta['projectId']?.toString() ??
        '';
    _projectName = meta['projectName']?.toString() ?? '';
    _projectLocation = meta['projectLocation']?.toString() ?? '';
    _builderName = meta['builderName']?.toString() ?? '';

    _city = meta['city']?.toString() ?? '';
    _state = meta['state']?.toString() ?? '';
    _pincode = meta['pincode']?.toString() ?? '';
    _landmark = meta['landmark']?.toString() ?? '';
    _propertyCondition = meta['propertyCondition']?.toString();
    _constructionAge = meta['constructionAge']?.toString();
    _availabilityStatus = meta['availabilityStatus']?.toString();
    final availItems = meta['availableItems'];
    if (availItems is List) _availableItems = List<String>.from(availItems);
    _electricityBackup = meta['electricityBackup']?.toString();
    _waterAvailability = meta['waterAvailability']?.toString();
    _numberOfLifts = meta['numberOfLifts']?.toString() ?? '';
    _openParking = meta['openParking']?.toString() ?? '';
    _gasPipeline = meta['gasPipeline'] as bool? ?? false;
    _internetAvailability = meta['internetAvailability'] as bool? ?? false;
    _solarPower = meta['solarPower'] as bool? ?? false;
    _guardRoom = meta['guardRoom'] as bool? ?? false;
    _reraRegistered = meta['reraRegistered'] as bool? ?? false;
    _reraNumber = meta['reraNumber']?.toString() ?? '';
    _saleDeed = meta['saleDeed'] as bool? ?? false;
    _registryCopy = meta['registryCopy'] as bool? ?? false;
    _nocAvailable = meta['nocAvailable'] as bool? ?? false;
    _encumbranceFree = meta['encumbranceFree'] as bool? ?? false;
    _loanApproved = meta['loanApproved'] as bool? ?? false;
    _propertyApproved = meta['propertyApproved'] as bool? ?? false;
    _facing = meta['facing']?.toString();
    final banks = meta['approvedByBanks'];
    if (banks is List) _approvedByBanks = List<String>.from(banks);
    _securityDeposit = meta['securityDeposit']?.toString() ?? '';
    // Canonical React key first, then the legacy key Flutter used to write, so
    // listings created by older app builds keep their value on edit.
    _maintenanceCharges =
        (meta['maintenanceCharges'] ?? meta['maintenanceAmount'])?.toString() ??
            '';
    _bookingAmount = meta['tokenAmount']?.toString() ?? '';
    _lockInPeriod = meta['lockInPeriod']?.toString();
    _priceNegotiable = meta['priceNegotiable'] as bool? ?? false;
    _allInclusivePriceToggle =
        (meta['allInclusivePriceToggle'] ?? meta['allInclusivePrice'])
                as bool? ??
            false;
    _taxGovtChargesIncluded = meta['taxGovtChargesIncluded'] as bool? ?? false;
    _loanAvailability = meta['loanAvailability'] as bool? ?? false;
    _brokerage = meta['brokerage']?.toString() ?? '';
    _contactName = meta['contactName']?.toString() ?? '';
    _whatsappNumber = meta['whatsappNumber']?.toString() ?? '';
    _bestTimeToCall = meta['bestTimeToCall']?.toString() ?? '';
    _bhkType = meta['bhkType']?.toString();

    // metadata.pgHouseRules is a nested object, so _hydrateBagFromMetadata
    // deliberately skips it (Phase 0). React reads its seven flags back into
    // individual form fields (PropertyWizard.tsx:1265) and rebuilds the object
    // from them on save — so without this, editing a PG listing would rewrite
    // every house rule as false.
    final houseRules = meta['pgHouseRules'];
    if (houseRules is Map) {
      _kPgHouseRuleSources.forEach((subKey, flagKey) {
        _bool[flagKey] = houseRules[subKey] == true;
      });
    }

    // Preserve the entire stored object, not just the keys the app edits.
    final inv = meta['buildingInventory'];
    if (inv is Map) {
      _buildingInventory = Map<String, dynamic>.from(inv);
    }

    _hydrateBagFromMetadata(meta);

    // floorWiseRoomDetails is a list of objects, so the bag routed it into
    // _preservedLists above; copy it into mutable editor state so the PG
    // dimensions step can actually edit it without disturbing that raw
    // snapshot (still the thing the update-time merge falls back on for
    // any sub-shape this editor does not touch).
    final rawFloors = _preservedLists['floorWiseRoomDetails'];
    if (rawFloors != null) {
      _floorWiseRoomDetails = rawFloors
          .whereType<Map>()
          .map((f) => Map<String, dynamic>.from(f))
          .toList();
    }

    if (subtableRow != null) {
      final String? cat = propertyRow['category']?.toString();
      if (cat == 'residential' || cat == 'pg_coliving') {
        _bedrooms = subtableRow['bedrooms']?.toString() ?? '';
        _bathrooms = subtableRow['bathrooms']?.toString() ?? '';
        _carpetArea = subtableRow['carpet_area_sqft']?.toString() ?? '';
        _balconies = subtableRow['balconies']?.toString() ?? '';
        final bool furnished = subtableRow['furnished'] as bool? ?? false;
        _furnishingType = furnished ? 'Furnished' : 'Unfurnished';
        _coveredParking = subtableRow['parking_spaces']?.toString() ?? '';
        _floorNo = subtableRow['floor_number']?.toString() ?? '';
        _totalFloors = subtableRow['total_floors']?.toString() ?? '';
        final String? facingDir = subtableRow['facing_direction']?.toString();
        if (facingDir != null && facingDir.isNotEmpty) _facing = facingDir;
      } else if (cat == 'commercial') {
        _carpetArea = subtableRow['carpet_area_sqft']?.toString() ?? '';
        final bool furnished = subtableRow['furnished'] as bool? ?? false;
        _furnishingType = furnished ? 'Furnished' : 'Unfurnished';
        setText('washrooms', subtableRow['washrooms']?.toString() ?? '');
        setText('totalParking', subtableRow['parking_spaces']?.toString() ?? '');
        setText('floorNumber', subtableRow['floor_number']?.toString() ?? '');
        setText('totalFloorsCommercial', subtableRow['total_floors']?.toString() ?? '');
        final bool cafeteria = subtableRow['cafeteria'] as bool? ?? false;
        _guardRoom = cafeteria;
      } else if (cat == 'land') {
        setText('soilType', subtableRow['soil_type']?.toString() ?? '');
      }
    }

    if (contactRow != null) {
      _contactPhone = contactRow['contact_phone']?.toString() ?? '';
      _contactEmail = contactRow['contact_email']?.toString() ?? '';
    }

    _snapshotGrandfatheredFields();

    notifyListeners();
  }

  /// Records which rule fields are blank right after an existing listing loads.
  ///
  /// T2's rule table is much stricter than the getters it replaced, so a
  /// listing created under the old rules can legitimately be missing values the
  /// new rules demand. Blocking the user from re-saving it — possibly to fix
  /// something unrelated — would be a regression, and for fields whose input
  /// does not exist yet it would be unfixable. So a field that was already
  /// blank on load is exempt for the rest of this edit session; the moment the
  /// user fills it, the rule applies normally, and it is always enforced for
  /// newly created listings.
  void _snapshotGrandfatheredFields() {
    _grandfatheredBlankFields.clear();
    final data = ListingFormData(this);
    for (final rules in kPropertyStepRules.values) {
      for (final rule in rules) {
        final Object? value =
            rule.get != null ? rule.get!(data) : data.read(rule.field);
        if (isBlank(value)) _grandfatheredBlankFields.add(rule.field);
      }
    }
  }

  /// Metadata keys already owned by a named provider field above. They are
  /// deliberately excluded from the bag so one value can never be represented
  /// twice with two sources of truth.
  ///
  /// Both spellings of the two corrected keys are listed: the canonical React
  /// name and the legacy name older app builds wrote. The legacy value is
  /// still readable via the fallback in [initFromRawData], and still survives
  /// in the stored blob via the merge in `PropertyService.updateProperty` —
  /// it just must not also leak into the bag.
  static const Set<String> _namedMetadataKeys = {
    'city', 'state', 'pincode', 'landmark',
    'propertyCondition', 'constructionAge', 'availabilityStatus',
    'availableItems',
    'electricityBackup', 'waterAvailability', 'numberOfLifts', 'openParking',
    'gasPipeline', 'internetAvailability', 'solarPower', 'guardRoom',
    'reraRegistered', 'reraNumber',
    'saleDeed', 'registryCopy', 'nocAvailable', 'encumbranceFree',
    'loanApproved', 'propertyApproved',
    'facing', 'approvedByBanks',
    'securityDeposit',
    'maintenanceCharges', 'maintenanceAmount', // canonical + legacy
    'tokenAmount',
    'lockInPeriod', 'priceNegotiable',
    'allInclusivePriceToggle', 'allInclusivePrice', // canonical + legacy
    'taxGovtChargesIncluded', 'loanAvailability', 'brokerage',
    'contactName', 'whatsappNumber', 'bestTimeToCall',
    'bhkType',
    // Written by _buildMetadata from typed state, never user-edited via the bag.
    'isPg', 'mediaCategories',
  };

  /// Routes every metadata key that no named field owns back into the
  /// `_text` / `_bool` / `_list` bags, so edit mode no longer drops them.
  ///
  /// Previously this never happened: hydration read ~39 named keys and left
  /// the bag empty, while the write path flushed the bag into a fresh blob
  /// that replaced the column outright. Any key the form did not collect —
  /// the whole PG block, land legal flags, commercial detail — was destroyed
  /// on the first in-app edit of a web-created listing.
  ///
  /// Nested objects (`Map`) are intentionally skipped. The bag has no map
  /// slot and Phase 0 does not change its API; `buildingInventory` and
  /// friends survive untouched through the metadata merge on update instead,
  /// and gain real editing support in the category parity phases.
  ///
  /// Lists are only hydrated when every element is a scalar. `_list` is typed
  /// `List<String>`, so a list of objects — React persists
  /// `floorWiseRoomDetails` as `{floor, rooms{...}}[]` — would be flattened to
  /// its `toString()` form and written back as mangled strings. Such lists take
  /// the same route as nested maps: left out of the bag, preserved verbatim by
  /// the update-time merge.
  void _hydrateBagFromMetadata(Map<String, dynamic> meta) {
    meta.forEach((key, value) {
      if (value == null || _namedMetadataKeys.contains(key)) return;

      if (value is bool) {
        _bool[key] = value;
      } else if (value is List) {
        if (value.any((e) => e is Map || e is List)) {
          _preservedLists[key] = value;
          return;
        }
        _list[key] = value
            .where((e) => e != null)
            .map((e) => e.toString())
            .toList();
      } else if (value is Map) {
        // Preserved by the update-time merge, not hydrated. See doc above.
        return;
      } else {
        _text[key] = value.toString();
      }
    });
  }

  static PropertyCategory? _parseCategory(String? dbValue) => switch (dbValue) {
    'residential' => PropertyCategory.residential,
    'commercial' => PropertyCategory.commercial,
    'land' => PropertyCategory.land,
    'pg_coliving' => PropertyCategory.pg,
    // 'others' is the canonical property_category enum member React writes.
    // 'other' was never valid in the DB enum, but it is accepted here so that
    // if any row somehow carries it the wizard still opens rather than
    // silently losing the category.
    'others' => PropertyCategory.other,
    'other' => PropertyCategory.other,
    _ => null,
  };

  static ListingIntent? _parseListingIntent(String? dbValue) => switch (dbValue) {
    'sell' => ListingIntent.sell,
    'rent' => ListingIntent.rent,
    'lease' => ListingIntent.lease,
    _ => null,
  };
}
