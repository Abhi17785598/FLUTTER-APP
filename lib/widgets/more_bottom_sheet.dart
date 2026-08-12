import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/navigation/workspace_destinations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';
import 'manage_list_tile.dart';

/// Secondary destination sheet opened from the Profile screen's Manage list
/// "More" row (blueprint §16.3).
///
/// Offers the destinations not already surfaced by the Manage list itself.
/// Every row calls the same [WorkspaceDestinations] method the Workspace
/// Drawer uses, so the two entry points cannot diverge.
///
/// Uses `showModalBottomSheet` with the app's existing 24 dp rounded-top
/// chrome rather than a bespoke sheet mechanism.
void showMoreBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => const _MoreSheetBody(),
  );
}

class _MoreSheetBody extends StatelessWidget {
  const _MoreSheetBody();

  void _navigate(BuildContext context, void Function(NavigatorState) action) {
    final navigator = Navigator.of(context);
    navigator.pop();
    action(navigator);
  }

  void _overlay(BuildContext context, void Function(BuildContext) action) {
    final navigator = Navigator.of(context);
    navigator.pop();
    action(navigator.context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Same additive gate as the Workspace Drawer — see its build() comment.
    final showTeamWorkspace =
        auth.hasTeamMembership && auth.userType != 'team_member';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDF2),
                  borderRadius: BorderRadius.circular(AppConstants.pillRadius),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                'More',
                style: AppTextStyles.heading3.copyWith(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            _row(
              context,
              Icons.grid_view_rounded,
              'Manage Dashboard',
              onNavigate: WorkspaceDestinations.manageDashboard,
            ),
            if (showTeamWorkspace)
              _row(
                context,
                Icons.groups_outlined,
                'Team Workspace',
                onNavigate: WorkspaceDestinations.teamWorkspace,
              ),
            _row(
              context,
              Icons.dynamic_feed_outlined,
              'Feed',
              onNavigate: WorkspaceDestinations.feed,
            ),
            _row(
              context,
              Icons.chat_bubble_outline,
              'Messages',
              onNavigate: WorkspaceDestinations.messages,
            ),
            _row(
              context,
              Icons.people_outline,
              'Network',
              onNavigate: WorkspaceDestinations.network,
            ),
            _row(
              context,
              Icons.credit_card_outlined,
              'Subscription & Billing',
              onNavigate: WorkspaceDestinations.subscriptionBilling,
            ),
            _row(
              context,
              Icons.share_outlined,
              'Social',
              onNavigate: WorkspaceDestinations.social,
            ),
            _row(
              context,
              Icons.settings_outlined,
              'Settings',
              onOverlay: WorkspaceDestinations.settings,
            ),
            _row(
              context,
              Icons.logout,
              'Logout',
              isDestructive: true,
              onOverlay: WorkspaceDestinations.logout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    IconData icon,
    String label, {
    void Function(NavigatorState)? onNavigate,
    void Function(BuildContext)? onOverlay,
    bool isDestructive = false,
  }) {
    return ManageListTile(
      icon: icon,
      label: label,
      variant: ManageListTileVariant.plain,
      isDestructive: isDestructive,
      surfaceColor: AppColors.cardBackground,
      onTap: () {
        if (onNavigate != null) {
          _navigate(context, onNavigate);
        } else if (onOverlay != null) {
          _overlay(context, onOverlay);
        }
      },
    );
  }
}
