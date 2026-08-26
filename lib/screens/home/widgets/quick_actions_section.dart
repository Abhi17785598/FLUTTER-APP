import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/scale_tap.dart';

class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.route,
    this.args,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String route;
  final Map<String, dynamic>? args;
}

/// Premium quick-action cards — Compare, Visits, Post Property, with a
/// gradient icon badge and a subtitle.
///
/// EMI Calculator used to be a 4th card here, duplicating the EMI Calculator
/// tool that also lives in `SmartToolsSection`'s "Smart Tools" rail (the
/// portal's "Useful Tools" grouping) further down the same page — the exact
/// duplicate this list existed to avoid. That entry was removed; Smart Tools
/// is now the Homepage's single EMI Calculator entry point.
class QuickActionsSection extends StatelessWidget {
  const QuickActionsSection({super.key});

  static const List<_QuickAction> _actions = [
    _QuickAction(
      label: 'Compare',
      subtitle: 'Find better deals',
      icon: Icons.compare_arrows_rounded,
      gradient: [Color(0xFF8B5CF6), Color(0xFFA78BFA)],
      route: AppConstants.comparePropertiesScreen,
      args: {'propertyIds': <String>[]},
    ),
    _QuickAction(
      label: 'Visits',
      subtitle: 'Manage site visits',
      icon: Icons.calendar_month_rounded,
      gradient: [Color(0xFF10B981), Color(0xFF34D399)],
      route: AppConstants.visitsScreen,
    ),
    _QuickAction(
      label: 'Post Property',
      subtitle: 'List in minutes',
      icon: Icons.add_home_rounded,
      gradient: [Color(0xFFF97316), Color(0xFFFB923C)],
      route: AppConstants.postPropertyScreen,
    ),
  ];

  static const double _cardSpacing = 12;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (var i = 0; i < _actions.length; i++) ...[
            if (i != 0) const SizedBox(width: _cardSpacing),
            Expanded(child: _QuickActionCard(action: _actions[i])),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 400.ms, delay: 80.ms);
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: () => Navigator.pushNamed(
        context,
        action.route,
        arguments: action.args,
      ),
      child: Container(
        height: 108,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: action.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: action.gradient.first.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(action.icon, color: Colors.white, size: 20),
            ),
            const Spacer(),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              action.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
