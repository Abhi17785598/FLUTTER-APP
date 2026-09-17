import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_card.dart';
import '../../../providers/notification_provider.dart';

/// Home's top app bar: logo/brand dropdown + calendar/notifications/avatar
/// shortcuts. Purely presentational — every tap target below navigates to
/// exactly the same route it did in the previous inline `_buildAppBar`.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  /// The real PropCid wordmark — 862×203 px, transparent background,
  /// already brand-orange. Same file the rest of the app's branding
  /// declares in `pubspec.yaml`; sized here by height only (via
  /// `AspectRatio`) so it can never stretch or distort.
  static const String _logoAssetPath = 'assets/branding/propcid_logo.png';
  static const double _logoAspectRatio = 862 / 203;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: GlassCard(
        borderRadius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        // Flat, solid white — no blurred backdrop bleeding through. `opacity`
        // near 1 and `blurSigma: 0` (which also skips the BackdropFilter
        // entirely, see GlassCard) turn this into a plain white bar, matching
        // the clean, non-glassy header the reference design shows.
        opacity: 0.98,
        blurSigma: 0,
        borderColor: Colors.white.withOpacity(0.9),
        highlight: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => _showLogoDropdown(context),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'PropCid',
                        image: true,
                        child: SizedBox(
                          height: 25,
                          child: AspectRatio(
                            aspectRatio: _logoAspectRatio,
                            child: Image.asset(
                              _logoAssetPath,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Padding(
                        // The wordmark's own glyphs sit slightly above its
                        // bounding box's vertical centre (no descenders), so
                        // the arrow is nudged down a touch to optically (not
                        // just numerically) align with it, rather than with
                        // the wordmark's full — partly empty — box.
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 19,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Find. Compare. Own.',
                    style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                _CircleIconButton(
                  icon: Icons.calendar_today_outlined,
                  onTap: () =>
                      Navigator.pushNamed(context, AppConstants.visitsScreen),
                ),
                const SizedBox(width: 10),
                // G-3: the badge was hard-coded `true`, so it showed a dot forever
                // whether or not anything was unread. It now watches the app-level
                // provider, which the realtime channel keeps current — a notification
                // arriving while this screen is open lights the dot without a refresh.
                _CircleIconButton(
                  icon: Icons.notifications_outlined,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppConstants.notificationsScreen,
                  ),
                  badge: context.watch<NotificationProvider>().hasUnread,
                ),
                const SizedBox(width: 10),
                // Was the profile avatar (already one tap away via the bottom
                // nav's own Profile tab), which meant reaching Messages was
                // Profile -> Dashboard -> Messages. This is the direct
                // shortcut instead — same tap-target style as the calendar/
                // notifications icons beside it.
                _CircleIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  onTap: () =>
                      Navigator.pushNamed(context, AppConstants.messagesScreen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoDropdown(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          children: [
            _buildDropdownItem(
              context,
              Icons.home_outlined,
              'Home',
              () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
            _buildDropdownItem(context, Icons.search_outlined, 'Search', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.searchScreen);
            }),
            const SizedBox(height: 8),
            _buildDropdownItem(context, Icons.favorite_border, 'Shortlist', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.shortlistScreen);
            }),
            const SizedBox(height: 8),
            _buildDropdownItem(
              context,
              Icons.calculate_outlined,
              'EMI Calculator',
              () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppConstants.emiCalculatorScreen);
              },
            ),
            const SizedBox(height: 8),
            _buildDropdownItem(
              context,
              Icons.compare_arrows_rounded,
              'Compare Properties',
              () {
                Navigator.pop(context);
                Navigator.pushNamed(
                  context,
                  AppConstants.comparePropertiesScreen,
                  arguments: {'propertyIds': <String>[]},
                );
              },
            ),
            const SizedBox(height: 8),
            _buildDropdownItem(
              context,
              Icons.notifications_outlined,
              'Notifications',
              () {
                Navigator.pop(context);
                Navigator.pushNamed(context, AppConstants.notificationsScreen);
              },
            ),
            const SizedBox(height: 8),
            _buildDropdownItem(context, Icons.movie_outlined, 'Reels', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.reelsScreen);
            }),
            const SizedBox(height: 8),
            _buildDropdownItem(context, Icons.person_outline, 'Profile', () {
              Navigator.pop(context);
              Navigator.pushNamed(context, AppConstants.profileScreen);
            }),
            const SizedBox(height: 16),
            Divider(color: AppColors.textHint.withOpacity(0.2)),
            const SizedBox(height: 16),
            _buildDropdownItem(
              context,
              Icons.info_outline,
              'About PropCID',
              () {
                Navigator.pop(context);
                _showAboutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownItem(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary),
      title: Text(
        label,
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
      ),
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('About PropCID'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PropCID is a modern real-estate application designed to make property search and visits seamless and efficient.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 16),
            Text('Version: 1.0.0'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppColors.cardShadow,
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
          if (badge)
            Positioned(
              top: 6,
              right: 6,
              child:
                  Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.35, 1.35),
                        duration: 900.ms,
                        curve: Curves.easeInOut,
                      ),
            ),
        ],
      ),
    );
  }
}
