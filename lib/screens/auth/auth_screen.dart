import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/premium_button.dart';
import '../../providers/auth_provider.dart';

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

  // Sign Up — email only, portal parity. No name/password/role/type here:
  // Supabase's own `signInWithOtp(shouldCreateUser: true)` both creates the
  // account (if new) and signs in (if existing) with a magic link, and Full
  // Name + User Type are collected afterwards, once the link is confirmed
  // and a real session exists — see AccountTypeScreen.
  final _signUpEmailCtrl = TextEditingController();
  bool _signUpEmailSent = false;
  String? _signUpSentTo;

  // Phone controllers
  final _phoneNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _isLoading = false;

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

    // A blocked-account sign-out (AuthProvider.handleBlockedAccount) lands
    // here — surface its message through the same snackbar every other
    // auth failure already uses, rather than a new screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blockedMessage = AuthProvider.consumeBlockedMessage();
      if (blockedMessage != null && mounted) {
        _showSnackBar(blockedMessage, isError: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _headerController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signUpEmailCtrl.dispose();
    _phoneNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
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
    // Email or username only — phone sign-in lives on the Phone tab and is
    // never password-based (see AuthService.loginWithIdentifier).
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

  String? _validateSignUpEmail() {
    return Validators.required(_signUpEmailCtrl.text) ??
        Validators.email(_signUpEmailCtrl.text);
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
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (error != null) {
      _showSnackBar(error, isError: true);
    }
    // On success, AuthProvider's own auth-stream listener resolves the
    // destination and navigates — this screen does not decide where to go.
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
    final validationError = _validateSignUpEmail();
    if (validationError != null) {
      _showSnackBar(validationError, isError: true);
      return;
    }
    final email = _signUpEmailCtrl.text.trim();
    setState(() => _isLoading = true);
    final error = await context.read<AuthProvider>().signUpWithEmail(email);
    setState(() => _isLoading = false);
    if (error != null) {
      _showSnackBar(error, isError: true);
      return;
    }
    setState(() {
      _signUpEmailSent = true;
      _signUpSentTo = email;
    });
  }

  Future<void> _handleResendSignUpEmail() async {
    final email = _signUpSentTo;
    if (email == null) return;
    setState(() => _isLoading = true);
    final error = await context.read<AuthProvider>().signUpWithEmail(email);
    setState(() => _isLoading = false);
    if (!mounted) return;
    if (error != null) {
      _showSnackBar(error, isError: true);
    } else {
      _showSnackBar('Confirmation email resent.', isError: false);
    }
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
          label: 'Email or Username',
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
  // Portal parity: email only. Full Name + User Type are collected after
  // the magic link is confirmed and a session exists (AccountTypeScreen) —
  // there is no role/type choice here, and never a Buyer/Seller one.

  Widget _buildSignUpForm() {
    if (_signUpEmailSent) {
      return _buildSignUpConfirmationState();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          controller: _signUpEmailCtrl,
          label: 'Email',
          hint: 'you@example.com',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
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

  Widget _buildSignUpConfirmationState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.mark_email_read_outlined,
          size: 48,
          color: AppColors.primary,
        ),
        const SizedBox(height: 16),
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a confirmation link to ${_signUpSentTo ?? ''}. Tap it on this device to continue.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _isLoading ? null : _handleResendSignUpEmail,
            child: Text(
              _isLoading ? 'Sending…' : 'Resend email',
              style: const TextStyle(color: AppColors.primary, fontSize: 13),
            ),
          ),
        ),
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
          if (error != null && mounted) {
            _showSnackBar(error, isError: true);
          }
          // Browser opened on success. The session arrives later via the
          // auth state stream — AuthProvider is the sole owner of what
          // happens next; this screen does not track a "pending" flag or
          // navigate itself.
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
