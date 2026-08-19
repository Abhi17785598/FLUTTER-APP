import 'dart:async';

import 'package:propcid_app/models/builder_section_models.dart';
import 'package:propcid_app/services/auth_service.dart';
import 'package:propcid_app/services/builder_sections_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Drives [AuthProvider] with a manually controlled auth-state stream and
/// canned profile rows — no live or locally-initialized Supabase client
/// involved, thanks to [AuthServiceBase] (see `auth_service.dart`). Shared
/// by `auth_provider_test.dart` and `auth_navigation_test.dart` so both
/// exercise the exact same fake behaviour.
class FakeAuthService implements AuthServiceBase {
  final _controller = StreamController<AuthState>.broadcast();

  User? currentUserOverride;
  final Map<String, Map<String, dynamic>?> profilesByUserId = {};
  Object? nextProfileFetchError;
  Completer<void>? pauseNextFetch;
  int logoutCallCount = 0;
  final List<String> profileFetchCalls = [];
  final List<Map<String, String>> upsertCalls = [];
  final List<String> signUpWithEmailCalls = [];
  Object? nextSignUpError;

  void emit(AuthState state) => _controller.add(state);
  void emitError(Object error) => _controller.addError(error);
  Future<void> dispose() => _controller.close();

  @override
  Stream<AuthState> get onAuthStateChange => _controller.stream;

  @override
  User? get currentUser => currentUserOverride;

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    profileFetchCalls.add(userId);
    final pause = pauseNextFetch;
    if (pause != null) {
      pauseNextFetch = null;
      await pause.future;
    }
    final error = nextProfileFetchError;
    if (error != null) {
      nextProfileFetchError = null;
      throw error;
    }
    return profilesByUserId[userId];
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String userId) =>
      throw UnimplementedError('AuthProvider uses fetchProfile, not this.');

  @override
  Future<void> upsertAccountTypeAndName({
    required String userId,
    required String displayName,
    required String userType,
  }) async {
    upsertCalls.add({
      'userId': userId,
      'displayName': displayName,
      'userType': userType,
    });
    final existing = profilesByUserId[userId] ?? <String, dynamic>{};
    profilesByUserId[userId] = {
      ...existing,
      'user_id': userId,
      'display_name': displayName,
      'user_type': userType,
      'profile_complete': false,
    };
  }

  @override
  Future<void> logout() async {
    logoutCallCount++;
    currentUserOverride = null;
    emit(AuthState(AuthChangeEvent.signedOut, null));
  }

  @override
  Future<void> loginWithIdentifier(String identifier, String password) =>
      throw UnimplementedError();
  @override
  Future<void> sendOtp(String phone) => throw UnimplementedError();
  @override
  Future<void> resendOtp(String phone) => throw UnimplementedError();
  @override
  Future<void> verifyOtp({
    required String phone,
    required String otp,
    String? name,
  }) => throw UnimplementedError();
  @override
  Future<bool> signInWithGoogle() => throw UnimplementedError();
  @override
  Future<void> signUpWithEmail(String email) async {
    signUpWithEmailCalls.add(email);
    final error = nextSignUpError;
    if (error != null) {
      nextSignUpError = null;
      throw error;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      throw UnimplementedError();
  @override
  Future<void> verifyRecoveryToken(String tokenHash) =>
      throw UnimplementedError();
  @override
  Future<UserResponse> updatePassword(String newPassword) =>
      throw UnimplementedError();
}

/// Overrides the two network calls [AuthProvider] makes on every profile
/// fetch so tests never touch a real Supabase client. The `client:` argument
/// avoids `BuilderTeamService`'s default `Supabase.instance.client` fallback
/// — it's stored but never read once these overrides are in place.
class FakeTeamService extends BuilderTeamService {
  FakeTeamService()
    : super(client: SupabaseClient('http://localhost:54321', 'test-anon-key'));

  @override
  Future<List<BuilderTeamMember>> myActiveMemberships(String userId) async =>
      const [];

  @override
  Future<List<BuilderTeamInvitation>> myPendingInvitations(
    String email,
  ) async => const [];
}

User fakeUser(String id, {String? email}) => User(
  id: id,
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: '2024-01-01T00:00:00Z',
  email: email,
);

Session fakeSession(User user) =>
    Session(accessToken: 'access-$user.id', tokenType: 'bearer', user: user);
