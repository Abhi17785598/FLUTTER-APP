import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/navigation/workspace_destinations.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';
import 'manage_list_tile.dart';

/// Left slide-in navigation panel opened from the Profile header, giving
/// access to the full destination set (blueprint §16.2).
///
/// Built on Flutter's native [Drawer] rather than a bespoke overlay, per §7's
/// stated preference: it matches the prototype's 280 dp width and scrim while
/// providing swipe-to-dismiss, back-button handling, focus traversal and
/// screen-reader semantics for free. The native settle duration (246 ms) is
/// close enough to the prototype's 280 ms not to read as different.
///
/// Every row delegates to [WorkspaceDestinations] so this and the More bottom
/// sheet can never diverge.
class WorkspaceDrawer extends StatelessWidget {
  const WorkspaceDrawer({super.key});

  /// Prototype: 280 dp panel.
  static const double _kWidth = 280;

  /// Prototype scrim: `rgba(26,26,46,0.45)`. Applied by the host Scaffold via
  /// `drawerScrimColor`.
  static const Color scrimColor = Color(0x731A1A2E);

  /// Closes the drawer, then runs a navigation action.
  ///
  /// The [NavigatorState] is captured before dismissal because the drawer's
  /// own context is deactivated once it closes.
  void _navigate(BuildContext context, void Function(NavigatorState) action) {
    final navigator = Navigator.of(context);
    navigator.pop();
    action(navigator);
  }

  /// Closes the drawer, then shows a sheet/dialog. Uses the navigator's own
  /// context, which outlives the drawer and still sits below the providers.
  void _overlay(BuildContext context, void Function(BuildContext) action) {
    final navigator = Navigator.of(context);
    navigator.pop();
    action(navigator.context);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    // Additive, never a replacement — `ProfileDashboardShell.tsx:693-708`'s
    // nav link only ever appears alongside an existing role's own dashboard.
    // Excluding `userType == 'team_member'` avoids a redundant second entry
    // to the same screen "Manage Dashboard" already resolves to for that
    // population (`ManageDashboardDispatcher`'s `team_member` case).
    final showTeamWorkspace =
        auth.hasTeamMembership && auth.userType != 'team_member';

    return Drawer(
      width: _kWidth,
      backgroundColor: AppColors.cardBackground,
      elevation: 16,
      // The prototype's panel is square-edged; M3's Drawer rounds its trailing
      // corners by default.
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Column(
          children: [
            const _DrawerHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                children: [
                  _row(
                    context,
                    Icons.home_outlined,
                    'Home',
                    onNavigate: WorkspaceDestinations.home,
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
                    Icons.movie_outlined,
                    'Reels',
                    onNavigate: WorkspaceDestinations.reels,
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
                    Icons.trending_up_rounded,
                    'Upgrade',
                    onNavigate: WorkspaceDestinations.upgrade,
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
            const _DrawerFooter(),
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
      // The drawer panel is white, so that is the surface behind each row.
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

/// Avatar + name + email + close button, above a hairline divider.
class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final initial =
        auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F4))),
      ),
      child: Row(
        children: [
          _Avatar(avatarUrl: auth.avatarUrl, initial: initial),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  auth.userName.isNotEmpty ? auth.userName : 'Guest',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (auth.userEmail.isNotEmpty)
                  Text(
                    auth.userEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            label: 'Close menu',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;

  const _Avatar({required this.avatarUrl, required this.initial});

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        initial,
        style: AppTextStyles.heading3.copyWith(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );

    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: avatarUrl == null
          ? fallback
          : ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                width: 44,
                height: 44,
                errorWidget: (_, _, _) => fallback,
              ),
            ),
    );
  }
}

class _DrawerFooter extends StatelessWidget {
  const _DrawerFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      // Hardcoded to match the prototype. Reading the real build number needs
      // package_info_plus, which is not an approved dependency — documented
      // for a later milestone.
      child: Text(
        'Version 1.0.0',
        style: AppTextStyles.caption.copyWith(
          fontSize: 10.5,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}
