// screens/visits/visits_screen.dart
//
// "My Visits" — ports the portal's `MyVisitRequests.tsx` exactly.
//
// The reference has NO Upcoming/Completed split: it is one flat list mixing
// every status (`pending`, `confirmed`, `completed`, `cancelled`,
// `rescheduled`), distinguished only by a colored status badge
// (MyVisitRequests.tsx:28-34), sorted by `created_at` descending
// (`:141-145`). The only interaction is tapping a card, which navigates to
// the property/project/profile page the visit was requested against
// (`:153-163`) — there is no Call button, no phone number shown, no
// "Book Again" button, and no Cancel/Reschedule action anywhere on this
// screen. Data comes from `VisitRequestsService.fetchMine`, merging
// `property_visit_bookings`, `project_visit_bookings` and
// `profile_visit_requests` — the same three tables the reference reads.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/visit_request_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../services/visit_requests_service.dart';
import '../../widgets/bottom_nav_bar.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key, this.service});

  /// Injected by tests.
  @visibleForTesting
  final VisitRequestsService? service;

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  late final VisitRequestsService _visits = widget.service ?? VisitRequestsService();

  List<VisitRequestItem>? _items;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Keeps the bottom nav's highlighted tab in sync when this screen is
      // opened directly rather than via a bottom-nav tap — unrelated to
      // Visit data, carried over unchanged from the previous screen.
      Provider.of<NavigationProvider>(context, listen: false).setIndex(3);
      _load();
    });
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      setState(() {
        _items = const [];
        _failed = false;
      });
      return;
    }

    setState(() => _failed = false);
    try {
      final rows = await _visits.fetchMine(userId);
      if (!mounted) return;
      setState(() => _items = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _openTarget(VisitRequestItem item) {
    switch (item.source) {
      case VisitRequestSource.property:
        Navigator.pushNamed(
          context,
          AppConstants.propertyDetailScreen,
          arguments: {'propertyId': item.targetId},
        );
      case VisitRequestSource.project:
        Navigator.pushNamed(
          context,
          AppConstants.projectDetailScreen,
          arguments: {'projectId': item.targetId},
        );
      case VisitRequestSource.profile:
        Navigator.pushNamed(
          context,
          AppConstants.publicProfileScreen,
          arguments: {'userId': item.targetId},
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }

  Widget _buildAppBar() {
    final total = _items?.length ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('My Visits', style: AppTextStyles.heading2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$total Visits',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final items = _items;
    if (items == null && !_failed) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.textHint.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text("Couldn't load your visits", style: AppTextStyles.heading3),
            const SizedBox(height: 8),
            Text('Check your connection and try again.', style: AppTextStyles.caption),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (items!.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) => _VisitCard(
        item: items[index],
        onTap: () => _openTarget(items[index]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: AppColors.textHint.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text('No visits yet', style: AppTextStyles.heading3),
          const SizedBox(height: 8),
          Text(
            'Requests you make to visit a property will appear here.',
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppConstants.homeScreen),
            icon: const Icon(Icons.search),
            label: const Text('Browse Properties'),
          ),
        ],
      ),
    );
  }
}

/// One visit request card — mirrors `MyVisitRequests.tsx`'s `RequestItem`
/// (`:159-204`): thumbnail, title, status badge, optional location line,
/// date/time line. The whole card is the tap target (`:161`) — there is no
/// separate button.
class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.item, required this.onTap});

  final VisitRequestItem item;
  final VoidCallback onTap;

  IconData get _fallbackIcon => switch (item.source) {
        VisitRequestSource.property => Icons.apartment_rounded,
        VisitRequestSource.project => Icons.layers_rounded,
        VisitRequestSource.profile => Icons.person_rounded,
      };

  /// `statusStyles` (MyVisitRequests.tsx:28-34).
  Color get _statusColor => switch (item.status.toLowerCase()) {
        'pending' => AppColors.warning,
        'confirmed' => AppColors.success,
        'completed' => const Color(0xFF7C3AED),
        'cancelled' => AppColors.error,
        'rescheduled' => AppColors.primary,
        _ => AppColors.textSecondary,
      };

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `new Date(request.preferred_date).toLocaleDateString("en-IN", {day:
  /// "numeric", month: "short", year: "numeric"})` (MyVisitRequests.tsx:195).
  String? get _formattedDate {
    final raw = item.preferredDate;
    if (raw == null || raw.isEmpty) return null;
    final date = DateTime.tryParse(raw);
    if (date == null) return raw;
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formattedDate;
    final time = item.preferredTime;

    return Semantics(
      button: true,
      label: '${item.title}, ${item.status}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.textHint.withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: item.imageUrl == null
                      ? ColoredBox(
                          color: AppColors.primaryLight.withOpacity(0.15),
                          child: Icon(_fallbackIcon, size: 24, color: AppColors.primary),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.imageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => ColoredBox(
                            color: AppColors.primaryLight.withOpacity(0.15),
                            child: Icon(_fallbackIcon, size: 24, color: AppColors.primary),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.status,
                            style: AppTextStyles.caption.copyWith(
                              color: _statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.location.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              item.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (formattedDate != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 13, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(formattedDate, style: AppTextStyles.caption),
                          if (time != null && time.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            const Icon(Icons.access_time, size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(time, style: AppTextStyles.caption),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
