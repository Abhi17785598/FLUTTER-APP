import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/property_provider.dart';
import '../../widgets/bottom_nav_bar.dart';

class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});

  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Consumer<PropertyProvider>(
          builder: (context, propertyProvider, child) {
            return Column(
              children: [
                _buildAppBar(context, propertyProvider),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUpcomingVisits(propertyProvider),
                      _buildCompletedVisits(propertyProvider),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 3,
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, PropertyProvider propertyProvider) {
    final totalVisits = propertyProvider.visits.where((v) => v['status'] != 'Cancelled').length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'My Visits',
            style: AppTextStyles.heading2,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$totalVisits Visits',
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

  Widget _buildTabBar() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: LinearGradient(
        colors: [
          AppColors.cardBackground.withOpacity(0.95),
          AppColors.cardBackground.withOpacity(0.75),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: AppColors.primary.withOpacity(0.12),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: AppColors.primary.withOpacity(0.08),
          blurRadius: 12,
          spreadRadius: 1,
        ),
      ],
    ),
    child: TabBar(
      controller: _tabController,
      dividerColor: Colors.transparent,
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      indicatorSize: TabBarIndicatorSize.tab,
      splashBorderRadius: BorderRadius.circular(14),
      labelColor: Colors.white,
      unselectedLabelColor: AppColors.textSecondary.withOpacity(0.8),
      labelStyle: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
      unselectedLabelStyle: AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      tabs: const [
        Tab(text: 'Upcoming'),
        Tab(text: 'Completed'),
      ],
    ),
  );
}

  Widget _buildUpcomingVisits(PropertyProvider propertyProvider) {
    final upcomingVisits = propertyProvider.visits.where((v) => v['isUpcoming'] == true).toList();

    if (upcomingVisits.isEmpty) {
      return _buildEmptyState('No upcoming visits', 'Schedule a visit to see properties');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: upcomingVisits.length,
      itemBuilder: (context, index) {
        final visit = upcomingVisits[index];
        return _buildVisitCard(visit, propertyProvider, isUpcoming: true);
      },
    );
  }

  Widget _buildCompletedVisits(PropertyProvider propertyProvider) {
    final completedVisits = propertyProvider.visits.where((v) => v['isUpcoming'] == false).toList();

    if (completedVisits.isEmpty) {
      return _buildEmptyState('No completed visits', 'Your completed visits will appear here');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: completedVisits.length,
      itemBuilder: (context, index) {
        final visit = completedVisits[index];
        return _buildVisitCard(visit, propertyProvider, isUpcoming: false);
      },
    );
  }

  Widget _buildVisitCard(Map<String, dynamic> visit, PropertyProvider propertyProvider, {required bool isUpcoming}) {
    final status = visit['status'] as String;
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  visit['title'] as String,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isUpcoming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'Confirmed'
                        ? AppColors.success.withOpacity(0.2)
                        : status == 'Cancelled'
                            ? Colors.red.withOpacity(0.2)
                            : AppColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    style: AppTextStyles.caption.copyWith(
                      color: status == 'Confirmed'
                          ? AppColors.success
                          : status == 'Cancelled'
                              ? Colors.red
                              : AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  visit['location'] as String,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildInfoChip(Icons.calendar_today, visit['date'] as String),
              const SizedBox(width: 8),
              _buildInfoChip(Icons.access_time, visit['time'] as String),
            ],
          ),
          const SizedBox(height: 12),
          if (isUpcoming) ...[
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  visit['agentName'] as String,
                  style: AppTextStyles.caption,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.phone, size: 20),
                  onPressed: () {
                    // Call agent
                  },
                  color: AppColors.primary,
                ),
              ],
            ),
            if (status != 'Cancelled') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _showCancelDialog(context, visit['propertyId'] as String, propertyProvider);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Cancel Visit', style: TextStyle(color: Colors.red)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          AppConstants.propertyDetailScreen,
                          arguments: {'propertyId': visit['propertyId']},
                        );
                      },
                      child: const Text('View Property'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppConstants.propertyDetailScreen,
                      arguments: {'propertyId': visit['propertyId']},
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('View Property'),
                ),
              ),
            ],
          ] else ...[
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  visit['agentName'] as String,
                  style: AppTextStyles.caption,
                ),
                const Spacer(),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < (visit['rating'] as int)
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: Colors.amber,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppConstants.propertyDetailScreen,
                    arguments: {'propertyId': visit['propertyId']},
                  );
                },
                child: const Text('Book Again'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
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
          Text(
            title,
            style: AppTextStyles.heading3,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pushNamed(context, AppConstants.homeScreen);
            },
            icon: const Icon(Icons.search),
            label: const Text('Browse Properties'),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String propertyId, PropertyProvider propertyProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Visit'),
        content: const Text('Are you sure you want to cancel this visit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              propertyProvider.cancelVisit(propertyId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Visit cancelled successfully')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
}
