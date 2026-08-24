import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../../app_navigator.dart';
import '../../providers/auth_provider.dart';
import '../constants/app_constants.dart';

/// Resolves `https://propcid.com/accept-invite?invitation=...&token=...` —
/// the link `invite-team-member` actually sends (`index.ts:149`,
/// `redirectTo = "${origin}/accept-invite?invitation=...&token=..."`).
///
/// WHY THIS IS SMALLER THAN IT LOOKS
/// ----------------------------------
/// The portal's `AcceptInvite.tsx` needs `invitation`/`token` from the URL
/// because it has nothing else to go on. This app already has
/// `PendingInvitationGate`, which finds the same invitation by the signed-in
/// user's email (`AuthProvider.pendingTeamInvitations`) — the exact fallback
/// `AcceptInvite.tsx:57-69` itself falls back to when the URL param is
/// missing. So once the link reaches the app, its own `invitation`/`token`
/// values add nothing `PendingInvitationScreen` doesn't already resolve on
/// its own; this handler only needs to recognise the link and open that
/// screen — never a new query, never new screen params.
///
/// WHY THIS CAN'T JUST ACCEPT THE INVITE ITSELF
/// ---------------------------------------------
/// `accept-team-invite` requires an authenticated caller
/// (`index.ts:27-38`) — the URL's `invitation`/`token` are business data, not
/// a credential. A brand-new invitee's *browser* gets a session from the
/// Supabase-hosted first hop of this link (`.../auth/v1/verify` redirecting
/// here); this Flutter app's own `SupabaseClient` is a separate storage
/// context that redirect never touches. So for that population, tapping the
/// link on a phone cannot itself complete acceptance in-app — they still
/// need to sign in to the app with the invited email, at which point
/// `PendingInvitationGate`'s existing mechanism (unrelated to this handler)
/// already finds the same invitation. This handler's real value is narrower:
/// an *already signed-in* user tapping the link jumps straight to
/// [AppConstants.pendingInvitationScreen] instead of a browser.
class InviteDeepLinkHandler {
  InviteDeepLinkHandler({AuthProvider? authProvider})
    : _authProvider = authProvider;

  final AuthProvider? _authProvider;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Starts listening. Safe to call once, from app start — checks the link
  /// that launched a cold start, then the stream for anything opened while
  /// running.
  Future<void> start() async {
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) _handle(initial);
    } catch (e) {
      debugPrint('InviteDeepLinkHandler.start (initial link) failed: $e');
    }

    _subscription = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (e) =>
          debugPrint('InviteDeepLinkHandler.uriLinkStream error: $e'),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }

  /// `path` is `/accept-invite` on both platforms once the OS hands the URI
  /// over — this only checks that, never `invitation`/`token`, per the class
  /// doc above.
  void _handle(Uri uri) {
    if (!uri.path.contains('accept-invite')) return;

    final authProvider = _authProvider;
    // Not logged in yet: nothing this handler does can complete acceptance
    // (see class doc). Doing nothing here is deliberate — signing in with
    // the invited email is what makes `PendingInvitationGate` pick this up,
    // and that path must not be duplicated.
    if (authProvider == null || !authProvider.isLoggedIn) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    final currentRoute = ModalRoute.of(navigator.context)?.settings.name;
    if (currentRoute == AppConstants.pendingInvitationScreen) return;

    navigator.pushNamed(AppConstants.pendingInvitationScreen);
  }
}
