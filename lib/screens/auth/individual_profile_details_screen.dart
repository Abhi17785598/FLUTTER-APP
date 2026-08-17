import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/premium_button.dart';
import '../../providers/auth_provider.dart';
import '../home/home_screen.dart';

/// Individual sign-up's name + phone step — the Flutter counterpart of the
/// portal's `ProfileCompletion.tsx`, field-for-field:
///
///   * Full Name — pre-filled from the current `display_name`, UNLESS it
///     looks like an email (`ProfileCompletion.tsx:160`'s `includes('@')`
///     guard). That check exists there specifically because a phone-first
///     signup's `display_name` falls back to the auto-generated
///     `u<phone>@propcid.app` placeholder (`send-otp/index.ts`'s `ensureUser`
///     leaves `display_name` unset when no name was collected at OTP time) —
///     without the guard, that placeholder would otherwise show up as a
///     pre-filled "name". Reproduced here identically.
///   * Phone Number — a plain text field, `^[6-9]\d{9}$` (India, no leading
///     0/1-5 — `ProfileCompletion.tsx`'s `PATTERNS.MOBILE`), NOT an OTP step.
///     The portal never verifies this number by SMS at profile-completion
///     time; it is collected exactly like every other text field on the form.
///     (An OTP-based version of this screen was tried and reverted — the
///     shared `send-otp` function's `verify` action unconditionally creates a
///     phantom `auth.users`/`profiles` row for any number it hasn't seen
///     before, which is a fine trade-off for an actual sign-in but not for
///     "type your number so we have it on file". Matching the portal's own
///     plain-text approach avoids that entirely.)
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

  late final TextEditingController _nameCtrl;
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _isSaving = false;
  String? _nameError;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    final displayName = context.read<AuthProvider>().userName;
    // `ProfileCompletion.tsx:160`'s exact guard: a name that "looks like an
    // email" is a placeholder, not a real name, so it isn't pre-filled.
    final prefill = displayName.contains('@') ? '' : displayName;
    _nameCtrl = TextEditingController(text: prefill);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final phoneDigits = _phoneCtrl.text.trim();

    setState(() {
      _nameError = name.isEmpty ? 'Please enter your name.' : null;
      _phoneError = _mobilePattern.hasMatch(phoneDigits)
          ? null
          : 'Please enter a valid 10-digit mobile number.';
    });
    if (_nameError != null || _phoneError != null) return;

    setState(() => _isSaving = true);
    try {
      await Supabase.instance.client.from('profiles').update({
        'display_name': name,
        'user_type': 'individual',
        'profile_complete': true,
        'phone': '+91$phoneDigits',
      }).eq('user_id', widget.userId);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_user_type');

      if (!mounted) return;
      await context.read<AuthProvider>().refreshProfile();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
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
              const SizedBox(height: 32),
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
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: '+91  ',
                  counterText: '',
                  hintText: '10-digit mobile number',
                  errorText: _phoneError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 28),
              PremiumButton(
                label: 'Continue',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
