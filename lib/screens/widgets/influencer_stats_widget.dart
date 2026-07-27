import 'package:flutter/material.dart';

import '../../models/influencer_dashboard_model.dart';

class InfluencerStatsWidget extends StatelessWidget {
  final InfluencerDashboardModel stats;

  const InfluencerStatsWidget({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.35,
      children: [
        _card(
          "Videos",
          stats.totalVideos.toString(),
          Icons.video_library_rounded,
          Colors.red,
        ),
        _card(
          "Campaigns",
          stats.activeCampaigns.toString(),
          Icons.campaign_rounded,
          Colors.blue,
        ),
        _card(
          "Views",
          stats.totalViews.toString(),
          Icons.visibility_rounded,
          Colors.green,
        ),
        _card(
          "Earnings",
          "₹${stats.totalEarnings.toStringAsFixed(0)}",
          Icons.payments_rounded,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _card(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: color.withOpacity(.12),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}