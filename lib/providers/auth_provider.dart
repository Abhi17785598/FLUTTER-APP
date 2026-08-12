import 'package:flutter/material.dart';
import 'dart:async';
import '../app_navigator.dart';
import '../models/builder_section_models.dart';
import '../services/auth_service.dart';
import '../services/builder_sections_service.dart';
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

  /// The full `profiles` row from the most recent fetch.
  ///
  /// Cached so profile-completion can evaluate role-specific fields (phone,
  /// bio, office_address, social_media, ...) without a second query or a
  /// parallel identity provider — see blueprint §10. Read-only.
  Map<String, dynamic>? _profileRow;

  /// This person's own team standing — never the builder-side view.
  ///
  /// Mirrors two separate, additive React mechanisms rather than one
  /// override: `ProfileDashboardShell.tsx:691-708`'s live
  /// `builder_team_members` count (→ [_activeTeamMemberships]/
  /// [hasTeamMembership]) and `TeamInviteGate.tsx`'s pending-invite lookup by
  /// email (→ [_pendingTeamInvitations]). Neither one changes `userType`
  /// routing — that stays exactly as it is until a later phase.
  List<BuilderTeamMember> _activeTeamMemberships = const [];
  List<BuilderTeamInvitation> _pendingTeamInvitations = const [];

  /// The user id [_activeTeamMemberships]/[_pendingTeamInvitations] were last
  /// checked for.
  ///
  /// `_fetchUserProfile()` reruns on every auth event carrying a session —
  /// including `tokenRefreshed`, which fires far more often than the
  /// membership/invitation rows actually change — so this guards the check to
  /// once per signed-in user rather than once per event, the same way
  /// `builder_dashboard_screen.dart`'s `_loadedUserId` guards its analytics
  /// load.
  String? _teamCheckedUserId;

  final AuthService _authService = AuthService();
  final BuilderTeamService _teamService = BuilderTeamService();
  StreamSubscription<AuthState>? _authSub;

  AuthProvider() {
    _authSub = _authService.onAuthStateChange.listen((state) {
      // A recovery-link deep link establishes a session before the user has
      // set a new password — jump straight to the reset screen regardless of
      // what's currently on screen (including a cold start).
      if (state.event == AuthChangeEvent.passwordRecovery) {
        appNavigatorKey.currentState?.pushNamed('/reset-password');
        return;
      }

      if (state.session != null) {
        // TEMPORARY DIAGNOSTIC — remove after the clock/expiry investigation.
        // Logged before any other Supabase call (incl. _fetchUserProfile
        // below) so this reflects the session exactly as gotrue just set it.
        final diagSession = _authService.currentSession;
        debugPrint(
          '[ClockDiag] now=${DateTime.now()} '
          'expiresAt=${diagSession?.expiresAt} '
          'isExpired=${diagSession?.isExpired} '
          'hasAccessToken=${diagSession?.accessToken != null} '
          'hasRefreshToken=${diagSession?.refreshToken != null}',
        );

        _isLoggedIn = true;

        final currentUser = _authService.currentUser;

        if (currentUser != null) {
          _userName = currentUser.userMetadata?['display_name'] ?? '';

          _userEmail = currentUser.email ?? '';

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
        _profileRow = null;
        _teamCheckedUserId = null;
        _activeTeamMemberships = const [];
        _pendingTeamInvitations = const [];
      }

      notifyListeners();
    });
  }

  Future<void> _fetchUserProfile() async {
    final currentUser = _authService.currentUser;

    if (currentUser == null) return;

    try {
      final profile = await _authService.getUserProfile(currentUser.id);

      if (profile != null) {
        _userName = profile['display_name'] ?? _userName;

        _userEmail = profile['email'] ?? _userEmail;

        _avatarUrl = profile['avatar_url'];

        _userRole = profile['user_role'];

        _userType = profile['user_type'];
        _userId = currentUser.id;
        _profileCity = profile['work_city'];
        _profileRow = Map<String, dynamic>.from(profile);

        notifyListeners();
      }

      await _checkTeamStatus(currentUser);
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  /// This person's own active memberships and pending invitations —
  /// deliberately separate from [_fetchUserProfile]'s `profiles` read, since
  /// neither table is scoped by `builder_id` the way the builder-side
  /// `BuilderTeamService` calls are (`myActiveMemberships`/
  /// `myPendingInvitations` query by `member_user_id`/`email` instead — see
  /// `builder_sections_service.dart`).
  ///
  /// Read-only: never accepts an invitation, never writes `user_type`, never
  /// navigates. Guarded by [_teamCheckedUserId] so a `tokenRefreshed` event
  /// for the same user doesn't re-run it; a genuine failure is swallowed the
  /// same way, rather than retried on every subsequent refresh, so this
  /// cannot become another contributor to a refresh loop.
  Future<void> _checkTeamStatus(User user) async {
    if (_teamCheckedUserId == user.id) return;
    _teamCheckedUserId = user.id;

    try {
      final memberships = await _teamService.myActiveMemberships(user.id);

      final email = user.email;
      final invitations = (email == null || email.isEmpty)
          ? const <BuilderTeamInvitation>[]
          : await _teamService.myPendingInvitations(email);

      _activeTeamMemberships = memberships;
      _pendingTeamInvitations = invitations;

      // TEMPORARY DEBUG — remove once a later phase has a real consumer to
      // verify against. No token/credential is ever printed here.
      debugPrint(
        '[TeamStatus] userId=${user.id} email=$email '
        'activeMemberships=${memberships.length} '
        'pendingInvitations=${invitations.length}',
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error checking team status: $e');
    }
  }

  /// Re-runs [_checkTeamStatus] regardless of [_teamCheckedUserId].
  ///
  /// For a caller that just changed the underlying rows itself — right now
  /// only the pending-invitation screen, after `acceptInvite` succeeds — and
  /// needs this cache to reflect that immediately rather than waiting for
  /// the next auth event. This is a single deliberate, user-triggered
  /// refresh, not a poll, so it doesn't reintroduce the every-event-reruns-it
  /// problem [_teamCheckedUserId] guards against elsewhere.
  Future<void> refreshTeamStatus() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;

    _teamCheckedUserId = null;
    await _checkTeamStatus(currentUser);
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

  /// Unmodifiable view of the cached `profiles` row, or null before the first
  /// successful fetch.
  Map<String, dynamic>? get profileRow =>
      _profileRow == null ? null : Map<String, dynamic>.unmodifiable(_profileRow!);

  /// True once at least one active `builder_team_members` row has been found
  /// for this person, across any builder. Additive information only — does
  /// not change [userType] or where this app routes them.
  bool get hasTeamMembership => _activeTeamMemberships.isNotEmpty;

  /// This person's own active memberships, across every builder they've
  /// joined. Empty before the first check completes or if there are none.
  List<BuilderTeamMember> get activeTeamMemberships =>
      List.unmodifiable(_activeTeamMemberships);

  /// This person's own pending invitations, across every builder that has
  /// invited them. Empty before the first check completes or if there are
  /// none.
  List<BuilderTeamInvitation> get pendingTeamInvitations =>
      List.unmodifiable(_pendingTeamInvitations);

  /// Accepts an email, phone number or username — [AuthService] resolves
  /// whichever was typed to an email before signing in.
  Future<String?> login(String identifier, String password) async {
    if (identifier.trim().isEmpty || password.isEmpty) {
      return 'Please fill in all fields';
    }

    try {
      await _authService.loginWithIdentifier(identifier.trim(), password);

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sends a 6-digit SMS code to [phone]. Returns an error string, or null on
  /// success.
  Future<String?> sendOtp(String phone) async {
    try {
      await _authService.sendOtp(phone);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> resendOtp(String phone) async {
    try {
      await _authService.resendOtp(phone);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Verifies the code and establishes the session. Returns an error string,
  /// or null on success — the auth-state listener above then populates
  /// [isLoggedIn] and the profile fields.
  Future<String?> verifyOtp({
    required String phone,
    required String otp,
    String? name,
  }) async {
    try {
      await _authService.verifyOtp(phone: phone, otp: otp, name: name);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> resetPassword(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Exchanges a recovery `token_hash` from the reset-password deep link for
  /// a session. Returns an error string, or null on success.
  Future<String?> verifyRecoveryToken(String tokenHash) async {
    try {
      await _authService.verifyRecoveryToken(tokenHash);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    try {
      await _authService.updatePassword(newPassword);
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
    if (name.trim().isEmpty || email.trim().isEmpty || password.isEmpty) {
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

      final authResponse = await _authService.signUp(
        email.trim(),
        password,
        name.trim(),
        role: role,
        type: type,
      );

      if (authResponse.session == null) {
        // Supabase requires email confirmation — no session yet.
        // Return a non-null message so the caller shows a confirmation prompt
        // instead of calling updateProfileData() with no logged-in user.
        return '__email_confirmation_required__';
      }

      // A session came back immediately (email confirmation disabled) —
      // persist the chosen role/type now instead of leaving user_role NULL
      // until some later reconciliation step.
      await updateProfileData(name: name.trim(), role: role, type: type);

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
    await _authService.updateProfileData(name: name, role: role, type: type);

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
    _profileRow = null;
    _teamCheckedUserId = null;
    _activeTeamMemberships = const [];
    _pendingTeamInvitations = const [];

    notifyListeners();
  }

  /// Re-reads the profiles row from Supabase and updates all cached fields.
  /// Call this after any external write to the profiles table (e.g. after a
  /// registration screen saves its data) so the provider reflects DB state.
  Future<void> refreshProfile() async {
    await _fetchUserProfile();
  }

  void updateProfile(String name, String email) {
    _userName = name.trim();
    _userEmail = email.trim();

    notifyListeners();
  }
}
