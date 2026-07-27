import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/bottom_nav_bar.dart';

// ─────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────
enum NotifType { priceDrop, visitReminder, newMatch, enquiry, system }

class _Notif {
  final String id;
  final NotifType type;
  final String title;
  final String subtitle;
  final String time;
  bool isRead;
  final String? propertyId;
  final String? imageUrl;

  _Notif({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isRead = false,
    this.propertyId,
    this.imageUrl,
  });
}

// ─────────────────────────────────────────────
//  Screen
// ─────────────────────────────────────────────
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _activeFilter = 'All';

  final List<String> _filters = ['All', 'Price Drop', 'Visits', 'Matches', 'Enquiries'];

  final List<_Notif> _notifications = [
    _Notif(
      id: '1',
      type: NotifType.priceDrop,
      title: 'Price Drop Alert 🎉',
      subtitle: 'Luxury 3BHK in Gachibowli dropped by ₹5L. New price: ₹1.20 Cr',
      time: '2 min ago',
      isRead: false,
      imageUrl: 'https://picsum.photos/seed/property1/80/80',
    ),
    _Notif(
      id: '2',
      type: NotifType.visitReminder,
      title: 'Visit Reminder ⏰',
      subtitle: 'Your site visit for Prestige Falcon City is scheduled today at 3:00 PM',
      time: '1 hr ago',
      isRead: false,
      imageUrl: 'https://picsum.photos/seed/property2/80/80',
    ),
    _Notif(
      id: '3',
      type: NotifType.newMatch,
      title: 'New Match Found ✨',
      subtitle: '3 new properties in Whitefield match your saved search criteria',
      time: '3 hrs ago',
      isRead: false,
    ),
    _Notif(
      id: '4',
      type: NotifType.enquiry,
      title: 'Enquiry Reply',
      subtitle: 'DLF Camellias builder responded to your query about payment plans',
      time: 'Yesterday',
      isRead: true,
      imageUrl: 'https://picsum.photos/seed/property4/80/80',
    ),
    _Notif(
      id: '5',
      type: NotifType.priceDrop,
      title: 'Price Drop Alert 🎉',
      subtitle: '2BHK in Koramangala dropped by ₹2.5L. Don\'t miss out!',
      time: 'Yesterday',
      isRead: true,
      imageUrl: 'https://picsum.photos/seed/property5/80/80',
    ),
    _Notif(
      id: '6',
      type: NotifType.newMatch,
      title: 'Trending in Your Area 🔥',
      subtitle: '5 properties trending in Bangalore within ₹80L budget',
      time: '2 days ago',
      isRead: true,
    ),
    _Notif(
      id: '7',
      type: NotifType.system,
      title: 'Profile Verified ✅',
      subtitle: 'Your profile has been successfully verified. Enjoy premium features!',
      time: '3 days ago',
      isRead: true,
    ),
    _Notif(
      id: '8',
      type: NotifType.visitReminder,
      title: 'Visit Feedback Pending',
      subtitle: 'How was your visit to Godrej Splendour? Share your experience',
      time: '4 days ago',
      isRead: true,
      imageUrl: 'https://picsum.photos/seed/property8/80/80',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<NavigationProvider>(context, listen: false).setIndex(3);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<_Notif> get _filtered {
    if (_activeFilter == 'All') return _notifications;
    final typeMap = {
      'Price Drop': NotifType.priceDrop,
      'Visits': NotifType.visitReminder,
      'Matches': NotifType.newMatch,
      'Enquiries': NotifType.enquiry,
    };
    final t = typeMap[_activeFilter];
    return _notifications.where((n) => n.type == t).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  void _markAllRead() {
    setState(() {
      for (final n in _notifications) {
        n.isRead = true;
      }
    });
  }

  void _markRead(String id) {
    setState(() {
      final n = _notifications.firstWhere((n) => n.id == id);
      n.isRead = true;
    });
  }

  void _dismiss(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification dismissed'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        action: SnackBarAction(label: 'Undo', onPressed: () {}),
      ),
    );
  }

  // ─── UI ───────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            _buildFilterRow(),
            Expanded(
              child: _filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) =>
                          _buildCard(_filtered[i]),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppColors.cardShadow,
              ),
              child: const Icon(Icons.arrow_back_ios_new, size: 16,
                  color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Notifications', style: AppTextStyles.heading2),
          ),
          if (_unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_unreadCount new',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _markAllRead,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  const Icon(Icons.done_all, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text('Mark all read',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _filters.length,
        itemBuilder: (context, i) {
          final f = _filters[i];
          final isActive = _activeFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: AppConstants.animationDurationMs),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.primaryGradient : null,
                color: isActive ? null : Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.chipRadius * 2),
                boxShadow: isActive ? AppColors.primaryGlow : AppColors.cardShadow,
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard(_Notif n) {
    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 22),
      ),
      onDismissed: (_) => _dismiss(n.id),
      child: GestureDetector(
        onTap: () => _markRead(n.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: n.isRead ? Colors.white : AppColors.primaryLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            border: n.isRead
                ? null
                : Border.all(color: AppColors.primary.withOpacity(0.15), width: 1),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(n),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  n.isRead ? FontWeight.w500 : FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (!n.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n.subtitle,
                      style: AppTextStyles.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 11, color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Text(n.time,
                            style: TextStyle(
                                fontSize: 10, color: AppColors.textHint)),
                        const Spacer(),
                        if (n.propertyId != null || n.imageUrl != null)
                          GestureDetector(
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppConstants.propertyDetailScreen,
                              arguments: {'propertyId': n.propertyId ?? '1'},
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('View',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(_Notif n) {
    if (n.imageUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          n.imageUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _iconFallback(n),
        ),
      );
    }
    return _iconFallback(n);
  }

  Widget _iconFallback(_Notif n) {
    final Map<NotifType, Map<String, dynamic>> cfg = {
      NotifType.priceDrop: {
        'icon': Icons.trending_down_rounded,
        'color': AppColors.success,
        'bg': const Color(0xFFDCFCE7),
      },
      NotifType.visitReminder: {
        'icon': Icons.calendar_today_outlined,
        'color': AppColors.primary,
        'bg': AppColors.primaryLight,
      },
      NotifType.newMatch: {
        'icon': Icons.auto_awesome,
        'color': const Color(0xFFF59E0B),
        'bg': const Color(0xFFFEF3C7),
      },
      NotifType.enquiry: {
        'icon': Icons.chat_bubble_outline_rounded,
        'color': AppColors.statusBooked,
        'bg': const Color(0xFFFFF7ED),
      },
      NotifType.system: {
        'icon': Icons.shield_outlined,
        'color': AppColors.textSecondary,
        'bg': AppColors.background,
      },
    };
    final c = cfg[n.type]!;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: c['bg'] as Color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(c['icon'] as IconData,
          size: 22, color: c['color'] as Color),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 38, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text('No notifications', style: AppTextStyles.heading3),
          const SizedBox(height: 6),
          Text('You\'re all caught up!', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}