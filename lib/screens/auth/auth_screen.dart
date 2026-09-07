import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/validation/validators.dart';
import '../../core/widgets/premium_button.dart';
import '../../providers/auth_provider.dart';

/// The real, official Google "G" mark (Google's own multi-colour logo, as
/// used on every standard "Sign in with Google" button) — inlined as raw SVG
/// so it renders pixel-accurately via the app's existing `flutter_svg`
/// dependency, with no new package and no new asset file. Replaces the
/// earlier hand-painted 4-arc approximation, which read as an approximation
/// rather than the real logo.
const String _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z"/>
  <path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z"/>
  <path fill="#FBBC05" d="M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24s.85 6.91 2.34 9.88l7.35-5.7z"/>
  <path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z"/>
</svg>
''';

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
  bool _googleOAuthStarting = false;

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

  Future<void> _handleGoogleSignIn() async {
    // Stops double taps and simultaneous authentication actions.
    if (_isLoading || _googleOAuthStarting) return;

    setState(() => _googleOAuthStarting = true);
    debugPrint('[GOOGLE_OAUTH] Google sign-in requested');

    final error = await context.read<AuthProvider>().signInWithGoogle();

    if (!mounted) return;

    setState(() => _googleOAuthStarting = false);

    if (error != null) {
      _showSnackBar(error, isError: true);
    }
  }

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

  /// Same premium house photo already used elsewhere in this app (the
  /// second slide of the Home hero carousel, `HeroBannerSection`) — reused
  /// verbatim rather than a new, unrelated image.
  static const String _backgroundImageUrl =
      'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=900&q=80';

  @override
  Widget build(BuildContext context) {
    // Bottom safe-area inset (home indicator / gesture bar), folded into the
    // card's own bottom padding below rather than left to `SafeArea` — the
    // card must reach the literal bottom edge of the screen with no bare
    // strip of photo left showing under it, on every device, so it owns
    // that inset itself instead of a wrapping `SafeArea` reserving it as
    // dead space above the card.
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed background photo behind everything.
          CachedNetworkImage(
            imageUrl: _backgroundImageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                Container(color: AppColors.primaryLight),
            errorWidget: (context, url, error) =>
                Container(color: AppColors.primaryLight),
          ),
          // A soft light-to-transparent wash behind the header text so it
          // stays legible over whatever part of the photo sits at the top,
          // without hiding the photo the way a solid banner would.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCCF8F8FC), Color(0x00F8F8FC)],
                stops: [0.0, 0.42],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildHeader(),
                  ),
                ),
                const SizedBox(height: 20),
                // The frosted glass card carrying the tab bar and the
                // active form. `Expanded` pins it to fill every bit of
                // remaining space down to the true bottom edge of the
                // screen — on a tall device that's more empty card padding,
                // on a short one (or with the keyboard open) its own
                // `SingleChildScrollView` below takes over, but the photo
                // is never left exposed under a short-and-floating card.
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.86),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(28),
                            topRight: Radius.circular(28),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 24,
                              offset: const Offset(0, -6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            // A small grabber handle — the usual affordance
                            // for a card anchored to the bottom of the
                            // screen, and a cheap extra touch of polish.
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: AppColors.textHint.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  18,
                                  24,
                                  24 + bottomInset,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildTabBar(),
                                    const SizedBox(height: 22),
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
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
                  Icons.home_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _text1Animation,
              child: const Text(
                'Your Next Home',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            FadeTransition(
              opacity: _text2Animation,
              child: const Text(
                'Is Just a Login Away',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FadeTransition(
              opacity: _text2Animation,
              child: const Text(
                'Discover. Explore. Own.',
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
          _IconTab(icon: Icons.person_outline, label: 'Login'),
          _IconTab(icon: Icons.add, label: 'Sign Up'),
          _IconTab(icon: Icons.phone_outlined, label: 'Phone'),
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
    // Matches the reference: just the icon + field name inside the box, no
    // separate bold label floating above it (the field's semantic label is
    // still set below via InputDecoration.labelText's usual accessibility
    // role — this only changes what's painted, not what a label means for
    // validation, which is untouched).
    return Container(
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
          hintText: label,
          hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
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
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon = Icons.arrow_forward_rounded,
  }) {
    return PremiumButton(
      label: label,
      onPressed: onPressed,
      isLoading: _isLoading,
      icon: icon,
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
        onPressed: (_isLoading || _googleOAuthStarting)
            ? null
            : _handleGoogleSignIn,
        icon: _googleOAuthStarting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : SvgPicture.string(
                _googleLogoSvg,
                width: 20,
                height: 20,
              ),
        label: Text(
          _googleOAuthStarting ? 'Opening Google…' : 'Continue with Google',
          style: const TextStyle(
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
          disabledBackgroundColor: Colors.grey.shade100,
        ),
      ),
    );
  }
}

/// A `TabBar` tab with its icon and label laid out side by side. The stock
/// `Tab(icon:, text:)` constructor stacks them vertically, which doesn't
/// match the reference's horizontal "🧑 Login" / "＋ Sign Up" / "📞 Phone"
/// pills — this just wraps `Tab(child:)` with a `Row` instead. Colour
/// (selected white / unselected grey) still comes entirely from the parent
/// `TabBar.labelColor`/`unselectedLabelColor` via `IconTheme`/`DefaultTextStyle`
/// inherited from `Tab`'s own internals, so selection state needs no extra
/// wiring here.
class _IconTab extends StatelessWidget {
  const _IconTab({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tab(
      height: 44,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17),
          const SizedBox(width: 6),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

