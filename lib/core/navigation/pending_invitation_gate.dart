import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_navigator.dart';
import '../../providers/auth_provider.dart';
import '../constants/app_constants.dart';

/// Mobile mirror of the portal's `TeamInviteGate.tsx`.
///
/// That component is mounted globally in `App.tsx`, outside `<Routes>`, and
/// silently redirects a signed-in user with a pending invitation to
/// `/accept-invite`. This widget is mounted the same way — wrapped around
/// every screen via [MaterialApp.builder] in `app.dart` — and does the same
/// thing: it never renders anything of its own, it only watches
/// [AuthProvider.pendingTeamInvitations] (already populated by
/// `AuthProvider._checkTeamStatus`, so this does not run a query of its own)
/// and pushes [AppConstants.pendingInvitationScreen] the first time that list
/// is non-empty for a signed-in user.
///
/// "The first time" is deliberate and is what stands in for
/// `TeamInviteGate`'s own `sessionStorage["propcid_team_invite_checked"]`
/// guard: the closest Flutter analogue of "once per browser session" is once
/// per app run, so [_hasFired] latches shut permanently after it fires once,
/// regardless of whether the user acts on the invitation. Without that latch,
/// every later `notifyListeners()` from [AuthProvider] (a token refresh, a
/// profile edit, anything) would re-run this `build()` and re-push the same
/// screen on top of itself.
class PendingInvitationGate extends StatefulWidget {
  const PendingInvitationGate({required this.child, super.key});

  final Widget child;

  @override
  State<PendingInvitationGate> createState() => _PendingInvitationGateState();
}

class _PendingInvitationGateState extends State<PendingInvitationGate> {
  bool _hasFired = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!_hasFired &&
        auth.isLoggedIn &&
        auth.pendingTeamInvitations.isNotEmpty) {
      // Set synchronously, before the frame callback below even runs, so a
      // second `build()` triggered before that callback fires (e.g. by
      // another provider notifying in the same frame) cannot schedule a
      // second push.
      _hasFired = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        appNavigatorKey.currentState
            ?.pushNamed(AppConstants.pendingInvitationScreen);
      });
    }

    return widget.child;
  }
}
