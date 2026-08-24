import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../screens/dashboard/broker_dashboard_screen.dart';
import '../../screens/dashboard/builder_dashboard_screen.dart';
import '../../screens/dashboard/individual_dashboard_screen.dart';
import '../../screens/dashboard/influencer_dashboard_screen.dart';
import '../../screens/stubs/coming_soon_screen.dart';
import '../../screens/team/team_workspace_screen.dart';
import '../theme/app_colors.dart';

/// Resolves the current user's role to the correct dashboard screen.
///
/// A thin dispatcher, not a screen of its own (blueprint §2.4): the Workspace
/// Drawer, the More bottom sheet and the Profile screen all push
/// `AppConstants.manageDashboardScreen` instead of each repeating the
/// role-switch. The mapping is lifted unchanged from
/// `_ProfileScreenState._openDashboard`.
class ManageDashboardDispatcher extends StatelessWidget {
  const ManageDashboardDispatcher({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // AuthProvider populates userType asynchronously via _fetchUserProfile().
    // Resolving the role before it lands would fall through to the unavailable
    // state for a frame or two, so wait it out — same guard RoleHomeRouter
    // already applies.
    if (auth.isLoggedIn && auth.userType == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    switch (auth.userType?.toLowerCase()) {
      case 'builder':
        return const BuilderDashboardScreen();
      case 'broker':
        return const BrokerDashboardScreen();
      case 'influencer':
        return const InfluencerDashboardScreen();
      case 'individual':
        return const IndividualDashboardScreen();
      // `ProfileDispatch.tsx:59`'s literal switch case: `profiles.user_type`
      // is set to `'team_member'` only for a brand-new invitee with no prior
      // profile (`accept-team-invite/index.ts:131-151`) — never inferred
      // from an active membership, which an existing builder/broker/
      // individual/influencer can also hold without their own `userType`
      // ever becoming this value. See `WorkspaceDestinations.teamWorkspace`
      // for how an existing user reaches the same screen instead.
      case 'team_member':
        return const TeamWorkspaceScreen();
      default:
        // Previously a "Dashboard — coming soon" snackbar that pushed nothing.
        // As a route we are already on screen, so the same message is rendered
        // instead. Reached only for a signed-out user or an unrecognised
        // user_type.
        return const ComingSoonScreen(
          title: 'Dashboard',
          message:
              'Your dashboard will appear here once your account type is '
              'set up.',
        );
    }
  }
}
