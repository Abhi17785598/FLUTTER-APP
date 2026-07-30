import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/validation/validators.dart';
import 'edge_functions_service.dart';

/// What the user typed into the single "email, phone or username" field.
enum IdentifierKind { email, phone, username }

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final EdgeFunctionsService _functions = EdgeFunctionsService();

  /// Stream of Auth State changes
  Stream<AuthState> get onAuthStateChange => _supabase.auth.onAuthStateChange;

  /// Current active session
  Session? get currentSession => _supabase.auth.currentSession;

  /// Current active user
  User? get currentUser => _supabase.auth.currentUser;

  /// Login with email and password
  Future<AuthResponse> login(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  /// Resolves whatever the user typed (email, phone, or username) to an
  /// email, then signs in — Supabase can only authenticate with email/password.
  Future<AuthResponse> loginWithIdentifier(
    String identifier,
    String password,
  ) async {
    final value = identifier.trim();
    final String? email;
    switch (kindOf(value)) {
      case IdentifierKind.email:
        email = value;
        break;
      case IdentifierKind.phone:
        email = await getEmailByPhone(value);
        break;
      case IdentifierKind.username:
        email = await getEmailByUsername(value);
        break;
    }

    if (email == null || email.isEmpty) {
      throw 'No account found for those details.';
    }
    return login(email, password);
  }

  /// `@` → email, all digits (allowing spaces/dashes/`+`) → phone,
  /// otherwise username.
  static IdentifierKind kindOf(String raw) {
    final value = raw.trim();
    if (value.contains('@')) return IdentifierKind.email;
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10 &&
        digits.length == value.replaceAll(RegExp(r'[\s+\-()]'), '').length) {
      return IdentifierKind.phone;
    }
    return IdentifierKind.username;
  }

  Future<String?> getEmailByPhone(String phone) async {
    try {
      final result = await _supabase.rpc(
        'get_email_by_phone',
        params: {'p_phone': Validators.toE164(phone)},
      );
      return result as String?;
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  Future<String?> getEmailByUsername(String username) async {
    try {
      final result = await _supabase.rpc(
        'get_email_by_username',
        params: {'p_username': username.trim().toLowerCase()},
      );
      return result as String?;
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  /// Sign up with role and type
  Future<AuthResponse> signUp(
    String email,
    String password,
    String name, {
    String role = 'buyer',
    String type = 'individual',
  }) async {
    try {
      return await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'display_name': name.trim()},
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  // ── Phone OTP (MSG91 via the send-otp edge function) ──────────────────────
  //
  // Supabase's own phone auth is deliberately NOT used: the project's SMS goes
  // through MSG91 inside the edge function, and `otp_verifications` is the
  // store of record on the backend.

  Future<void> sendOtp(String phone) async {
    try {
      await _functions.sendOtp(Validators.toE164(phone));
    } catch (e) {
      throw e is String ? e : 'A network error occurred. Please try again.';
    }
  }

  Future<void> resendOtp(String phone) async {
    try {
      await _functions.resendOtp(Validators.toE164(phone));
    } catch (e) {
      throw e is String ? e : 'A network error occurred. Please try again.';
    }
  }

  /// Verifies the code **and establishes the session**.
  ///
  /// Two steps, because the edge function cannot mint a session for a caller
  /// that does not have one yet:
  /// 1. `send-otp` `verify` → checks the OTP, creates the auth user if the
  ///    phone is new, returns a magic-link `hashed_token`.
  /// 2. `verifyOTP(type: magiclink, tokenHash: …)` → exchanges that token for
  ///    a session, with no browser round-trip.
  Future<void> verifyOtp({
    required String phone,
    required String otp,
    String? name,
  }) async {
    Map<String, dynamic> data;
    try {
      data = await _functions.verifyOtp(
        phoneNumber: Validators.toE164(phone),
        otp: otp.trim(),
        name: name,
      );
    } catch (e) {
      throw e is String ? e : 'A network error occurred. Please try again.';
    }

    final hashedToken = data['hashed_token'] as String?;
    if (hashedToken == null) {
      throw data['error']?.toString() ?? 'That code could not be verified.';
    }

    try {
      await _supabase.auth.verifyOTP(
        type: OtpType.magiclink,
        tokenHash: hashedToken,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  /// Google Sign In
  Future<bool> signInWithGoogle() async {
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb
            ? Uri.base.origin
            : 'io.supabase.flutter://login-callback',
      );

      return true;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      return false;
    }
  }

  Future<void> updateProfileData({
    required String name,
    required String role,
    required String type,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User not logged in');
    }

    await _supabase
        .from('profiles')
        .update({
          'display_name': name,
          'email': user.email,
          'user_role': role,
          'user_type': type,
        })
        .eq('user_id', user.id);
  }

  /// Update profile with additional fields (for profile completion)
  Future<void> updateProfileFields(
    String userId,
    Map<String, dynamic> profileData,
  ) async {
    try {
      await _supabase
          .from('profiles')
          .update(profileData)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('Error updating profile fields: $e');
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('Logout error: $e');
    }
  }

  /// Forgot password
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb ? null : 'propcid://reset-password',
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  /// Exchanges a recovery `token_hash` from the reset-password deep link for
  /// a session, which is what makes the subsequent [updatePassword] call
  /// legal. Not needed when `supabase_flutter` has already established the
  /// session itself from the incoming link (the common case).
  Future<void> verifyRecoveryToken(String tokenHash) async {
    try {
      await _supabase.auth.verifyOTP(
        type: OtpType.recovery,
        tokenHash: tokenHash,
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  /// Update password
  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  /// Load profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      return await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  String _mapAuthException(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'email_not_confirmed':
        return 'Please verify your email.';
      case 'user_not_found':
        return 'No account found.';
      case 'email_exists':
        return 'Email already registered.';
      case 'weak_password':
        return 'Password must be at least 6 characters.';
      default:
        return e.message;
    }
  }
}
