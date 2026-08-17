// screens/profile_completion/broker_registration/broker_registration_screen.dart
//
// Mirrors `BrokerRegistration.tsx` field-for-field: same 7 steps (Personal,
// Professional, Address, Documents, Social, Account, Terms), same
// required-field map (`STEP_REQUIRED`), same regex patterns (`PATTERNS`),
// same option lists, same upsert payload shape (`handleSubmit`).
//
// The portal's "Step 4: Service Details" (propertyTypesHandled, serviceAreas,
// priceRangeMin/Max, buyRentBoth, commissionDetails, availabilityTiming) has
// no JSX anywhere in `renderStepContent` — `stepsList` only has 7 entries and
// none of them render those fields. They are still written into every broker
// row with their fixed initial values (`ProfileService.saveBrokerProfile`
// hardcodes them), but there is no step here to collect them, matching the
// portal exactly.
//
// No password field on the Account step — the account's password is already
// set at signup (auth_screen.dart's sign-up form collects it before this
// screen is ever reached), same fix as the builder registration screen.
//
// Validation is an imperative `_errors` map computed on "Continue"/"Submit",
// not live per-keystroke — matching how the portal's `handleNext`/
// `handleSubmit` work.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/text_input_formatters.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/geocoding_service.dart';
import '../../../services/profile_media_service.dart';
import '../../../services/profile_service.dart';
import '../../../services/registration_draft_store.dart';
import '../../../widgets/address_autocomplete_field.dart';
import '../../../widgets/location_picker_map.dart';
import '../../role_home_router.dart';

// ── Portal constants, transcribed verbatim (BrokerRegistration.tsx:111-192) ─

const List<Map<String, String>> _kCountryCodes = [
  {'code': '+91', 'country': 'India'},
  {'code': '+1', 'country': 'USA'},
  {'code': '+44', 'country': 'UK'},
  {'code': '+61', 'country': 'Australia'},
  {'code': '+971', 'country': 'UAE'},
];

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final RegExp _mobilePattern = RegExp(r'^[6-9]\d{9}$');
final RegExp _pincodePattern = RegExp(r'^\d{6}$');
final RegExp _reraPattern = RegExp(r'^[A-Z]{2}\d{4}\d{4}$');
final RegExp _websitePattern = RegExp(
  r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b',
);

const List<String> _kBrokerTypes = [
  'Independent Broker',
  'Real Estate Agency',
  'Freelancer',
  'Property Consultant',
];

const List<String> _kExpertiseOptions = [
  'Luxury Properties',
  'High-Rise Apartments',
  'Commercial Leasing',
  'Farmhouses & Land',
  'Affordable Housing',
  'First-Time Home Buyers',
  'Industrial Spaces',
  'Real Estate Investment Advisor',
];

const List<String> _kLanguageOptions = [
  'English',
  'Hindi',
  'Marathi',
  'Gujarati',
  'Tamil',
  'Telugu',
  'Kannada',
  'Malayalam',
  'Bengali',
  'Punjabi',
];

const List<String> _kGenderOptions = ['Male', 'Female', 'Other', 'Skip'];

bool _isBlank(String? v) => v == null || v.trim().isEmpty;

class BrokerRegistrationScreen extends StatefulWidget {
  const BrokerRegistrationScreen({super.key});

  @override
  State<BrokerRegistrationScreen> createState() =>
      _BrokerRegistrationScreenState();
}

class _BrokerRegistrationScreenState extends State<BrokerRegistrationScreen> {
  int currentStep = 0;
  bool _isSubmitting = false;
  final Map<String, String> _errors = {};
  final _mediaService = ProfileMediaService();
  final Set<String> _uploading = {};
  final _draftStore = RegistrationDraftStore('broker_registration_draft');

  // ─── Step 1 – Personal Information ───────────────────────────────────────
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  String _countryCode = '+91';
  String _alternateCountryCode = '+91';
  String? _gender;
  final _dobCtrl = TextEditingController();
  String? _avatarUrl;
  bool _isEmailUser = false;
  bool _isPhoneUser = false;

  // ─── Step 2 – Professional Details ────────────────────────────────────────
  final _brokerFirmNameCtrl = TextEditingController();
  String? _brokerType;
  final _reraNumberCtrl = TextEditingController();
  final _yearsOfExpCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _aboutBrokerCtrl = TextEditingController();
  final List<String> _areasOfExpertise = [];
  final List<String> _languagesKnown = [];
  final _customAreaCtrl = TextEditingController();
  final _customLangCtrl = TextEditingController();

  // ─── Step 3 – Address Information ────────────────────────────────────────
  final _officeAddressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  // Not submitted — mirrors the portal, which only ever uses these to drive
  // the map picker and geocoding, never to populate the upsert payloads.
  double? _pickedLat;
  double? _pickedLng;

  // ─── Step 4 – Verification & Documents ───────────────────────────────────
  String? _aadhaarCardUrl;
  String? _panCardUrl;
  String? _reraCertificateUrl;

  // ─── Step 5 – Social Media ────────────────────────────────────────────────
  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();

  // ─── Step 6 – Account Setup ───────────────────────────────────────────────
  final _usernameCtrl = TextEditingController();
  Timer? _usernameDebounce;
  bool? _usernameAvailable;
  bool _usernameTaken = false;

  // ─── Step 7 – Terms ───────────────────────────────────────────────────────
  bool _termsAccepted = false;
  bool _privacyAccepted = false;

  final List<String> _stepTitles = [
    'Personal',
    'Professional',
    'Address',
    'Documents',
    'Socials',
    'Account',
    'Submit',
  ];

  final List<IconData> _stepIcons = [
    Icons.person_outline,
    Icons.badge_outlined,
    Icons.location_on_outlined,
    Icons.description_outlined,
    Icons.share_outlined,
    Icons.lock_outline,
    Icons.verified_outlined,
  ];

  @override
  void initState() {
    super.initState();
    // Mirrors BrokerRegistration.tsx:346-384.
    final authUser = Supabase.instance.client.auth.currentUser;
    final rawEmail = authUser?.email;
    final rawPhone = authUser?.phone;

    _isEmailUser = rawEmail != null &&
        rawEmail.isNotEmpty &&
        !rawEmail.endsWith('@propcid.app');
    _isPhoneUser = (rawPhone != null && rawPhone.isNotEmpty) ||
        (rawEmail != null && rawEmail.endsWith('@propcid.app'));

    if (_isEmailUser) _emailCtrl.text = rawEmail!;
    if (_isPhoneUser) {
      if (rawPhone != null && rawPhone.isNotEmpty) {
        final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
        _mobileCtrl.text =
            digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      } else if (rawEmail != null) {
        final m = RegExp(r'u(\d+)@').firstMatch(rawEmail);
        if (m != null) _mobileCtrl.text = m.group(1)!;
      }
    }

    // The sign-up form (auth_screen.dart) already asked for this and stored
    // it as Supabase auth's `display_name` user metadata — pre-fill instead
    // of asking a second time. Mirrors the portal's own
    // `fullName: basicInfo.fullName || ...` restore (BrokerRegistration.tsx),
    // just reading Supabase auth metadata instead of the portal's
    // sessionStorage-based "basic info" step, which this app doesn't have.
    final metadataName = authUser?.userMetadata?['display_name'] as String?;
    if (metadataName != null && metadataName.trim().isNotEmpty) {
      _fullNameCtrl.text = metadataName.trim();
    }

    _wireDraftAutoSave();
    _restoreDraft();
  }

  // ─── Draft persistence — mirrors the portal's per-wizard localStorage
  // autosave (e.g. BrokerRegistration.tsx:329-339's `autoSave`), restored on
  // reopen so a half-filled form isn't lost between sessions. See
  // RegistrationDraftStore for the save/load/expiry mechanics.
  void _wireDraftAutoSave() {
    for (final c in [
      _fullNameCtrl, _emailCtrl, _mobileCtrl, _altMobileCtrl, _dobCtrl,
      _brokerFirmNameCtrl, _reraNumberCtrl, _yearsOfExpCtrl, _websiteCtrl,
      _aboutBrokerCtrl,
      _officeAddressCtrl, _cityCtrl, _stateCtrl, _pincodeCtrl, _landmarkCtrl,
      _facebookCtrl, _instagramCtrl, _linkedinCtrl, _youtubeCtrl,
      _whatsappCtrl, _telegramCtrl,
      _usernameCtrl,
    ]) {
      c.addListener(_scheduleDraftSave);
    }
  }

  void _scheduleDraftSave() => _draftStore.scheduleSave(_draftToJson);

  Map<String, dynamic> _draftToJson() => {
        'currentStep': currentStep,
        'fullName': _fullNameCtrl.text,
        'email': _emailCtrl.text,
        'mobileNumber': _mobileCtrl.text,
        'countryCode': _countryCode,
        'alternateMobileNumber': _altMobileCtrl.text,
        'alternateCountryCode': _alternateCountryCode,
        'gender': _gender ?? '',
        'dob': _dobCtrl.text,
        'avatarUrl': _avatarUrl ?? '',
        'brokerFirmName': _brokerFirmNameCtrl.text,
        'brokerType': _brokerType ?? '',
        'reraNumber': _reraNumberCtrl.text,
        'yearsOfExperience': _yearsOfExpCtrl.text,
        'websiteUrl': _websiteCtrl.text,
        'areasOfExpertise': _areasOfExpertise,
        'languagesKnown': _languagesKnown,
        'aboutBroker': _aboutBrokerCtrl.text,
        'officeAddress': _officeAddressCtrl.text,
        'city': _cityCtrl.text,
        'state': _stateCtrl.text,
        'pincode': _pincodeCtrl.text,
        'landmark': _landmarkCtrl.text,
        'pickedLat': _pickedLat,
        'pickedLng': _pickedLng,
        'aadhaarCardUrl': _aadhaarCardUrl ?? '',
        'panCardUrl': _panCardUrl ?? '',
        'reraCertificateUrl': _reraCertificateUrl ?? '',
        'facebookUrl': _facebookCtrl.text,
        'instagramUrl': _instagramCtrl.text,
        'linkedinUrl': _linkedinCtrl.text,
        'youtubeUrl': _youtubeCtrl.text,
        'whatsappNumber': _whatsappCtrl.text,
        'telegramUsername': _telegramCtrl.text,
        'username': _usernameCtrl.text,
        'termsAccepted': _termsAccepted,
        'privacyAccepted': _privacyAccepted,
      };

  Future<void> _restoreDraft() async {
    final data = await _draftStore.load();
    if (!mounted || data == null) return;

    String s(String key) => data[key] as String? ?? '';
    List<String> l(String key) => (data[key] as List<dynamic>?)?.cast<String>() ?? const [];

    setState(() {
      final step = data['currentStep'] as int?;
      if (step != null && step >= 0 && step < _stepTitles.length) currentStep = step;

      if (s('fullName').isNotEmpty) _fullNameCtrl.text = s('fullName');
      if (s('email').isNotEmpty) _emailCtrl.text = s('email');
      if (s('mobileNumber').isNotEmpty) _mobileCtrl.text = s('mobileNumber');
      if (s('countryCode').isNotEmpty) _countryCode = s('countryCode');
      if (s('alternateMobileNumber').isNotEmpty) {
        _altMobileCtrl.text = s('alternateMobileNumber');
      }
      if (s('alternateCountryCode').isNotEmpty) {
        _alternateCountryCode = s('alternateCountryCode');
      }
      if (s('gender').isNotEmpty) _gender = s('gender');
      if (s('dob').isNotEmpty) _dobCtrl.text = s('dob');
      if (s('avatarUrl').isNotEmpty) _avatarUrl = s('avatarUrl');

      if (s('brokerFirmName').isNotEmpty) _brokerFirmNameCtrl.text = s('brokerFirmName');
      if (s('brokerType').isNotEmpty) _brokerType = s('brokerType');
      if (s('reraNumber').isNotEmpty) _reraNumberCtrl.text = s('reraNumber');
      if (s('yearsOfExperience').isNotEmpty) {
        _yearsOfExpCtrl.text = s('yearsOfExperience');
      }
      if (s('websiteUrl').isNotEmpty) _websiteCtrl.text = s('websiteUrl');
      final expertise = l('areasOfExpertise');
      if (expertise.isNotEmpty) {
        _areasOfExpertise
          ..clear()
          ..addAll(expertise);
      }
      final languages = l('languagesKnown');
      if (languages.isNotEmpty) {
        _languagesKnown
          ..clear()
          ..addAll(languages);
      }
      if (s('aboutBroker').isNotEmpty) _aboutBrokerCtrl.text = s('aboutBroker');

      if (s('officeAddress').isNotEmpty) _officeAddressCtrl.text = s('officeAddress');
      if (s('city').isNotEmpty) _cityCtrl.text = s('city');
      if (s('state').isNotEmpty) _stateCtrl.text = s('state');
      if (s('pincode').isNotEmpty) _pincodeCtrl.text = s('pincode');
      if (s('landmark').isNotEmpty) _landmarkCtrl.text = s('landmark');
      _pickedLat = (data['pickedLat'] as num?)?.toDouble() ?? _pickedLat;
      _pickedLng = (data['pickedLng'] as num?)?.toDouble() ?? _pickedLng;

      if (s('aadhaarCardUrl').isNotEmpty) _aadhaarCardUrl = s('aadhaarCardUrl');
      if (s('panCardUrl').isNotEmpty) _panCardUrl = s('panCardUrl');
      if (s('reraCertificateUrl').isNotEmpty) {
        _reraCertificateUrl = s('reraCertificateUrl');
      }

      if (s('facebookUrl').isNotEmpty) _facebookCtrl.text = s('facebookUrl');
      if (s('instagramUrl').isNotEmpty) _instagramCtrl.text = s('instagramUrl');
      if (s('linkedinUrl').isNotEmpty) _linkedinCtrl.text = s('linkedinUrl');
      if (s('youtubeUrl').isNotEmpty) _youtubeCtrl.text = s('youtubeUrl');
      if (s('whatsappNumber').isNotEmpty) _whatsappCtrl.text = s('whatsappNumber');
      if (s('telegramUsername').isNotEmpty) _telegramCtrl.text = s('telegramUsername');

      if (s('username').isNotEmpty) _usernameCtrl.text = s('username');
      _termsAccepted = data['termsAccepted'] as bool? ?? _termsAccepted;
      _privacyAccepted = data['privacyAccepted'] as bool? ?? _privacyAccepted;
    });
  }

  // ─── Navigation ───────────────────────────────────────────────────────────
  void _nextStep() {
    final stepErrors = switch (currentStep) {
      0 => _validateStep0(),
      1 => _validateStep1(),
      2 => _validateStep2(),
      3 => _validateStep3(),
      4 => _validateStep4(),
      5 => _validateStep5(),
      _ => <String, String>{},
    };

    setState(() {
      _errors.clear();
      _errors.addAll(stepErrors);
    });

    if (stepErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the highlighted fields to continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (currentStep < _stepTitles.length - 1) {
      setState(() => currentStep++);
      _scheduleDraftSave();
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
        _errors.clear();
      });
      _scheduleDraftSave();
    }
  }

  // ─── Per-step validation — mirrors STEP_REQUIRED + the custom checks in
  // BrokerRegistration.tsx:718-796 ──────────────────────────────────────────
  Map<String, String> _validateStep0() {
    final e = <String, String>{};
    if ((_avatarUrl ?? '').isEmpty) e['avatarUrl'] = 'Profile photo is required.';
    if (_isBlank(_fullNameCtrl.text)) e['fullName'] = 'Full name is required.';
    if (_isBlank(_emailCtrl.text)) {
      e['email'] = 'Email address is required.';
    } else if (!_emailPattern.hasMatch(_emailCtrl.text.trim())) {
      e['email'] = 'Please enter a valid email address.';
    }
    if (_isBlank(_mobileCtrl.text)) {
      e['mobileNumber'] = 'Mobile number is required.';
    } else {
      final digits = _mobileCtrl.text.replaceAll(RegExp(r'\D'), '');
      if (_countryCode == '+91') {
        if (!_mobilePattern.hasMatch(digits)) {
          e['mobileNumber'] = 'Mobile number must be a valid 10-digit number.';
        }
      } else if (digits.length < 8 || digits.length > 12) {
        e['mobileNumber'] = 'Phone number must be between 8 and 12 digits.';
      }
    }
    if (_altMobileCtrl.text.trim().isNotEmpty) {
      final digits = _altMobileCtrl.text.replaceAll(RegExp(r'\D'), '');
      if (_alternateCountryCode == '+91') {
        if (!_mobilePattern.hasMatch(digits)) {
          e['alternateMobileNumber'] =
              'Alternate number must be a valid 10-digit Indian mobile number.';
        }
      } else if (digits.length < 8 || digits.length > 12) {
        e['alternateMobileNumber'] = 'Alternate number must be between 8 and 12 digits.';
      }
    }
    if (_gender == null || _gender!.isEmpty) e['gender'] = 'Gender is required.';
    if (_isBlank(_dobCtrl.text)) e['dob'] = 'Date of birth is required.';
    return e;
  }

  Map<String, String> _validateStep1() {
    final e = <String, String>{};
    if (_isBlank(_brokerFirmNameCtrl.text)) {
      e['brokerFirmName'] = 'Broker firm name is required.';
    }
    if (_brokerType == null || _brokerType!.isEmpty) {
      e['brokerType'] = 'Broker type is required.';
    }
    if (_isBlank(_reraNumberCtrl.text)) {
      e['reraNumber'] = 'RERA registration number is required.';
    } else if (!_reraPattern.hasMatch(_reraNumberCtrl.text.trim())) {
      e['reraNumber'] = 'RERA format is invalid. Matches e.g. MH12345678';
    }
    if (_isBlank(_yearsOfExpCtrl.text)) {
      e['yearsOfExperience'] = 'Years of experience is required.';
    }
    if (_isBlank(_websiteCtrl.text)) e['websiteUrl'] = 'Website URL is required.';
    if (_areasOfExpertise.isEmpty) {
      e['areasOfExpertise'] = 'Areas of expertise is required.';
    }
    if (_languagesKnown.isEmpty) e['languagesKnown'] = 'Languages known is required.';
    if (_isBlank(_aboutBrokerCtrl.text)) e['aboutBroker'] = 'About you is required.';
    return e;
  }

  Map<String, String> _validateStep2() {
    final e = <String, String>{};
    if (_isBlank(_officeAddressCtrl.text)) e['officeAddress'] = 'Office address is required.';
    if (_isBlank(_cityCtrl.text)) e['city'] = 'City is required.';
    if (_isBlank(_stateCtrl.text)) e['state'] = 'State is required.';
    if (_isBlank(_pincodeCtrl.text)) {
      e['pincode'] = 'Pincode is required.';
    } else if (!_pincodePattern.hasMatch(_pincodeCtrl.text.trim())) {
      e['pincode'] = 'Pincode must be a 6-digit number.';
    }
    return e;
  }

  Map<String, String> _validateStep3() {
    final e = <String, String>{};
    if ((_aadhaarCardUrl ?? '').isEmpty) e['aadhaarCardUrl'] = 'Aadhaar card copy is required.';
    if ((_panCardUrl ?? '').isEmpty) e['panCardUrl'] = 'PAN card copy is required.';
    if ((_reraCertificateUrl ?? '').isEmpty) {
      e['reraCertificateUrl'] = 'RERA certificate is required.';
    }
    return e;
  }

  Map<String, String> _validateStep4() {
    final e = <String, String>{};
    if (_facebookCtrl.text.trim().isNotEmpty &&
        !_websitePattern.hasMatch(_facebookCtrl.text.trim())) {
      e['facebookUrl'] = 'Please enter a valid URL.';
    }
    if (_instagramCtrl.text.trim().isNotEmpty &&
        !_websitePattern.hasMatch(_instagramCtrl.text.trim())) {
      e['instagramUrl'] = 'Please enter a valid URL.';
    }
    if (_linkedinCtrl.text.trim().isNotEmpty &&
        !_websitePattern.hasMatch(_linkedinCtrl.text.trim())) {
      e['linkedinUrl'] = 'Please enter a valid URL.';
    }
    if (_youtubeCtrl.text.trim().isNotEmpty &&
        !_websitePattern.hasMatch(_youtubeCtrl.text.trim())) {
      e['youtubeUrl'] = 'Please enter a valid URL.';
    }
    return e;
  }

  Map<String, String> _validateStep5() {
    final e = <String, String>{};
    final username = _usernameCtrl.text.trim();
    if (username.length < 3) {
      e['username'] = 'Username must be at least 3 characters.';
    } else if (_usernameAvailable == null) {
      e['username'] = 'Checking username availability. Please wait.';
    } else if (_usernameTaken) {
      e['username'] = 'This username is already taken.';
    }
    return e;
  }

  // ─── Username availability — mirrors BrokerRegistration.tsx:386-421 ──────
  void _onUsernameChanged(String value) {
    final cleaned =
        value.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').toLowerCase();
    if (cleaned != value) {
      _usernameCtrl.value = TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
      return; // the recursive onChanged(cleaned) call handles the debounce
    }

    _usernameDebounce?.cancel();
    if (cleaned.length < 3) {
      setState(() {
        _usernameAvailable = null;
        _usernameTaken = false;
      });
      return;
    }
    _usernameDebounce =
        Timer(const Duration(milliseconds: 500), () => _checkUsername(cleaned));
    setState(() {});
  }

  Future<void> _checkUsername(String username) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('username, user_id')
          .eq('username', username)
          .maybeSingle();
      if (!mounted) return;
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final taken = data != null && data['user_id'] != currentUserId;
      setState(() {
        _usernameTaken = taken;
        _usernameAvailable = !taken;
      });
    } catch (e) {
      debugPrint('Username availability check failed: $e');
    }
  }

  // ─── Uploads — real files via ProfileMediaService ────────────────────────
  Future<void> _pickAndUploadAvatar() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _uploading.add('avatarUrl'));
    try {
      final file = await _mediaService.pickAvatar();
      if (file == null) return;
      final url = await _mediaService.uploadAvatar(userId: userId, file: file);
      if (mounted) {
        setState(() => _avatarUrl = url);
        _scheduleDraftSave();
      }
    } catch (e) {
      _showUploadError(e);
    } finally {
      if (mounted) setState(() => _uploading.remove('avatarUrl'));
    }
  }

  Future<void> _pickAndUploadDocument(
    String fieldKey,
    ProfileDocumentKind kind,
  ) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _uploading.add(fieldKey));
    try {
      final file = await _mediaService.pickDocument();
      if (file == null) return;
      final url =
          await _mediaService.uploadDocument(userId: userId, kind: kind, file: file);
      if (!mounted) return;
      setState(() {
        switch (fieldKey) {
          case 'aadhaarCardUrl':
            _aadhaarCardUrl = url;
          case 'panCardUrl':
            _panCardUrl = url;
          case 'reraCertificateUrl':
            _reraCertificateUrl = url;
        }
      });
      _scheduleDraftSave();
    } catch (e) {
      _showUploadError(e);
    } finally {
      if (mounted) setState(() => _uploading.remove(fieldKey));
    }
  }

  void _showUploadError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
    );
  }

  // ─── Pill pickers ─────────────────────────────────────────────────────────
  void _toggleExpertise(String item) {
    setState(() {
      _areasOfExpertise.contains(item)
          ? _areasOfExpertise.remove(item)
          : _areasOfExpertise.add(item);
    });
    _scheduleDraftSave();
  }

  void _removeExpertise(String item) {
    setState(() => _areasOfExpertise.remove(item));
    _scheduleDraftSave();
  }

  void _addCustomExpertise(String value) {
    final v = value.trim();
    _customAreaCtrl.clear();
    if (v.isEmpty || _areasOfExpertise.contains(v)) return;
    setState(() => _areasOfExpertise.add(v));
    _scheduleDraftSave();
  }

  void _toggleLanguage(String item) {
    setState(() {
      _languagesKnown.contains(item)
          ? _languagesKnown.remove(item)
          : _languagesKnown.add(item);
    });
    _scheduleDraftSave();
  }

  void _removeLanguage(String item) {
    setState(() => _languagesKnown.remove(item));
    _scheduleDraftSave();
  }

  void _addCustomLanguage(String value) {
    final v = value.trim();
    _customLangCtrl.clear();
    if (v.isEmpty || _languagesKnown.contains(v)) return;
    setState(() => _languagesKnown.add(v));
    _scheduleDraftSave();
  }

  // ─── Date picker ──────────────────────────────────────────────────────────
  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30),
      firstDate: DateTime(1950),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dobCtrl.text = '${picked.year.toString().padLeft(4, '0')}-'
            '${picked.month.toString().padLeft(2, '0')}-'
            '${picked.day.toString().padLeft(2, '0')}';
      });
      _scheduleDraftSave();
    }
  }

  // ─── Map picker — mirrors BrokerRegistration.tsx:626-648's
  // handleLocationSelect: keep the existing value when the geocode result
  // didn't resolve that field.
  // [updateOfficeAddress] is false for the autocomplete field's selections:
  // it already wrote the full selected description into the controller
  // itself (matching the portal, which fills `officeAddress` with
  // `place.formatted_address`) — overwriting it here with the shorter parsed
  // `addressLine1` would fight that. The map tap path has no pre-filled
  // text, so it still wants this.
  void _onLocationSelected(
    double lat,
    double lng,
    GeocodedAddress? address, {
    bool updateOfficeAddress = true,
  }) {
    setState(() {
      _pickedLat = lat;
      _pickedLng = lng;
      if (updateOfficeAddress && (address?.addressLine1 ?? '').isNotEmpty) {
        _officeAddressCtrl.text = address!.addressLine1!;
      }
      if ((address?.city ?? '').isNotEmpty) _cityCtrl.text = address!.city!;
      if ((address?.state ?? '').isNotEmpty) _stateCtrl.text = address!.state!;
      if ((address?.pincode ?? '').isNotEmpty) _pincodeCtrl.text = address!.pincode!;
      if ((address?.landmark ?? '').isNotEmpty) _landmarkCtrl.text = address!.landmark!;
      _errors.remove('officeAddress');
      _errors.remove('city');
      _errors.remove('state');
      _errors.remove('pincode');
    });
    _scheduleDraftSave();
  }

  // ─── Submit — mirrors BrokerRegistration.tsx:829-964 ─────────────────────
  Future<void> _onSubmit() async {
    if (!_termsAccepted || !_privacyAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please accept the terms and conditions and privacy policy to continue.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ProfileService().saveBrokerProfile({
        'fullName': _fullNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'mobileNumber': _mobileCtrl.text.trim(),
        'countryCode': _countryCode,
        'alternateMobileNumber': _altMobileCtrl.text.trim(),
        'alternateCountryCode': _alternateCountryCode,
        'gender': _gender ?? '',
        'dob': _dobCtrl.text.trim(),
        'avatarUrl': _avatarUrl ?? '',
        'brokerFirmName': _brokerFirmNameCtrl.text.trim(),
        'brokerType': _brokerType ?? '',
        'reraNumber': _reraNumberCtrl.text.trim(),
        'yearsOfExperience': _yearsOfExpCtrl.text.trim(),
        'websiteUrl': _websiteCtrl.text.trim(),
        'areasOfExpertise': _areasOfExpertise,
        'languagesKnown': _languagesKnown,
        'aboutBroker': _aboutBrokerCtrl.text.trim(),
        'officeAddress': _officeAddressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'landmark': _landmarkCtrl.text.trim(),
        'aadhaarCardUrl': _aadhaarCardUrl ?? '',
        'panCardUrl': _panCardUrl ?? '',
        'reraCertificateUrl': _reraCertificateUrl ?? '',
        'facebookUrl': _facebookCtrl.text.trim(),
        'instagramUrl': _instagramCtrl.text.trim(),
        'linkedinUrl': _linkedinCtrl.text.trim(),
        'youtubeUrl': _youtubeCtrl.text.trim(),
        'whatsappNumber': _whatsappCtrl.text.trim(),
        'telegramUsername': _telegramCtrl.text.trim(),
        'username': _usernameCtrl.text.trim(),
      });

      if (!mounted) return;

      (await SharedPreferences.getInstance()).remove('pending_user_type');
      await _draftStore.clear();
      await context.read<AuthProvider>().refreshProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Broker profile saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RoleHomeRouter()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Shared UI widgets ────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    Widget? suffix,
    bool hasError = false,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label.isEmpty ? null : label,
      hintText: hint,
      suffixIcon: suffix,
      filled: true,
      fillColor: scheme.surfaceVariant.withOpacity(0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? scheme.error : scheme.outline.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: hasError ? scheme.error : scheme.primary,
          width: 2,
        ),
      ),
      contentPadding:
          contentPadding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _errorText(String fieldKey) {
    final msg = _errors[fieldKey];
    if (msg == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 14, color: Colors.red),
          const SizedBox(width: 4),
          Expanded(
            child: Text(msg, style: const TextStyle(fontSize: 12, color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
          children: [
            if (required)
              const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required String fieldKey,
    required TextEditingController controller,
    required String label,
    bool required = false,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
    void Function(String)? onChanged,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            readOnly: readOnly,
            onTap: onTap,
            onChanged: onChanged,
            enabled: enabled,
            decoration: _inputDecoration(
              required ? '$label *' : label,
              hint: hint,
              suffix: suffixIcon,
              hasError: _errors.containsKey(fieldKey),
            ),
          ),
          _errorText(fieldKey),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String fieldKey,
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            value: value,
            decoration: _inputDecoration(
              required ? '$label *' : label,
              hasError: _errors.containsKey(fieldKey),
            ),
            items: items
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: onChanged,
          ),
          _errorText(fieldKey),
        ],
      ),
    );
  }

  Widget _phoneField({
    required String fieldKey,
    required TextEditingController controller,
    required String label,
    required String countryCode,
    required void Function(String) onCountryChanged,
    bool enabled = true,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: DropdownButtonFormField<String>(
                  value: countryCode,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, size: 18),
                  decoration: _inputDecoration(
                    '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  ),
                  items: _kCountryCodes
                      .map((c) => DropdownMenuItem(
                            value: c['code'],
                            child: Text(c['code']!, overflow: TextOverflow.ellipsis),
                          ))
                      .toList(),
                  onChanged: enabled
                      ? (v) {
                          if (v != null) onCountryChanged(v);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _inputDecoration(
                    required ? '$label *' : label,
                    hasError: _errors.containsKey(fieldKey),
                  ),
                ),
              ),
            ],
          ),
          _errorText(fieldKey),
        ],
      ),
    );
  }

  Widget _uploadCard({
    required String fieldKey,
    required String label,
    required String? url,
    required VoidCallback onTap,
    bool required = false,
    String subtitle = '',
    bool isImagePreview = false,
  }) {
    final busy = _uploading.contains(fieldKey);
    final has = (url ?? '').isNotEmpty;
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          if (subtitle.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                subtitle,
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ),
          GestureDetector(
            onTap: busy ? null : onTap,
            child: Container(
              height: 108,
              width: double.infinity,
              decoration: BoxDecoration(
                color: scheme.surfaceVariant.withOpacity(0.4),
                border: Border.all(
                  color: _errors.containsKey(fieldKey)
                      ? scheme.error
                      : (has ? scheme.primary : scheme.outline.withOpacity(0.4)),
                  width: has ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: busy
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(height: 8),
                          Text('Uploading...', style: TextStyle(fontSize: 12)),
                        ],
                      )
                    : has
                        ? (isImagePreview
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  url!,
                                  height: 64,
                                  width: 64,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.check_circle, color: Colors.green, size: 30),
                                  SizedBox(height: 6),
                                  Text('Uploaded', style: TextStyle(fontSize: 12)),
                                ],
                              ))
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.upload_file, color: scheme.onSurfaceVariant),
                              const SizedBox(height: 6),
                              const Text('Tap to upload', style: TextStyle(fontSize: 12)),
                            ],
                          ),
              ),
            ),
          ),
          _errorText(fieldKey),
        ],
      ),
    );
  }

  Widget _pillPicker({
    required String fieldKey,
    required String label,
    required List<String> selected,
    required List<String> options,
    required TextEditingController customCtrl,
    required void Function(String) onToggle,
    required void Function(String) onRemove,
    required void Function(String) onAddCustom,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.3),
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: selected.isEmpty
                ? Text(
                    'Select from below or add a custom entry',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: selected
                        .map((s) => Chip(
                              label: Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                              onDeleted: () => onRemove(s),
                              deleteIcon: const Icon(Icons.close, size: 14),
                            ))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: customCtrl,
                  decoration: _inputDecoration('Add custom...'),
                  onSubmitted: onAddCustom,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => onAddCustom(customCtrl.text),
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options
                .where((o) => !selected.contains(o))
                .map((o) => ActionChip(
                      label: Text(
                        '+ $o',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                        ),
                      ),
                      onPressed: () => onToggle(o),
                    ))
                .toList(),
          ),
          _errorText(fieldKey),
        ],
      ),
    );
  }

  // ─── Progress Header ──────────────────────────────────────────────────────
  Widget _buildProgressHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _stepTitles[currentStep],
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentStep + 1} / ${_stepTitles.length}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (currentStep + 1) / _stepTitles.length,
            minHeight: 8,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── Step 1 — Personal Information ───────────────────────────────────────
  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Personal Information'),
        _uploadCard(
          fieldKey: 'avatarUrl',
          label: 'Profile Photo',
          url: _avatarUrl,
          onTap: _pickAndUploadAvatar,
          required: true,
          isImagePreview: true,
          subtitle: 'Provide your primary contact and profile photo.',
        ),
        _field(
          fieldKey: 'fullName',
          controller: _fullNameCtrl,
          label: 'Full Name',
          required: true,
          hint: 'e.g. John Doe',
        ),
        _field(
          fieldKey: 'email',
          controller: _emailCtrl,
          label: 'Email Address',
          required: true,
          keyboardType: TextInputType.emailAddress,
          enabled: !_isEmailUser,
        ),
        _phoneField(
          fieldKey: 'mobileNumber',
          controller: _mobileCtrl,
          label: 'Mobile Number',
          countryCode: _countryCode,
          onCountryChanged: (v) {
            setState(() => _countryCode = v);
            _scheduleDraftSave();
          },
          enabled: !_isPhoneUser,
          required: true,
        ),
        _phoneField(
          fieldKey: 'alternateMobileNumber',
          controller: _altMobileCtrl,
          label: 'Alternate Mobile Number',
          countryCode: _alternateCountryCode,
          onCountryChanged: (v) {
            setState(() => _alternateCountryCode = v);
            _scheduleDraftSave();
          },
        ),
        _label('Gender', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kGenderOptions.map((g) {
            final selected = _gender == g;
            return ChoiceChip(
              label: Text(g == 'Skip' ? 'N/A' : g),
              selected: selected,
              onSelected: (_) {
                setState(() => _gender = g);
                _scheduleDraftSave();
              },
            );
          }).toList(),
        ),
        _errorText('gender'),
        const SizedBox(height: 16),
        _field(
          fieldKey: 'dob',
          controller: _dobCtrl,
          label: 'Date of Birth',
          required: true,
          readOnly: true,
          onTap: _pickDob,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
      ],
    );
  }

  // ─── Step 2 — Professional Details ───────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Professional Details'),
        _field(
          fieldKey: 'brokerFirmName',
          controller: _brokerFirmNameCtrl,
          label: 'Broker/Firm Name',
          required: true,
          hint: 'e.g. Full Name',
        ),
        _dropdown(
          fieldKey: 'brokerType',
          label: 'Broker Type',
          value: _brokerType,
          items: _kBrokerTypes,
          onChanged: (v) {
            setState(() => _brokerType = v);
            _scheduleDraftSave();
          },
          required: true,
        ),
        _field(
          fieldKey: 'reraNumber',
          controller: _reraNumberCtrl,
          label: 'RERA Registration Number',
          required: true,
          hint: 'e.g. MH12345678',
          inputFormatters: [const UpperCaseTextFormatter()],
        ),
        _field(
          fieldKey: 'yearsOfExperience',
          controller: _yearsOfExpCtrl,
          label: 'Years of Experience',
          required: true,
          hint: 'e.g. 5',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        _field(
          fieldKey: 'websiteUrl',
          controller: _websiteCtrl,
          label: 'Website URL',
          required: true,
          keyboardType: TextInputType.url,
          hint: 'e.g. https://www.mycompany.com',
        ),
        _pillPicker(
          fieldKey: 'areasOfExpertise',
          label: 'Areas of Expertise',
          selected: _areasOfExpertise,
          options: _kExpertiseOptions,
          customCtrl: _customAreaCtrl,
          onToggle: _toggleExpertise,
          onRemove: _removeExpertise,
          onAddCustom: _addCustomExpertise,
        ),
        _pillPicker(
          fieldKey: 'languagesKnown',
          label: 'Languages Known',
          selected: _languagesKnown,
          options: _kLanguageOptions,
          customCtrl: _customLangCtrl,
          onToggle: _toggleLanguage,
          onRemove: _removeLanguage,
          onAddCustom: _addCustomLanguage,
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _aboutBrokerCtrl,
                maxLines: 4,
                maxLength: 400,
                decoration: _inputDecoration(
                  'About Broker (Short Summary) *',
                  hint: 'Describe your specialities, firm accomplishments, and services...',
                  hasError: _errors.containsKey('aboutBroker'),
                ),
              ),
              _errorText('aboutBroker'),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 3 — Office Address & Location ──────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Office Address & Location'),
        _label('Google Maps Location Picker'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: LocationPickerMap(
            initialLat: _pickedLat,
            initialLng: _pickedLng,
            onLocationSelected: _onLocationSelected,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AddressAutocompleteField(
                controller: _officeAddressCtrl,
                decoration: _inputDecoration(
                  'Office Address *',
                  hasError: _errors.containsKey('officeAddress'),
                ),
                maxLines: 2,
                onPlaceSelected: (address, lat, lng) => _onLocationSelected(
                  lat,
                  lng,
                  address,
                  updateOfficeAddress: false,
                ),
              ),
              _errorText('officeAddress'),
            ],
          ),
        ),
        _field(fieldKey: 'city', controller: _cityCtrl, label: 'Work City', required: true),
        _field(fieldKey: 'state', controller: _stateCtrl, label: 'State', required: true),
        _field(
          fieldKey: 'pincode',
          controller: _pincodeCtrl,
          label: 'Pincode',
          required: true,
          hint: '6-digit pincode',
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
        ),
        _field(
          fieldKey: 'landmark',
          controller: _landmarkCtrl,
          label: 'Landmark',
          hint: 'Famous landmark near office',
        ),
      ],
    );
  }

  // ─── Step 4 — Verification & Documents ───────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Verification & Documents'),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Upload verified files to gain a premium shield badge.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey),
          ),
        ),
        _uploadCard(
          fieldKey: 'aadhaarCardUrl',
          label: 'Aadhaar Card Copy',
          url: _aadhaarCardUrl,
          onTap: () => _pickAndUploadDocument('aadhaarCardUrl', ProfileDocumentKind.aadhaar),
          required: true,
        ),
        _uploadCard(
          fieldKey: 'panCardUrl',
          label: 'PAN Card Copy',
          url: _panCardUrl,
          onTap: () => _pickAndUploadDocument('panCardUrl', ProfileDocumentKind.pan),
          required: true,
        ),
        _uploadCard(
          fieldKey: 'reraCertificateUrl',
          label: 'RERA Certificate',
          url: _reraCertificateUrl,
          onTap: () =>
              _pickAndUploadDocument('reraCertificateUrl', ProfileDocumentKind.rera),
          required: true,
        ),
      ],
    );
  }

  // ─── Step 5 — Social Media Links & Connectivity ──────────────────────────
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Social Media Links & Connectivity'),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'Connect your professional networks — all optional.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey),
          ),
        ),
        _field(
          fieldKey: 'facebookUrl',
          controller: _facebookCtrl,
          label: 'Facebook Business Profile',
          hint: 'e.g. https://facebook.com/mycompany',
          keyboardType: TextInputType.url,
        ),
        _field(
          fieldKey: 'instagramUrl',
          controller: _instagramCtrl,
          label: 'Instagram Business Handle',
          hint: 'e.g. https://instagram.com/mycompany',
          keyboardType: TextInputType.url,
        ),
        _field(
          fieldKey: 'linkedinUrl',
          controller: _linkedinCtrl,
          label: 'LinkedIn Corporate Page',
          hint: 'e.g. https://linkedin.com/company/mycompany',
          keyboardType: TextInputType.url,
        ),
        _field(
          fieldKey: 'youtubeUrl',
          controller: _youtubeCtrl,
          label: 'YouTube Channel Link',
          hint: 'e.g. https://youtube.com/c/mycompany',
          keyboardType: TextInputType.url,
        ),
        _field(
          fieldKey: 'whatsappNumber',
          controller: _whatsappCtrl,
          label: 'WhatsApp Business Number',
          hint: 'WhatsApp active number',
        ),
        _field(
          fieldKey: 'telegramUsername',
          controller: _telegramCtrl,
          label: 'Telegram Link',
          hint: 'https://t.me/yourchannel',
        ),
      ],
    );
  }

  // ─── Step 6 — Account Setup ───────────────────────────────────────────────
  Widget _buildStep5() {
    final usernameLen = _usernameCtrl.text.trim().length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Account Setup'),
        _field(
          fieldKey: 'username',
          controller: _usernameCtrl,
          label: 'Choose Unique Username',
          required: true,
          hint: 'Choose username',
          onChanged: _onUsernameChanged,
          suffixIcon: usernameLen >= 3
              ? (_usernameTaken
                  ? const Icon(Icons.close, color: Colors.red)
                  : (_usernameAvailable == true
                      ? const Icon(Icons.check, color: Colors.green)
                      : null))
              : null,
        ),
        if (usernameLen >= 3 && !_usernameTaken && _usernameAvailable == true)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Username is available!', style: TextStyle(fontSize: 12, color: Colors.green)),
          ),
      ],
    );
  }

  // ─── Step 7 — Review & Submit ─────────────────────────────────────────────
  // Mirrors BrokerRegistration.tsx:1697-1742's accordion summary.
  Widget _reviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '—' : value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewSection(
    String title,
    List<MapEntry<String, String>> rows, {
    bool initiallyExpanded = false,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        children: rows.map((r) => _reviewRow(r.key, r.value)).toList(),
      ),
    );
  }

  Widget _buildReviewSummary() {
    final divider = Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _reviewSection(
            'Personal Information',
            [
              MapEntry('Full Name', _fullNameCtrl.text),
              MapEntry('Email', _emailCtrl.text),
              MapEntry('Phone', '$_countryCode ${_mobileCtrl.text}'),
              MapEntry('DOB', _dobCtrl.text),
            ],
            initiallyExpanded: true,
          ),
          divider,
          _reviewSection('Professional Profile', [
            MapEntry('Firm Name', _brokerFirmNameCtrl.text),
            MapEntry('Type', _brokerType ?? ''),
            MapEntry('RERA Number', _reraNumberCtrl.text),
            MapEntry('Experience', '${_yearsOfExpCtrl.text} Years'),
          ]),
          divider,
          _reviewSection('Address Details', [
            MapEntry('Office Address', _officeAddressCtrl.text),
            MapEntry('City & State', '${_cityCtrl.text}, ${_stateCtrl.text}'),
            MapEntry('Pincode', _pincodeCtrl.text),
          ]),
        ],
      ),
    );
  }

  Widget _buildStep6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Review & Submit'),
        _buildReviewSummary(),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.08),
            border: Border.all(color: Colors.blue.withOpacity(0.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'RERA and documents uploads are verified by our audit managers. '
                  'Approvals are generally finalized within 20-30 minutes! Once active, '
                  'a verified shield tag will display on all listings.',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _termsAccepted,
          onChanged: (v) {
            setState(() => _termsAccepted = v ?? false);
            _scheduleDraftSave();
          },
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I accept the Terms & Conditions of PropCID real estate platform. '
            'I declare the listings provided belong to verified owners.',
            style: TextStyle(fontSize: 13),
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _privacyAccepted,
          onChanged: (v) {
            setState(() => _privacyAccepted = v ?? false);
            _scheduleDraftSave();
          },
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text(
            'I agree to the Privacy Policy and authorize PropCID to display my '
            'contact details on property listings.',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ─── Step content router ──────────────────────────────────────────────────
  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      case 4:
        return _buildStep4();
      case 5:
        return _buildStep5();
      case 6:
        return _buildStep6();
      default:
        return const SizedBox();
    }
  }

  // ─── Bottom Navigation Buttons ────────────────────────────────────────────
  Widget _buildNavigationButtons() {
    final isLastStep = currentStep == _stepTitles.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _previousStep,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          if (currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : (isLastStep ? _onSubmit : _nextStep),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(
                      isLastStep ? Icons.check_circle_outline : Icons.arrow_forward,
                      size: 18,
                    ),
              label: Text(
                _isSubmitting
                    ? 'Submitting...'
                    : (isLastStep ? 'Submit Registration' : 'Continue'),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text(
          'Broker Registration',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(
              _stepIcons[currentStep],
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressHeader(),
                  _buildCurrentStep(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _draftStore.dispose();
    _usernameDebounce?.cancel();
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _altMobileCtrl.dispose();
    _dobCtrl.dispose();
    _brokerFirmNameCtrl.dispose();
    _reraNumberCtrl.dispose();
    _yearsOfExpCtrl.dispose();
    _websiteCtrl.dispose();
    _aboutBrokerCtrl.dispose();
    _customAreaCtrl.dispose();
    _customLangCtrl.dispose();
    _officeAddressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _landmarkCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _linkedinCtrl.dispose();
    _youtubeCtrl.dispose();
    _whatsappCtrl.dispose();
    _telegramCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }
}
