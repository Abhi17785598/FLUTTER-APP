import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/validation/validators.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/profile_service.dart';
import '../../role_home_router.dart';
import '../../../core/utils/text_input_formatters.dart';

class BrokerRegistrationScreen extends StatefulWidget {
  const BrokerRegistrationScreen({super.key});

  @override
  State<BrokerRegistrationScreen> createState() =>
      _BrokerRegistrationScreenState();
}

class _BrokerRegistrationScreenState extends State<BrokerRegistrationScreen> {
  int currentStep = 0;

  // ─── Step 1 – Personal Information ───────────────────────────────────────
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _altMobileCtrl = TextEditingController();
  String? _selectedGender;
  final _dobCtrl = TextEditingController();
  String _avatarPath = '';

  // ─── Step 2 – Broker Profile ──────────────────────────────────────────────
  final _reraNumberCtrl = TextEditingController();
  final _licenseNumberCtrl = TextEditingController();
  final _agencyNameCtrl = TextEditingController();
  final _yearsOfExpCtrl = TextEditingController();
  final _companyDescCtrl = TextEditingController();

  // ─── Step 3 – Address Information ────────────────────────────────────────
  final _officeAddressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();

  // ─── Step 4 – Business Details ────────────────────────────────────────────
  final List<String> _allPropertyTypes = [
    'Residential',
    'Commercial',
    'Industrial',
    'Plots',
    'Agricultural',
    'Luxury',
  ];
  final List<String> _selectedPropertyTypes = [];
  final _serviceAreasCtrl = TextEditingController();
  final _priceMinCtrl = TextEditingController();
  final _priceMaxCtrl = TextEditingController();
  String? _selectedDealType;
  final _commissionCtrl = TextEditingController();
  final _availabilityCtrl = TextEditingController();

  // ─── Step 5 – Documents ──────────────────────────────────────────────────
  String _aadhaarPath = '';
  String _panCardPath = '';
  String _reraCertPath = '';

  // ─── Step 6 – Social Media ────────────────────────────────────────────────
  final _whatsappCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _instagramCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _telegramCtrl = TextEditingController();

  // ─── Step 7 – Account Setup ───────────────────────────────────────────────
  final _usernameCtrl = TextEditingController();


  // ─── Form Keys ────────────────────────────────────────────────────────────
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();
  final _step3Key = GlobalKey<FormState>();
  final _step7Key = GlobalKey<FormState>();

  final List<String> _stepTitles = [
    'Personal Information',
    'Broker Profile',
    'Address Information',
    'Business Details',
    'Documents Upload',
    'Social Media',
    'Account Setup',
  ];

  final List<IconData> _stepIcons = [
    Icons.person_outline,
    Icons.badge_outlined,
    Icons.location_on_outlined,
    Icons.handshake_outlined,
    Icons.folder_outlined,
    Icons.share_outlined,
    Icons.lock_outline,
  ];

  // ─── Navigation ───────────────────────────────────────────────────────────
  bool _validateCurrentStep() {
    switch (currentStep) {
      case 0:
        return _step1Key.currentState?.validate() ?? false;
      case 1:
        return _step2Key.currentState?.validate() ?? false;
      case 2:
        return _step3Key.currentState?.validate() ?? false;
      case 6:
        return _step7Key.currentState?.validate() ?? false;
      default:
        return true;
    }
  }

  void _nextStep() {
    if (!_validateCurrentStep()) return;
    if (currentStep < _stepTitles.length - 1) {
      setState(() => currentStep++);
    }
  }

  void _previousStep() {
    if (currentStep > 0) setState(() => currentStep--);
  }

Future<void> _onSubmit() async {
  if (!(_step7Key.currentState?.validate() ?? false)) return;

  try {
    await ProfileService().saveBrokerProfile(
      fullName: _fullNameCtrl.text.trim(),
      reraNumber: _reraNumberCtrl.text.trim(),
      licenseNumber: _licenseNumberCtrl.text.trim(),
      agencyName: _agencyNameCtrl.text.trim(),
      yearsOfExperience: _yearsOfExpCtrl.text.trim(),
      companyDescription: _companyDescCtrl.text.trim(),
      officeAddress: _officeAddressCtrl.text.trim(),
      city: _cityCtrl.text.trim(),
      state: _stateCtrl.text.trim(),
      pincode: _pincodeCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      website: '',
      mobileNumber: _mobileCtrl.text.trim(),
      propertyTypes: _selectedPropertyTypes,
      operatingCities: [_cityCtrl.text.trim()],
    );

  if (!mounted) return;

  (await SharedPreferences.getInstance()).remove('pending_user_type');
  await context.read<AuthProvider>().refreshProfile();

  ScaffoldMessenger.of(context).showSnackBar(
  const SnackBar(
    content: Text('Broker profile saved successfully'),
  ),
);

await Future.delayed(
  const Duration(milliseconds: 800),
);

if (!mounted) return;

Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(
   builder: (_) => const RoleHomeRouter(),
  ),
  (route) => false,
);

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.toString()),
      ),
    );
  }
}

  // ─── Date Picker ──────────────────────────────────────────────────────────
  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      ctrl.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  // ─── Shared UI Helpers ────────────────────────────────────────────────────
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

  InputDecoration _inputDecoration(String label,
      {String? hint, Widget? suffix, Widget? prefix}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      prefixIcon: prefix,
      filled: true,
      fillColor:
          Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Theme.of(context).colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: Theme.of(context).colorScheme.error, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    Widget? suffixIcon,
    Widget? prefixIcon,
    bool readOnly = false,
    VoidCallback? onTap,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        obscureText: obscureText,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        decoration: _inputDecoration(
          required ? '$label *' : label,
          hint: hint,
          suffix: suffixIcon,
          prefix: prefixIcon,
        ),
        validator: validator ??
            (required
                ? (v) {
                    if (v == null || v.trim().isEmpty) {
                      return '$label is required';
                    }
                    return null;
                  }
                : null),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: _inputDecoration(required ? '$label *' : label),
        items: items
            .map((item) =>
                DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
        onChanged: onChanged,
        validator: required
            ? (v) =>
                (v == null || v.isEmpty) ? '$label is required' : null
            : null,
      ),
    );
  }

  Widget _buildUploadPlaceholder({
    required String label,
    required String currentPath,
    required VoidCallback onTap,
  }) {
    final hasFile = currentPath.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceVariant
                .withOpacity(0.4),
            border: Border.all(
              color: hasFile
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context)
                      .colorScheme
                      .outline
                      .withOpacity(0.4),
              width: hasFile ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                hasFile ? Icons.check_circle : Icons.upload_file,
                color: hasFile
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasFile
                      ? 'File selected'
                      : 'Tap to upload $label',
                  style: TextStyle(
                    color: hasFile
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                'Browse',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.url,
        decoration: _inputDecoration(label).copyWith(
          prefixIcon: Icon(icon, color: iconColor),
        ),
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
            Expanded(
              child: Text(
                _stepTitles[currentStep],
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentStep + 1} / ${_stepTitles.length}',
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onPrimaryContainer,
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
            backgroundColor:
                Theme.of(context).colorScheme.surfaceVariant,
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  // ─── Step 1 – Personal Information ───────────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Basic Information'),
          _buildTextField(
            controller: _fullNameCtrl,
            label: 'Full Name',
            required: true,
          ),
          _buildTextField(
            controller: _emailCtrl,
            label: 'Email',
            required: true,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => Validators.required(v) ?? Validators.email(v),
          ),
          _buildTextField(
            controller: _mobileCtrl,
            label: 'Mobile Number',
            required: true,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (v) => Validators.required(v) ?? Validators.phone(v),
          ),
          _buildTextField(
            controller: _altMobileCtrl,
            label: 'Alternate Mobile Number',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: Validators.phone,
          ),
          _buildDropdown(
            label: 'Gender',
            value: _selectedGender,
            items: ['Male', 'Female', 'Other', 'Prefer not to say'],
            onChanged: (v) => setState(() => _selectedGender = v),
          ),
          _buildTextField(
            controller: _dobCtrl,
            label: 'Date of Birth',
            hint: 'DD/MM/YYYY',
            readOnly: true,
            onTap: () => _pickDate(_dobCtrl),
            suffixIcon: const Icon(Icons.calendar_today_outlined),
          ),
          _buildSectionTitle('Profile Photo'),
          _buildUploadPlaceholder(
            label: 'Avatar / Profile Photo',
            currentPath: _avatarPath,
            onTap: () =>
                setState(() => _avatarPath = 'placeholder_avatar.jpg'),
          ),
        ],
      ),
    );
  }

  // ─── Step 2 – Broker Profile ──────────────────────────────────────────────
  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Professional Details'),
          _buildTextField(
            controller: _reraNumberCtrl,
            label: 'RERA Number',
            required: true,
            inputFormatters: [UpperCaseTextFormatter()],
          ),
          _buildTextField(
            controller: _licenseNumberCtrl,
            label: 'License Number',
            inputFormatters: [UpperCaseTextFormatter()],
          ),
          _buildTextField(
            controller: _agencyNameCtrl,
            label: 'Agency Name',
          ),
          _buildTextField(
            controller: _yearsOfExpCtrl,
            label: 'Years of Experience',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          _buildTextField(
            controller: _companyDescCtrl,
            label: 'Company Description',
            maxLines: 4,
            hint: 'Tell clients about your agency and expertise...',
          ),
        ],
      ),
    );
  }

  // ─── Step 3 – Address Information ────────────────────────────────────────
  Widget _buildStep3() {
    return Form(
      key: _step3Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Office Address'),
          _buildTextField(
            controller: _officeAddressCtrl,
            label: 'Office Address',
            maxLines: 2,
          ),
          _buildTextField(
            controller: _cityCtrl,
            label: 'City',
            required: true,
          ),
          _buildTextField(
            controller: _stateCtrl,
            label: 'State',
            required: true,
          ),
          _buildTextField(
            controller: _pincodeCtrl,
            label: 'Pincode',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: Validators.pincode,
          ),
          _buildTextField(
            controller: _landmarkCtrl,
            label: 'Landmark',
            hint: 'Near...',
          ),
        ],
      ),
    );
  }

  // ─── Step 4 – Business Details ────────────────────────────────────────────
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Property Types Handled'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allPropertyTypes.map((type) {
              final selected = _selectedPropertyTypes.contains(type);
              return FilterChip(
                label: Text(type),
                selected: selected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedPropertyTypes.add(type);
                    } else {
                      _selectedPropertyTypes.remove(type);
                    }
                  });
                },
                selectedColor: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                checkmarkColor:
                    Theme.of(context).colorScheme.onPrimaryContainer,
                labelStyle: TextStyle(
                  color: selected
                      ? Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.4),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        _buildTextField(
          controller: _serviceAreasCtrl,
          label: 'Service Areas',
          hint: 'e.g., Gurgaon, Noida, South Delhi',
          maxLines: 2,
        ),
        _buildSectionTitle('Pricing & Deal Type'),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _priceMinCtrl,
                label: 'Price Range Min (₹)',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTextField(
                controller: _priceMaxCtrl,
                label: 'Price Range Max (₹)',
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        _buildDropdown(
          label: 'Deal Type',
          value: _selectedDealType,
          items: ['Buy', 'Rent', 'Both'],
          onChanged: (v) => setState(() => _selectedDealType = v),
        ),
        _buildTextField(
          controller: _commissionCtrl,
          label: 'Commission Details',
          hint: 'e.g., 2% on sale, 1 month rent on rental',
          maxLines: 2,
        ),
        _buildTextField(
          controller: _availabilityCtrl,
          label: 'Availability Timing',
          hint: 'e.g., Mon–Sat, 9 AM – 7 PM',
        ),
      ],
    );
  }

  // ─── Step 5 – Documents ──────────────────────────────────────────────────
  Widget _buildStep5() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Identity Documents'),
        _buildUploadPlaceholder(
          label: 'Aadhaar Card',
          currentPath: _aadhaarPath,
          onTap: () =>
              setState(() => _aadhaarPath = 'aadhaar_card.pdf'),
        ),
        _buildUploadPlaceholder(
          label: 'PAN Card',
          currentPath: _panCardPath,
          onTap: () =>
              setState(() => _panCardPath = 'pan_card.pdf'),
        ),
        _buildSectionTitle('Professional Certificate'),
        _buildUploadPlaceholder(
          label: 'RERA Certificate',
          currentPath: _reraCertPath,
          onTap: () =>
              setState(() => _reraCertPath = 'rera_cert.pdf'),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .tertiaryContainer
                .withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Accepted formats: PDF, JPG, PNG. Max size: 10 MB per file.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Step 6 – Social Media ────────────────────────────────────────────────
  Widget _buildStep6() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Social Media Profiles'),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Add your profiles so potential clients can reach you easily.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        _buildSocialField(
          controller: _whatsappCtrl,
          label: 'WhatsApp',
          icon: Icons.chat_outlined,
          iconColor: const Color(0xFF25D366),
        ),
        _buildSocialField(
          controller: _facebookCtrl,
          label: 'Facebook',
          icon: Icons.facebook,
          iconColor: const Color(0xFF1877F2),
        ),
        _buildSocialField(
          controller: _instagramCtrl,
          label: 'Instagram',
          icon: Icons.camera_alt_outlined,
          iconColor: const Color(0xFFE1306C),
        ),
        _buildSocialField(
          controller: _linkedinCtrl,
          label: 'LinkedIn',
          icon: Icons.work_outline,
          iconColor: const Color(0xFF0A66C2),
        ),
        _buildSocialField(
          controller: _youtubeCtrl,
          label: 'YouTube',
          icon: Icons.play_circle_outline,
          iconColor: const Color(0xFFFF0000),
        ),
        _buildSocialField(
          controller: _telegramCtrl,
          label: 'Telegram',
          icon: Icons.send_outlined,
          iconColor: const Color(0xFF26A5E4),
        ),
      ],
    );
  }

 // ─── Step 7 Content ───────────────────────────────────────────────────────
Widget _buildStep7() {
  return Form(
    key: _step7Key,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Complete Registration'),

        _buildTextField(
          controller: _usernameCtrl,
          label: 'Username',
          required: true,
          hint: 'Choose a unique username',
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'Username is required';
            }

            if (v.trim().length < 3) {
              return 'Username must be at least 3 characters';
            }

            final usernameRegex =
                RegExp(r'^[a-zA-Z0-9_]+$');

            if (!usernameRegex.hasMatch(v.trim())) {
              return 'Only letters, numbers, and underscores allowed';
            }

            return null;
          },
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .primaryContainer
                .withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your account has already been created during Sign Up. '
                  'Complete your profile and submit registration to continue.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.6),
            ),
            children: [
              const TextSpan(
                text: 'By registering, you agree to our ',
              ),
              TextSpan(
                text: 'Terms of Service',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  // ─── Step content router ──────────────────────────────────────────────────
  Widget _buildCurrentStep() {
    switch (currentStep) {
      case 0:
        return _buildStep1();
      case 1:
        return _buildStep2();
      case 2:
        return _buildStep3();
      case 3:
        return _buildStep4();
      case 4:
        return _buildStep5();
      case 5:
        return _buildStep6();
      case 6:
        return _buildStep7();
      default:
        return const SizedBox();
    }
  }

  // ─── Bottom Navigation ────────────────────────────────────────────────────
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
                onPressed: _previousStep,
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: isLastStep ? _onSubmit : _nextStep,
              icon: Icon(
                isLastStep
                    ? Icons.check_circle_outline
                    : Icons.arrow_forward,
                size: 18,
              ),
              label:
                  Text(isLastStep ? 'Submit Registration' : 'Continue'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _mobileCtrl.dispose();
    _altMobileCtrl.dispose();
    _dobCtrl.dispose();
    _reraNumberCtrl.dispose();
    _licenseNumberCtrl.dispose();
    _agencyNameCtrl.dispose();
    _yearsOfExpCtrl.dispose();
    _companyDescCtrl.dispose();
    _officeAddressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _landmarkCtrl.dispose();
    _serviceAreasCtrl.dispose();
    _priceMinCtrl.dispose();
    _priceMaxCtrl.dispose();
    _commissionCtrl.dispose();
    _availabilityCtrl.dispose();
    _whatsappCtrl.dispose();
    _facebookCtrl.dispose();
    _instagramCtrl.dispose();
    _linkedinCtrl.dispose();
    _youtubeCtrl.dispose();
    _telegramCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }
}

// ─── Helper formatter ─────────────────────────────────────────────────────────
