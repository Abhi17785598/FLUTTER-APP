import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/premium_button.dart';
import '../../providers/auth_provider.dart';
import 'auth_post_login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _headerController;
  late Animation<double> _logoAnimation;
  late Animation<double> _text1Animation;
  late Animation<double> _text2Animation;

  // Login controllers
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginPasswordVisible = false;

  // Sign Up controllers
  //
  // No password/confirm-password here — the account is created with a
  // securely random placeholder password (never seen by anyone) and the
  // person's actual chosen password is now collected later, alongside
  // Username, on the registration form's Account Setup step (Builder/Broker/
  // Influencer) via Supabase's own updateUser(password:).
  final _signUpNameCtrl = TextEditingController();
  final _signUpEmailCtrl = TextEditingController();

  // Phone controllers
  final _phoneNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Role & Type selection
  String? _selectedRole;
  String? _selectedType;

  static const List<String> _roles = ['buyer', 'seller'];
  static const List<String> _sellerTypes = ['builder', 'broker', 'influencer'];

  bool _isLoading = false;
  bool _googleAuthPending = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );

    _text1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );

    _text2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _headerController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );

    _headerController.forward();

    // Register a listener that routes after Google OAuth completes.
    // Fires for every AuthProvider change but only acts when _googleAuthPending.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AuthProvider>().addListener(_onGoogleAuthChanged);
      }
    });
  }

  @override
  void dispose() {
    context.read<AuthProvider>().removeListener(_onGoogleAuthChanged);
    _tabController.dispose();
    _headerController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signUpNameCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _phoneNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // Fires when AuthProvider notifies. Only acts if Google OAuth is in progress.
  // Email login is unaffected because _googleAuthPending stays false for it.
  void _onGoogleAuthChanged() {
    if (!_googleAuthPending || !mounted) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) return;
    setState(() => _googleAuthPending = false);
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) routeAfterAuth(context, userId);
  }

  // ─── Validation ───────────────────────────────────────────

  Future<void> _handleForgotPassword() async {
    final email = _loginEmailCtrl.text.trim();
    if (email.isEmpty) {
      _showSnackBar(
        'Enter your email address above, then tap Forgot password.',
        isError: true,
      );
      return;
    }
    setState(() => _isLoading = true);
    final error = await context.read<AuthProvider>().resetPassword(email);
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (error != null) {
      _showSnackBar('Could not send reset email: $error', isError: true);
    } else {
      _showSnackBar(
        'Password reset email sent. Check your inbox.',
        isError: false,
      );
    }
  }

  String? _validateLogin() {
    // The field accepts an email, phone number or username, so only presence
    // is required here — AuthService resolves whichever was typed.
    final idErr = Validators.required(_loginEmailCtrl.text);
    if (idErr != null) return idErr;
    if (_loginPasswordCtrl.text.isEmpty) return 'Password is required.';
    if (_loginPasswordCtrl.text.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    return null;
  }

  String? _validatePhoneForm() {
    return Validators.required(_phoneCtrl.text) ??
        Validators.phone(_phoneCtrl.text);
  }

  /// A password nobody ever needs to know, type or remember — it only exists
  /// to satisfy Supabase's `signUp(email, password)` API, which cannot create
  /// an email account without one. `Random.secure()` is a CSPRNG, matching
  /// `PaymentService.newIdempotencyKey()`'s reasoning for the same primitive.
  String _generatePlaceholderPassword() {
    final random = Random.secure();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String? _validateSignUp() {
    if (_signUpNameCtrl.text.trim().isEmpty) return 'Full name is required.';
    final signUpEmailErr =
        Validators.required(_signUpEmailCtrl.text) ??
        Validators.email(_signUpEmailCtrl.text);
    if (signUpEmailErr != null) return signUpEmailErr;
    if (_selectedRole == null) {
      return 'Please select a role.';
    }

    if (_selectedRole == 'seller' && _selectedType == null) {
      return 'Please select a user type.';
    }

    return null;
  }

  // ─── Handlers ─────────────────────────────────────────────

  Future<void> _handleLogin() async {
    final validationError = _validateLogin();
    if (validationError != null) {
      _showSnackBar(validationError, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    final error = await context.read<AuthProvider>().login(
      _loginEmailCtrl.text.trim(),
      _loginPasswordCtrl.text,
    );
    setState(() => _isLoading = false);
    if (error != null) {
      _showSnackBar(error, isError: true);
    } else {
      if (!mounted) return;
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) await routeAfterAuth(context, userId);
    }
  }

  Future<void> _handleSendOtp() async {
    final validationError = _validatePhoneForm();
    if (validationError != null) {
      _showSnackBar(validationError, isError: true);
      return;
    }
    setState(() => _isLoading = true);
    final error = await context.read<AuthProvider>().sendOtp(
      _phoneCtrl.text.trim(),
    );
    setState(() => _isLoading = false);
    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }
    if (!mounted) return;
    final name = _phoneNameCtrl.text.trim();
    await Navigator.pushNamed(
      context,
      '/auth-otp',
      arguments: {
        'phone': Validators.toE164(_phoneCtrl.text.trim()),
        if (name.isNotEmpty) 'name': name,
      },
    );
  }

  Future<void> _handleSignUp() async {
    final validationError = _validateSignUp();
    if (validationError != null) {
      _showSnackBar(validationError, isError: true);
      return;
    }

    // Persist the selected type now so it survives email confirmation + re-open + sign-in.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_user_type', _selectedType ?? 'individual');

    // No password is collected here anymore — Supabase's email signUp still
    // requires one to create the account, so a securely random placeholder
    // is used. Nobody is ever shown it or expected to know it: the person's
    // real, chosen password is set later via Supabase's updateUser(password:)
    // on the registration form's Account Setup step, alongside Username.
    final placeholderPassword = _generatePlaceholderPassword();

    setState(() => _isLoading = true);
    final error = await context.read<AuthProvider>().signUp(
      _signUpNameCtrl.text.trim(),
      _signUpEmailCtrl.text.trim(),
      placeholderPassword,
      placeholderPassword,
      role: _selectedRole!,
      type: _selectedType ?? 'individual',
    );
    setState(() => _isLoading = false);

    if (error == '__email_confirmation_required__') {
      _showSnackBar(
        'Account created! Please check your email to confirm your address, then sign in.',
        isError: false,
      );
      return;
    }
    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }

    // Signup returned a session immediately (email confirmation disabled in Supabase).
    if (!mounted) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) await routeAfterAuth(context, userId);
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Colors.red.shade700
            : AppColors.verifiedBadge,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ─── Root Build ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0EEFF), Color(0xFFF4F4F8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildTabBar(),
                const SizedBox(height: 24),
                // Use AnimatedBuilder to rebuild tab content on tab switch
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    switch (_tabController.index) {
                      case 0:
                        return _buildLoginForm();
                      case 1:
                        return _buildSignUpForm();
                      default:
                        return _buildPhoneForm();
                    }
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────

  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _headerController,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Transform.scale(
              scale: _logoAnimation.value,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppColors.primaryGlow,
                ),
                child: const Icon(
                  Icons.home_work_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _text1Animation,
              child: const Text(
                'Find your perfect',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            FadeTransition(
              opacity: _text2Animation,
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  children: [
                    TextSpan(
                      text: 'property ',
                      style: TextStyle(color: AppColors.primary),
                    ),
                    TextSpan(text: '🏡'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _text2Animation,
              child: const Text(
                'Login or create an account to get started',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── Tab Bar ──────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      height: 62,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF5B50E8)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(14),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: const [
          Tab(text: 'Login'),
          Tab(text: 'Sign Up'),
          Tab(text: 'Phone'),
        ],
      ),
    );
  }

  // ─── Login Form ───────────────────────────────────────────

  Widget _buildLoginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _loginEmailCtrl,
          label: 'Email, phone or username',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _loginPasswordCtrl,
          label: 'Password',
          hint: '••••••••',
          icon: Icons.lock_outline,
          isPassword: true,
          passwordVisible: _loginPasswordVisible,
          onTogglePassword: () =>
              setState(() => _loginPasswordVisible = !_loginPasswordVisible),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _isLoading ? null : _handleForgotPassword,
            child: const Text(
              'Forgot password?',
              style: TextStyle(color: AppColors.primary, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildPrimaryButton(
          label: 'Login',
          onPressed: _isLoading ? null : _handleLogin,
        ),
        const SizedBox(height: 20),
        _buildDivider(),
        const SizedBox(height: 16),
        _buildGoogleButton(),
      ],
    );
  }

  // ─── Sign Up Form ─────────────────────────────────────────

  Widget _buildSignUpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _signUpNameCtrl,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _signUpEmailCtrl,
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                label: 'Role',
                value: _selectedRole,
                items: _roles,
                hint: 'Select role',
                icon: Icons.badge_outlined,
                onChanged: (val) {
                  setState(() {
                    _selectedRole = val;

                    if (val == 'buyer') {
                      _selectedType = 'individual';
                    } else {
                      _selectedType = null;
                    }
                  });
                },
              ),
            ),

            if (_selectedRole == 'seller') ...[
              const SizedBox(width: 12),

              Expanded(
                child: _buildDropdown(
                  label: 'User Type',
                  value: _selectedType,
                  items: _sellerTypes,
                  hint: 'Select type',
                  icon: Icons.category_outlined,
                  onChanged: (val) {
                    setState(() {
                      _selectedType = val;
                    });
                  },
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 22),
        _buildPrimaryButton(
          label: 'Create Account',
          onPressed: _isLoading ? null : _handleSignUp,
        ),
        const SizedBox(height: 20),
        _buildDivider(),
        const SizedBox(height: 16),
        _buildGoogleButton(),
      ],
    );
  }

  // ─── Phone Form ───────────────────────────────────────────
  // One unified entry point regardless of sign-in vs sign-up: the backend
  // creates the account if the phone is new, or logs the user in if it
  // already exists — there is no separate "phone sign up" step.

  Widget _buildPhoneForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _phoneNameCtrl,
          label: 'Name (new accounts only)',
          hint: 'Enter your full name',
          icon: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _phoneCtrl,
          label: 'Phone number',
          hint: '10-digit mobile number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 4),
        const Text(
          'We will text you a 6-digit code.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 18),
        _buildPrimaryButton(
          label: 'Send OTP',
          onPressed: _isLoading ? null : _handleSendOtp,
        ),
      ],
    );
  }

  // ─── Shared Widgets ───────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool passwordVisible = false,
    VoidCallback? onTogglePassword,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword && !passwordVisible,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: AppColors.textHint,
                fontSize: 14,
              ),
              prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
              suffixIcon: isPassword
                  ? IconButton(
                      onPressed: onTogglePassword,
                      icon: Icon(
                        passwordVisible
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required String hint,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              hint: Row(
                children: [
                  Icon(icon, color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      hint,
                      style: const TextStyle(
                        color: AppColors.textHint,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        _formatDropdownLabel(item),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDropdownLabel(String value) {
    return value
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return PremiumButton(
      label: label,
      onPressed: onPressed,
      isLoading: _isLoading,
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: () async {
          final error = await context.read<AuthProvider>().signInWithGoogle();
          if (error != null) {
            if (mounted) _showSnackBar(error, isError: true);
          } else {
            // Browser opened. Session arrives via auth state stream.
            // _onGoogleAuthChanged will fire and call routeAfterAuth when ready.
            setState(() => _googleAuthPending = true);
          }
        },
        icon: const Text(
          'G',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
          ),
        ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: Colors.grey.shade300),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }
}
