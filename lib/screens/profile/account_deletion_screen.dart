// screens/profile/account_deletion_screen.dart
//
// Requests account deletion — a port of pages/AccountDeletion.tsx.
//
// IT FILES A REQUEST; IT DOES NOT DELETE.
// The portal inserts a row into `account_deletion_requests` with `status:
// 'pending'` for a human to process. Nothing is removed at the moment of
// submission, and the copy says so explicitly rather than implying otherwise.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/validation/validators.dart';
import '../../widgets/shared/app_action_button.dart';
import '../../widgets/shared/app_surface_card.dart';

class AccountDeletionScreen extends StatefulWidget {
  const AccountDeletionScreen({super.key});

  @override
  State<AccountDeletionScreen> createState() => _AccountDeletionScreenState();
}

class _AccountDeletionScreenState extends State<AccountDeletionScreen> {
  final _email = TextEditingController();
  final _phone = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    final messenger = ScaffoldMessenger.of(context);

    // AccountDeletion.tsx:23 — either identifier will do, but not neither.
    if (email.isEmpty && phone.isEmpty) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Enter your registered email or phone number.'),
          ),
        );
      return;
    }

    final emailError = Validators.email(email);
    if (emailError != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(emailError)));
      return;
    }

    setState(() => _submitting = true);

    try {
      // Exactly the portal's payload (AccountDeletion.tsx:36-41). Nulls rather
      // than empty strings, so a blank field is absent rather than matching "".
      await Supabase.instance.client.from('account_deletion_requests').insert({
        'email': email.isEmpty ? null : email,
        'phone': phone.isEmpty ? null : phone,
        'status': 'pending',
      });

      if (!mounted) return;
      setState(() => _submitted = true);
    } catch (e) {
      if (!mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not submit your request. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Account deletion',
          style: AppTextStyles.heading3.copyWith(fontSize: 16),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: ColoredBox(
            color: AppColors.hairline,
            child: SizedBox(height: 1),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: _submitted ? _success() : _form(),
      ),
    );
  }

  Widget _success() => DashboardCard(
    child: Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 26,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppConstants.spacingL),
        Text(
          'Request submitted',
          style: AppTextStyles.heading3.copyWith(fontSize: 15),
        ),
        const SizedBox(height: AppConstants.spacingS),
        Text(
          'Your request will be processed within 30 days. Some records may '
          'be retained where the law requires it.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(fontSize: 12.5, height: 1.5),
        ),
      ],
    ),
  );

  Widget _form() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 6),
                Text(
                  'This action is permanent',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingM),
            const DashboardCardTitle('Request account deletion'),
            const SizedBox(height: 6),
            Text(
              'Confirm the email or phone number you registered with. We will '
              'use it to find your account.',
              style: AppTextStyles.caption.copyWith(
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            _label('Registered email'),
            const SizedBox(height: 6),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              style: AppTextStyles.body.copyWith(fontSize: 14),
              decoration: const InputDecoration(hintText: 'you@example.com'),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Center(
              child: Text(
                'OR',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHint,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            _label('Registered phone'),
            const SizedBox(height: 6),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              style: AppTextStyles.body.copyWith(fontSize: 14),
              decoration: const InputDecoration(hintText: 'Phone number'),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppConstants.spacingL),
      DashboardCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DashboardSectionLabel('What happens next'),
            const SizedBox(height: AppConstants.spacingS),
            // AccountDeletion.tsx:142-147, same four points.
            for (final line in const [
              'Your request is reviewed by our team.',
              'Processing takes up to 30 days.',
              'You will receive a confirmation once it is done.',
              'Some data may be retained where the law requires it.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•  ',
                      style: AppTextStyles.caption.copyWith(fontSize: 12.5),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: AppConstants.spacingL),
      AppActionButton(
        label: _submitting ? 'Submitting…' : 'Submit request',
        variant: AppActionButtonVariant.danger,
        height: 46,
        onTap: _submitting ? null : _submit,
      ),
    ],
  );

  Widget _label(String text) => Text(
    text,
    style: AppTextStyles.caption.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );
}
