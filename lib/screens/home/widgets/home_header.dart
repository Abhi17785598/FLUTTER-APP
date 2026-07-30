import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Home's top app bar: logo/brand dropdown + calendar/notifications/avatar
/// shortcuts. Purely presentational — every tap target below navigates to
/// exactly the same route it did in the previous inline `_buildAppBar`.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => _showLogoDropdown(context),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: AppColors.primaryGlow,
                  ),
                  child: const Center(
                    child: Text(
                      'PC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PropCID',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    Text(
                      'Find. Compare. Own.',
                      style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                    ),
                  ],
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
              _CircleIconButton(
                icon: Icons.notifications_outlined,
                onTap: () => Navigator.pushNamed(
                  context,
                  AppConstants.notificationsScreen,
                ),
                badge: true,
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () =>
                    Navigator.pushNamed(context, AppConstants.profileScreen),
                child: Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(
                          'https://picsum.photos/seed/avatar/100/100',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
            Text('Developer: Rajesh Kumar'),
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
