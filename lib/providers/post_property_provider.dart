import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/validation/validators.dart';
import '../services/property_service.dart';

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
  static const int totalSteps = 9;

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

  // ── Edit mode ─────────────────────────────────────────────────────────
  String? _editingPropertyId;
  List<String> _existingMediaUrls = [];

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
  List<String> get existingMediaUrls => List.unmodifiable(_existingMediaUrls);
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

  List<MediaItem> get mediaItems => List.unmodifiable(_mediaItems);
  String get contactName => _contactName;
  String get contactPhone => _contactPhone;
  String get contactEmail => _contactEmail;
  String get whatsappNumber => _whatsappNumber;
  String get bestTimeToCall => _bestTimeToCall;
  String get hashtags => _hashtags;

  // ── Validity (mirrors the React source's required-field markers) ──────
  bool get isStep1Valid => _category != null && _listingIntent != null;

  bool get isStep2Valid {
    final hasCore = _title.trim().isNotEmpty &&
        _location.trim().isNotEmpty &&
        _city.trim().isNotEmpty;
    if (!hasCore) return false;
    // PG pricing is captured on Step 7; other categories require price here.
    final hasPrice = _category == PropertyCategory.pg || Validators.requiredPositiveNumber(_price) == null;
    if (!hasPrice) return false;
    // Enforce category-specific subtype fields marked * in the UI.
    switch (_category) {
      case PropertyCategory.residential:
        return _residentialSubType != null;
      case PropertyCategory.commercial:
        return (_text['commercialSubType'] ?? '').isNotEmpty;
      case PropertyCategory.pg:
        return (_text['pgPropertyType'] ?? '').isNotEmpty &&
            (_text['buildingType'] ?? '').isNotEmpty &&
            (_text['pgPropertyName'] ?? '').isNotEmpty &&
            (_text['propertyStatus'] ?? '').isNotEmpty;
      default:
        return true;
    }
  }

  bool get isStep3Valid {
    if (Validators.requiredPositiveNumber(_area) != null) return false;
    if (_category == PropertyCategory.residential || _category == null) {
      return _bhkType != null &&
          Validators.requiredPositiveInt(_bedrooms) == null &&
          Validators.requiredPositiveInt(_bathrooms) == null;
    }
    return true;
  }

  bool get isStep4Valid => _furnishingType != null;

  bool get isStep5Valid => true;

  bool get isStep6Valid => true;

  bool get isStep7Valid {
    // Validate optional numeric fields: reject invalid values when filled.
    if (Validators.optionalPositiveNumber(_ratePerArea) != null) return false;
    if (Validators.optionalNonNegativeNumber(_securityDeposit) != null) return false;
    if (Validators.optionalNonNegativeNumber(_maintenanceCharges) != null) return false;
    if (Validators.optionalPositiveNumber(_bookingAmount) != null) return false;
    if (Validators.optionalPercent(text('roiEstimate')) != null) return false;
    if (Validators.optionalPositiveNumber(text('monthlyRentPerBed')) != null) return false;
    if (Validators.optionalPositiveNumber(text('monthlyRentPerRoom')) != null) return false;
    if (Validators.optionalPercent(text('occupancyRate')) != null) return false;

    // PG additionally requires at least one price field to be present.
    if (_category != PropertyCategory.pg) return true;
    switch (_listingIntent) {
      case ListingIntent.rent:
        return text('monthlyRentPerBed').trim().isNotEmpty ||
            text('monthlyRentPerRoom').trim().isNotEmpty ||
            _price.trim().isNotEmpty;
      case ListingIntent.sell:
        return text('totalSalePrice').trim().isNotEmpty || _price.trim().isNotEmpty;
      case ListingIntent.lease:
        return text('leaseAmount').trim().isNotEmpty || _price.trim().isNotEmpty;
      default:
        return _price.trim().isNotEmpty;
    }
  }

  bool get isStep8Valid {
    final hasMedia = _mediaItems.isNotEmpty || _existingMediaUrls.isNotEmpty;
    final hasName = Validators.required(_contactName) == null;
    final hasPhone = Validators.phone(_contactPhone) == null;
    final hasEmail = Validators.email(_contactEmail) == null;
    return hasMedia && hasName && hasPhone && hasEmail;
  }

  bool get isStep9Valid => true;

  bool get canGoNext {
    switch (_currentStep) {
      case 0:
        return isStep1Valid;
      case 1:
        return isStep2Valid;
      case 2:
        return isStep3Valid;
      case 3:
        return isStep4Valid;
      case 4:
        return isStep5Valid;
      case 5:
        return isStep6Valid;
      case 6:
        return isStep7Valid;
      case 7:
        return isStep8Valid;
      case 8:
        return isStep9Valid;
      default:
        return false;
    }
  }

  bool get isLastStep => _currentStep == totalSteps - 1;

  // ── Setters: Step 1-2 ──────────────────────────────────────────────────
  void setCategory(PropertyCategory category) {
    _category = category;
    notifyListeners();
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

  // ── Setters: Step 8 ────────────────────────────────────────────────────
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

  void reset() {
    _currentStep = 0;
    _isSubmitting = false;
    _editingPropertyId = null;
    _existingMediaUrls = [];
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
    _areaUnit = propertyRow['area_unit']?.toString() ?? 'sq_ft';
    _area = propertyRow['area']?.toString() ?? '';
    _residentialSubType = propertyRow['residential_subtype']?.toString();

    final String? availableFrom = propertyRow['available_from']?.toString();
    if (availableFrom != null) _availableFrom = DateTime.tryParse(availableFrom);

    final mediaUrls = propertyRow['media_urls'];
    if (mediaUrls is List) {
      _existingMediaUrls = List<String>.from(mediaUrls);
    }

    final Map<String, dynamic> meta =
        (propertyRow['metadata'] as Map<String, dynamic>?) ?? {};

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

    _hydrateBagFromMetadata(meta);

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

    notifyListeners();
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
  void _hydrateBagFromMetadata(Map<String, dynamic> meta) {
    meta.forEach((key, value) {
      if (value == null || _namedMetadataKeys.contains(key)) return;

      if (value is bool) {
        _bool[key] = value;
      } else if (value is List) {
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
