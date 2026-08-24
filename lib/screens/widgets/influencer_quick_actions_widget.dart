import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

class InfluencerQuickActionsWidget extends StatelessWidget {
  const InfluencerQuickActionsWidget({super.key});

  Widget _action(IconData icon, String title, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withOpacity(.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Was `() {}` — a button labelled "Upload Video" that did nothing.
            // The other three below still have no destination; wiring them is
            // not routing this app can currently satisfy (Analytics and
            // Campaigns live on this same dashboard's other tabs, and there is
            // no earnings screen at all).
            _action(
              Icons.video_call_rounded,
              "Upload Video",
              Colors.red,
              () => Navigator.pushNamed(
                context,
                AppConstants.influencerVideoFormScreen,
              ),
            ),
            const SizedBox(width: 14),
            _action(Icons.analytics_rounded, "Analytics", Colors.blue, () {}),
          ],
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            _action(Icons.campaign_rounded, "Campaigns", Colors.green, () {}),
            const SizedBox(width: 14),
            _action(Icons.payments_rounded, "Earnings", Colors.orange, () {}),
          ],
        ),
      ],
    );
  }
}
