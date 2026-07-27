import 'package:flutter/material.dart';
import 'dart:async';
import '../services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';
  String? _avatarUrl;
  String? _userRole;
  String? _userType;
  String? _userId;
  String? _profileCity;

  final AuthService _authService = AuthService();
  StreamSubscription<AuthState>? _authSub;

  AuthProvider() {
    _authSub = _authService.onAuthStateChange.listen((state) {

      debugPrint('===================');
debugPrint('AUTH EVENT: ${state.event}');
debugPrint('HAS SESSION: ${state.session != null}');
debugPrint('EMAIL: ${state.session?.user.email}');
debugPrint('===================');

      if (state.session != null) {
        _isLoggedIn = true;

        final currentUser = _authService.currentUser;

        if (currentUser != null) {
          _userName =
              currentUser.userMetadata?['display_name'] ?? '';

          _userEmail =
              currentUser.email ?? '';

          _fetchUserProfile();
        }
      } else {
        _isLoggedIn = false;
        _userName = '';
        _userEmail = '';
        _avatarUrl = null;
        _userRole = null;
        _userType = null;
        _profileCity = null;
      }

      notifyListeners();
    });
  }

  Future<void> _fetchUserProfile() async {
    final currentUser = _authService.currentUser;

    if (currentUser == null) return;

    try {
      final profile =
          await _authService.getUserProfile(currentUser.id);

      if (profile != null) {
        _userName =
            profile['display_name'] ?? _userName;

        _userEmail =
            profile['email'] ?? _userEmail;

        _avatarUrl =
            profile['avatar_url'];

       _userRole = profile['user_role'];

_userType = profile['user_type'];
_userId = currentUser.id;
_profileCity = profile['work_city'];



debugPrint("================================");
debugPrint("PROFILE FETCHED");
debugPrint("ROLE = $_userRole");
debugPrint("TYPE = $_userType");
debugPrint("================================");

notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  bool get isLoggedIn => _isLoggedIn;
  String get userName => _userName;
  String get userEmail => _userEmail;
  String? get avatarUrl => _avatarUrl;
  String? get userRole => _userRole;
  String? get userType => _userType;
  String? get userId => _userId;
  String? get profileCity => _profileCity;

  Future<String?> login(
    String email,
    String password,
  ) async {
    if (email.trim().isEmpty || password.isEmpty) {
      return 'Please fill in all fields';
    }

    try {
      await _authService.login(
        email.trim(),
        password,
      );

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUp(
    String name,
    String email,
    String password,
    String confirmPassword, {
    String role = 'buyer',
    String type = 'individual',
  }) async {
    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        password.isEmpty) {
      return 'Please fill in all fields';
    }

    if (password != confirmPassword) {
      return 'Passwords do not match';
    }

    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }

    try {
      if (role == 'buyer') {
        type = 'individual';
      }

      print('=== AUTH_PROVIDER.signUp: calling _authService.signUp ===');
      final authResponse = await _authService.signUp(
        email.trim(),
        password,
        name.trim(),
        role: role,
        type: type,
      );
      print('=== AUTH_PROVIDER.signUp: returned. session=${authResponse.session != null ? 'PRESENT' : 'NULL'} ===');

      if (authResponse.session == null) {
        // Supabase requires email confirmation — no session yet.
        // Return a non-null message so the caller shows a confirmation prompt
        // instead of calling updateProfileData() with no logged-in user.
        return '__email_confirmation_required__';
      }

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> updateProfileData({
  required String name,
  required String role,
  required String type,
}) async {
  await _authService.updateProfileData(
    name: name,
    role: role,
    type: type,
  );

  await _fetchUserProfile();
}

  /// Initiates Google OAuth. Returns null on success (browser opened),
  /// or an error string if the flow could not be started.
  /// The actual session arrives later via the auth state stream.
  Future<String?> signInWithGoogle() async {
    try {
      final success = await _authService.signInWithGoogle();
      if (!success) return 'Could not open Google Sign In. Please try again.';
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> logout() async {
    await _authService.logout();

    _isLoggedIn = false;
    _userName = '';
    _userEmail = '';
    _avatarUrl = null;
    _userRole = null;
    _userType = null;
    _userId = null;
    _profileCity = null;

    notifyListeners();
  }

  /// Re-reads the profiles row from Supabase and updates all cached fields.
  /// Call this after any external write to the profiles table (e.g. after a
  /// registration screen saves its data) so the provider reflects DB state.
  Future<void> refreshProfile() async {
    await _fetchUserProfile();
  }

  void updateProfile(
    String name,
    String email,
  ) {
    _userName = name.trim();
    _userEmail = email.trim();

    notifyListeners();
  }
}