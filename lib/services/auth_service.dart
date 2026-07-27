import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Stream of Auth State changes
  Stream<AuthState> get onAuthStateChange =>
      _supabase.auth.onAuthStateChange;

  /// Current active session
  Session? get currentSession =>
      _supabase.auth.currentSession;

  /// Current active user
  User? get currentUser =>
      _supabase.auth.currentUser;

  /// Login with email and password
  Future<AuthResponse> login(
    String email,
    String password,
  ) async {
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

  /// Sign up with role and type
  Future<AuthResponse> signUp(
    String email,
    String password,
    String name, {
    String role = 'buyer',
    String type = 'individual',
  }) async {
    print('=== AUTH_SERVICE.signUp: entering ===');
    print('email: $email, role: $role, type: $type');
    try {
      final authResponse = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'display_name': name.trim(),
        },
      );

      print('=== AUTH_SERVICE.signUp: response received ===');
      print('user id: ${authResponse.user?.id}');
      print('session: ${authResponse.session != null ? 'PRESENT' : 'NULL (email confirmation required)'}');

      return authResponse;
    } on AuthException catch (e) {
      print('=== AUTH_SERVICE.signUp: AuthException: ${e.message} ===');
      throw _mapAuthException(e);
    } catch (e) {
      print('=== AUTH_SERVICE.signUp: unexpected error: $e ===');
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

  debugPrint('========================');
  debugPrint('SAVING ROLE: $role');
  debugPrint('SAVING TYPE: $type');
  debugPrint('USER ID: ${user.id}');
  debugPrint('========================');

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
  Future<void> sendPasswordResetEmail(
    String email,
  ) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email.trim(),
        redirectTo: kIsWeb
            ? null
            : 'propcid://reset-password',
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  /// Update password
  Future<UserResponse> updatePassword(
    String newPassword,
  ) async {
    try {
      return await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } catch (e) {
      throw 'A network error occurred. Please try again.';
    }
  }

  /// Load profile
  Future<Map<String, dynamic>?> getUserProfile(
    String userId,
  ) async {
    try {
      return await _supabase
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
    } catch (e) {
      debugPrint(
        'Error fetching profile: $e',
      );
      return null;
    }
  }

  String _mapAuthException(
    AuthException e,
  ) {
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