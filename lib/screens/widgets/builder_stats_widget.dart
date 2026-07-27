import 'package:flutter/material.dart';
import '../../models/builder_dashboard_model.dart';
import '../../services/builder_dashboard_service.dart';

class BuilderStatsWidget extends StatelessWidget {
  final BuilderDashboardModel stats;

  const BuilderStatsWidget({
    super.key,
    required this.stats,
  });

  Widget _card(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color accent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 12),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withOpacity(0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      accent.withOpacity(0.18),
                      accent.withOpacity(0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(icon, size: 24, color: accent),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final entries = <(String, String, IconData, Color)>[
      ('Total Projects', stats.totalProjects.toString(), Icons.business_rounded, scheme.primary),
      ('Active Projects', stats.activeProjects.toString(), Icons.trending_up_rounded, Colors.teal),
      ('Delivered', stats.deliveredProjects.toString(), Icons.check_circle_rounded, Colors.green),
      ('Network Members', stats.networkMembers.toString(), Icons.people_alt_rounded, Colors.indigo),
      ('Customer Rating', stats.customerRating.toStringAsFixed(1), Icons.star_rounded, Colors.amber),
      ('Broker Rating', stats.brokerRating.toStringAsFixed(1), Icons.workspace_premium_rounded, Colors.deepPurple),
    ];

    return Column(
      children: [
        for (final e in entries) _card(context, e.$1, e.$2, e.$3, e.$4),
      ],
    );
  }
}