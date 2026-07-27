import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/validation/validators.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/property_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../dashboard/builder_dashboard_screen.dart';
import '../dashboard/broker_dashboard_screen.dart';
import '../dashboard/influencer_dashboard_screen.dart';
import '../dashboard/individual_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NavigationProvider>(context, listen: false).setIndex(4);
      }
    });
  }

  // ── Role helpers ──────────────────────────────────────────────────────────

  Color _roleColor(String? userType) {
    switch (userType?.toLowerCase()) {
      case 'builder':
        return Colors.indigo;
      case 'broker':
        return Colors.teal;
      case 'influencer':
        return const Color(0xFF9333EA);
      default:
        return Colors.grey;
    }
  }

  String _roleLabel(String? userType) {
    switch (userType?.toLowerCase()) {
      case 'builder':
        return 'Builder';
      case 'broker':
        return 'Broker';
      case 'influencer':
        return 'Influencer';
      default:
        return 'Member';
    }
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  void _showPlaceholder(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  void _editProfile(BuildContext context, AuthProvider auth) {
    switch (auth.userType?.toLowerCase()) {
      case 'builder':
        Navigator.pushNamed(context, '/builder-profile');
        break;
      case 'broker':
        Navigator.pushNamed(context, '/broker-profile');
        break;
      case 'influencer':
        Navigator.pushNamed(context, '/influencer-profile');
        break;
      default:
        _showEditProfileDialog(context);
    }
  }

  void _openDashboard(BuildContext context, AuthProvider auth) {
    switch (auth.userType?.toLowerCase()) {
      case 'builder':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BuilderDashboardScreen()),
        );
        break;
      case 'broker':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BrokerDashboardScreen()),
        );
        break;
      case 'influencer':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const InfluencerDashboardScreen()),
        );
        break;
      case 'individual':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const IndividualDashboardScreen()),
        );
        break;
      default:
        _showPlaceholder(context, 'Dashboard');
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildProfileCard(context, auth),
                        const SizedBox(height: 24),
                        _buildStatsGrid(auth),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Quick Actions'),
                        const SizedBox(height: 16),
                        _buildQuickActions(context),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Business'),
                        const SizedBox(height: 12),
                        _buildBusinessSection(context, auth),
                        const SizedBox(height: 24),
                        _buildSectionHeader('Account'),
                        const SizedBox(height: 12),
                        _buildAccountSection(context, auth),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const BottomNavBar(currentIndex: 4),
        );
      },
    );
  }

  // ── Top header bar ────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Dashboard',
            style: AppTextStyles.heading2.copyWith(fontWeight: FontWeight.bold),
          ),
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.notifications_outlined, size: 20),
                      onPressed: () => _showNotificationsScreen(context),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined, size: 20),
                  onPressed: () => _showSettingsScreen(context),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Profile card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard(BuildContext context, AuthProvider auth) {
    final roleColor = _roleColor(auth.userType);
    final roleLabel = _roleLabel(auth.userType);
    final initials =
        auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'U';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
            const Color(0xFF4338CA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.primaryGlow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: auth.avatarUrl != null
                ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: auth.avatarUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Center(
                        child: Text(
                          initials,
                          style: AppTextStyles.heading1.copyWith(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      initials,
                      style: AppTextStyles.heading1.copyWith(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  auth.userName,
                  style: AppTextStyles.heading3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                // Email
                Text(
                  auth.userEmail,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 12),
                // Badges row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        roleLabel,
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Verified badge — shown when a role is assigned
                    if (auth.userRole != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified,
                                color: Colors.white, size: 13),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Edit profile button
                GestureDetector(
                  onTap: () => _editProfile(context, auth),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Edit Profile',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1);
  }

  // ── Performance stats ─────────────────────────────────────────────────────

  Widget _buildStatsGrid(AuthProvider auth) {
    // Business roles: Phase 1 shows placeholder values.
    // Individual: reads live counts from PropertyProvider.
    switch (auth.userType?.toLowerCase()) {
      case 'builder':
        return _staticStats([
          ('0', 'Projects', Icons.business_center_rounded, AppColors.primary),
          ('0', 'Network', Icons.people_rounded, Colors.indigo),
          ('0.0', 'Rating', Icons.star_rounded, Colors.amber),
        ]);

      case 'broker':
        return _staticStats([
          ('0', 'Listings', Icons.home_work_rounded, AppColors.primary),
          ('0', 'Views', Icons.visibility_rounded, Colors.teal),
          ('0.0', 'Rating', Icons.star_rounded, Colors.amber),
        ]);

      case 'influencer':
        return _staticStats([
          ('0', 'Videos', Icons.play_circle_rounded, const Color(0xFF9333EA)),
          ('0', 'Views', Icons.visibility_rounded, Colors.teal),
          ('0', 'Campaigns', Icons.campaign_rounded, Colors.orange),
        ]);

      default:
        return Consumer<PropertyProvider>(
          builder: (context, pp, _) {
            final saved = pp.getShortlistedProperties().length;
            final visits = pp.visits
                .where((v) =>
                    v['isUpcoming'] == true && v['status'] != 'Cancelled')
                .length;
            final enquiries = pp.enquiriesCount;

            return _staticStats([
              ('$saved', 'Saved', Icons.favorite_border, AppColors.primary),
              ('$visits', 'Visits', Icons.calendar_today_outlined,
                  const Color(0xFF10B981)),
              ('$enquiries', 'Enquiries', Icons.message_outlined,
                  const Color(0xFFF59E0B)),
            ]);
          },
        );
    }
  }

  Widget _staticStats(
      List<(String, String, IconData, Color)> entries) {
    return Row(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              entries[i].$1,
              entries[i].$2,
              entries[i].$3,
              entries[i].$4,
            ),
          ),
        ],
      ],
    ).animate().fadeIn(duration: 400.ms, delay: 100.ms);
  }

  Widget _buildStatCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: AppTextStyles.heading3.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String label) {
    return Text(
      label,
      style: AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (
        Icons.dynamic_feed_rounded,
        'Feed',
        AppColors.primary,
        () => Navigator.pushNamed(context, '/home'),
      ),
      (
        Icons.play_circle_fill_rounded,
        'Reels',
        const Color(0xFF9333EA),
        () => Navigator.pushNamed(context, AppConstants.reelsScreen),
      ),
      (
        Icons.chat_bubble_rounded,
        'Messages',
        Colors.teal,
        () => _showPlaceholder(context, 'Messages'),
      ),
      (
        Icons.people_rounded,
        'Network',
        Colors.indigo,
        () => _showPlaceholder(context, 'Network'),
      ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: actions
          .map((a) => _buildQuickActionButton(a.$1, a.$2, a.$3, a.$4))
          .toList(),
    ).animate().fadeIn(duration: 400.ms, delay: 200.ms);
  }

  Widget _buildQuickActionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Business section ──────────────────────────────────────────────────────

  Widget _buildBusinessSection(BuildContext context, AuthProvider auth) {
    final isBuilder = auth.userType?.toLowerCase() == 'builder';

    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.dashboard_rounded,
        'label': 'Dashboard',
        'subtitle': 'Analytics & management',
        'color': AppColors.primary,
        'onTap': () => _openDashboard(context, auth),
      },
      {
        'icon': Icons.home_work_rounded,
        'label': 'Manage Properties',
        'subtitle': 'Post & edit listings',
        'color': Colors.teal,
        'onTap': () =>
            Navigator.pushNamed(context, AppConstants.postPropertyScreen),
      },
      {
        'icon': Icons.business_center_rounded,
        'label': 'Projects',
        'subtitle': isBuilder ? 'View all projects' : 'Builder feature',
        'color': Colors.indigo,
        'onTap': isBuilder
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BuilderDashboardScreen()),
                )
            : () => _showPlaceholder(context, 'Projects'),
      },
    ];

    return _buildSectionCard(items)
        .animate()
        .fadeIn(duration: 400.ms, delay: 300.ms);
  }

  // ── Account section ───────────────────────────────────────────────────────

  Widget _buildAccountSection(BuildContext context, AuthProvider auth) {
    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.workspace_premium_rounded,
        'label': 'Subscription',
        'subtitle': 'Plans & billing',
        'color': Colors.amber,
        'onTap': () => _showPlaceholder(context, 'Subscription'),
      },
      {
        'icon': Icons.settings_rounded,
        'label': 'Settings',
        'subtitle': 'App preferences',
        'color': AppColors.primary,
        'onTap': () => _showSettingsScreen(context),
      },
      {
        'icon': Icons.logout_rounded,
        'label': 'Logout',
        'subtitle': 'Sign out of your account',
        'color': Colors.red,
        'onTap': () => _showLogoutDialog(context),
      },
    ];

    return _buildSectionCard(items)
        .animate()
        .fadeIn(duration: 400.ms, delay: 400.ms);
  }

  // ── Shared section card ───────────────────────────────────────────────────

  Widget _buildSectionCard(List<Map<String, dynamic>> items) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: AppColors.textHint.withOpacity(0.1),
          indent: 72,
        ),
        itemBuilder: (context, i) {
          final item = items[i];
          final color = item['color'] as Color;
          final isDestructive = color == Colors.red;

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            leading: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item['icon'] as IconData, color: color, size: 22),
            ),
            title: Text(
              item['label'] as String,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: isDestructive ? Colors.red : AppColors.textPrimary,
              ),
            ),
            subtitle: Text(
              item['subtitle'] as String,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            trailing: Icon(
              Icons.chevron_right,
              size: 20,
              color: isDestructive
                  ? Colors.red.withOpacity(0.5)
                  : AppColors.textHint,
            ),
            onTap: item['onTap'] as VoidCallback,
          );
        },
      ),
    );
  }

  // ── Notifications modal (keep) ────────────────────────────────────────────

  void _showNotificationsScreen(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style:
                        AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildNotificationItem(
                    'Visit Scheduled',
                    'Your visit for 3BHK Apartment is confirmed for tomorrow at 10:00 AM',
                    '2 hours ago',
                    Icons.calendar_today,
                    AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationItem(
                    'Property Price Drop',
                    'The 2BHK Flat you saved is now available at 10% less price',
                    '5 hours ago',
                    Icons.trending_down,
                    const Color(0xFF10B981),
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationItem(
                    'New Property Match',
                    'A new property matching your preferences is available in your area',
                    '1 day ago',
                    Icons.home,
                    const Color(0xFFF59E0B),
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationItem(
                    'Visit Reminder',
                    "Don't forget your scheduled visit for Villa tomorrow",
                    '2 days ago',
                    Icons.alarm,
                    const Color(0xFF6366F1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(
    String title,
    String message,
    String time,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  time,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textHint, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Settings modal (keep) ─────────────────────────────────────────────────

  void _showSettingsScreen(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Settings',
                    style:
                        AppTextStyles.heading3.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSettingItem(
                    Icons.dark_mode_outlined,
                    'Dark Mode',
                    'Enable dark theme',
                    false,
                    (value) {},
                  ),
                  const SizedBox(height: 8),
                  _buildSettingItem(
                    Icons.notifications_outlined,
                    'Push Notifications',
                    'Receive visit alerts',
                    true,
                    (value) {},
                  ),
                  const SizedBox(height: 8),
                  _buildSettingItem(
                    Icons.location_on_outlined,
                    'Location Services',
                    'Show nearby properties',
                    true,
                    (value) {},
                  ),
                  const SizedBox(height: 8),
                  _buildSettingItem(
                    Icons.language_outlined,
                    'Language',
                    'English',
                    null,
                    (value) {},
                  ),
                  const SizedBox(height: 8),
                  _buildSettingItem(
                    Icons.email_outlined,
                    'Email Updates',
                    'Weekly property digest',
                    true,
                    (value) {},
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.logout,
                            color: Colors.red, size: 20),
                      ),
                      title: const Text(
                        'Logout',
                        style: TextStyle(
                            color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                      trailing:
                          const Icon(Icons.chevron_right, color: Colors.red),
                      onTap: () {
                        Navigator.pop(context);
                        _showLogoutDialog(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    IconData icon,
    String title,
    String subtitle,
    bool? value,
    Function(bool) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.textHint.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (value != null)
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
            )
          else
            const Icon(Icons.chevron_right, color: AppColors.textHint),
        ],
      ),
    );
  }

  // ── Logout dialog (keep) ──────────────────────────────────────────────────

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final authProvider =
                  Provider.of<AuthProvider>(context, listen: false);
              authProvider.logout();
              Navigator.of(context).pop();
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ── Edit profile dialog fallback for individual users (keep) ──────────────

  void _showEditProfileDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final nameController =
        TextEditingController(text: authProvider.userName);
    final emailController =
        TextEditingController(text: authProvider.userEmail);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final emailVal = emailController.text.trim();
              final nameErr = Validators.required(name);
              final emailErr =
                  Validators.required(emailVal) ?? Validators.email(emailVal);
              if (nameErr != null || emailErr != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(nameErr ?? emailErr!)),
                );
                return;
              }
              authProvider.updateProfile(name, emailVal);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile updated successfully')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
