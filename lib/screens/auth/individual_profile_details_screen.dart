import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_button.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_media_service.dart';
import 'individual_username_password_screen.dart';

/// Individual sign-up's completion step — the Flutter counterpart of the
/// portal's `ProfileCompletion.tsx` individual branch, field-for-field:
///
///   * Avatar — optional, via [ProfileMediaService], same upload path every
///     other registration screen already uses.
///   * Full Name — pre-filled from the current `display_name`, UNLESS it
///     looks like an email (the portal's `includes('@')` guard). That check
///     exists there specifically because a phone-first signup's
///     `display_name` falls back to the auto-generated `u<phone>@propcid.app`
///     placeholder (`send-otp/index.ts`'s `ensureUser` leaves `display_name`
///     unset when no name was collected at OTP time) — without the guard,
///     that placeholder would otherwise show up as a pre-filled "name".
///   * Phone Number — read-only once a real number is already on the
///     session (`auth.currentUser.phone`, set the moment phone-OTP sign-in
///     completes): "Phone number cannot be changed once set.", matching the
///     portal exactly. Only editable for a Google sign-in, which has no
///     phone on the auth user yet and still needs one collected.
///   * Location — a plain city text field, matching the portal.
///
/// No Username/Password here — the portal has those on its own separate
/// second step ("Set Username & Password"), reached via Continue below —
/// see [IndividualUsernamePasswordScreen], which is also where this
/// screen's fields actually get written.
///
/// Reached only from [AccountTypeScreen]'s "Individual" tile — Builder/
/// Broker/Influencer are untouched and still go straight to their existing
/// registration screens.
class IndividualProfileDetailsScreen extends StatefulWidget {
  const IndividualProfileDetailsScreen({required this.userId, super.key});

  final String userId;

  @override
  State<IndividualProfileDetailsScreen> createState() =>
      _IndividualProfileDetailsScreenState();
}

class _IndividualProfileDetailsScreenState
    extends State<IndividualProfileDetailsScreen> {
  static final RegExp _mobilePattern = RegExp(r'^[6-9]\d{9}$');

  final ProfileMediaService _mediaService = ProfileMediaService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final TextEditingController _cityCtrl = TextEditingController();

  /// True once a real number was already on the auth session at open time —
  /// i.e. this person signed up via phone OTP, not Google.
  late final bool _phoneIsLocked;

  String? _avatarUrl;
  bool _uploadingAvatar = false;

  String? _nameError;
  String? _phoneError;
  String? _cityError;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final displayName = auth.userName;
    // `ProfileCompletion.tsx`'s exact guard: a name that "looks like an
    // email" is a placeholder, not a real name, so it isn't pre-filled.
    final prefill = displayName.contains('@') ? '' : displayName;
    _nameCtrl = TextEditingController(text: prefill);
    _avatarUrl = auth.avatarUrl;

    // Same extraction builder_registration_screen.dart's initState already
    // uses for a phone-signup user: the number they just verified is on
    // `auth.currentUser.phone` (or embedded in the `u<phone>@propcid.app`
    // placeholder email for an older row). Blank for a Google sign-in, which
    // has no phone on the auth user yet.
    var phonePrefill = '';
    final authUser = Supabase.instance.client.auth.currentUser;
    final rawPhone = authUser?.phone;
    if (rawPhone != null && rawPhone.isNotEmpty) {
      final digits = rawPhone.replaceAll(RegExp(r'\D'), '');
      phonePrefill =
          digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    } else {
      final rawEmail = authUser?.email;
      if (rawEmail != null) {
        final m = RegExp(r'u(\d+)@').firstMatch(rawEmail);
        if (m != null) phonePrefill = m.group(1)!;
      }
    }
    _phoneIsLocked = phonePrefill.isNotEmpty;
    _phoneCtrl = TextEditingController(text: phonePrefill);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    setState(() => _uploadingAvatar = true);
    try {
      final file = await _mediaService.pickAvatar();
      if (file == null) return;
      final url = await _mediaService.uploadAvatar(
        userId: widget.userId,
        file: file,
      );
      if (!mounted) return;
      setState(() => _avatarUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not upload photo: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    final phoneDigits = _phoneCtrl.text.trim();
    final city = _cityCtrl.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'Please enter your name.' : null;
      _phoneError = _mobilePattern.hasMatch(phoneDigits)
          ? null
          : 'Please enter a valid 10-digit mobile number.';
      _cityError = city.isEmpty ? 'Please enter your city.' : null;
    });
    if (_nameError != null || _phoneError != null || _cityError != null) {
      return;
    }

    // Nothing is written yet — the portal's own second step ("Set Username &
    // Password") is a separate screen from this one, so the actual
    // `profiles` write (plus setting the real password) happens there. This
    // screen only validates and carries the collected fields forward.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IndividualUsernamePasswordScreen(
          userId: widget.userId,
          name: name,
          phoneDigits: phoneDigits,
          city: city,
          avatarUrl: _avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Complete your profile',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Just a couple more details to get you started.',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Center(child: _avatarPicker()),
              const SizedBox(height: 28),
              const Text(
                'Full Name',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Your full name',
                  errorText: _nameError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Phone Number',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _phoneCtrl,
                enabled: !_phoneIsLocked,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: '+91  ',
                  counterText: '',
                  hintText: '10-digit mobile number',
                  errorText: _phoneError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: _phoneIsLocked,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              if (_phoneIsLocked) ...[
                const SizedBox(height: 4),
                Text(
                  'Phone number cannot be changed once set.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _cityCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Enter your city',
                  errorText: _cityError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 28),
              PremiumButton(
                label: 'Continue',
                isLoading: false,
                onPressed: _submit,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarPicker() {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
          child: _uploadingAvatar
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : (_avatarUrl == null
                  ? Icon(Icons.person, size: 40, color: AppColors.primary)
                  : null),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _uploadingAvatar ? null : _pickAndUploadAvatar,
          icon: const Icon(Icons.upload_outlined, size: 18),
          label: const Text('Upload Photo'),
        ),
      ],
    );
  }
}
