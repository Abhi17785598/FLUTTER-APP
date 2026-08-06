import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import '../../widgets/shared/app_surface_card.dart';
import '../../widgets/shared/toggle_row.dart';
import '../shared/section_loader.dart';
import 'widgets/social_screen_shell.dart';

/// Social ▸ Preferences — the design's `isSocialPreferences` screen.
///
/// Renders the caller's `social_share_preferences` row: seven auto-share
/// switches, six default-target switches, and the caption defaults.
///
/// The switches are **read-only in this phase**. React's `savePreferences`
/// upserts the row, but two things argue against wiring it up here: no Meta
/// account can be connected yet (the mobile OAuth strategy is an open
/// decision), so saved preferences would drive nothing; and every phase to date
/// has been read-only. They reflect the stored values and are visibly
/// non-interactive rather than silently discarding taps.
class SocialPreferencesScreen extends StatelessWidget {
  const SocialPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SocialPreferencesSection(),
      child: const _PreferencesView(),
    );
  }
}

class _PreferencesView extends StatefulWidget {
  const _PreferencesView();

  @override
  State<_PreferencesView> createState() => _PreferencesViewState();
}

class _PreferencesViewState extends State<_PreferencesView>
    with DeferredSectionLoader<_PreferencesView> {
  @override
  void loadSection(String userId) =>
      context.read<SocialPreferencesSection>().loadFor(userId);

  @override
  Widget build(BuildContext context) {
    final section = context.watch<SocialPreferencesSection>();

    return SocialPreferencesBody(
      preferences: section.value,
      loading: section.loading,
      failed: section.failed,
    );
  }
}

class SocialPreferencesBody extends StatelessWidget {
  final SocialPreferences preferences;
  final bool loading;
  final bool failed;

  const SocialPreferencesBody({
    super.key,
    required this.preferences,
    required this.loading,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    final prefs = preferences;

    return SocialScreenShell(
      title: 'Preferences',
      subtitle: 'Auto-share & publishing defaults',
      bottomPadding: 100,
      children: [
        const SizedBox(height: 18),
        if (failed)
          DashboardCard(
            child: Text(
              "Couldn't load your preferences. Try again in a moment.",
              style: AppTextStyles.caption.copyWith(
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          )
        else ...[
          const _ReadOnlyNotice(),
          const SizedBox(height: 14),
          DashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SocialCardHeading(
                  'Auto-share',
                  'Automatically pre-select publishing when you create these.',
                ),
                const SizedBox(height: 14),
                ..._toggles(const [
                  'Properties',
                  'Projects',
                  'Videos',
                  'Reels',
                  'Blogs',
                  'Promotions',
                  'Open Houses',
                ], [
                  prefs.autoShareProperty,
                  prefs.autoShareProjects,
                  prefs.autoShareVideos,
                  prefs.autoShareReels,
                  prefs.autoShareBlogs,
                  prefs.autoSharePromotions,
                  prefs.autoShareOpenHouses,
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SocialCardHeading(
                  'Default targets',
                  'Which platforms/placements are pre-checked on '
                      '"Publish Everywhere".',
                ),
                const SizedBox(height: 14),
                ..._toggles(const [
                  'Facebook',
                  'Instagram',
                  'Instagram Feed',
                  'Instagram Reel',
                  'Facebook Story',
                  'Instagram Story',
                ], [
                  prefs.fbEnabled,
                  prefs.igEnabled,
                  prefs.igFeed,
                  prefs.igReel,
                  prefs.fbStory,
                  prefs.igStory,
                ]),
              ],
            ),
          ),
          const SizedBox(height: 14),
          DashboardCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SocialCardHeading(
                  'Caption defaults',
                  "Captions are written automatically from each item's title "
                      '& details.',
                ),
                const SizedBox(height: 14),
                const SocialFieldLabel('Auto-share rule'),
                const SizedBox(height: 6),
                SocialValueBox(
                  value: prefs.autoShareRuleLabel,
                  placeholder: 'Every item',
                ),
                const SizedBox(height: 14),
                const SocialFieldLabel(
                  'Default hashtags (comma separated, max 30)',
                ),
                const SizedBox(height: 6),
                SocialValueBox(
                  value: prefs.defaultHashtags.join(', '),
                  placeholder: 'None set',
                ),
                const SizedBox(height: 14),
                const SocialFieldLabel('Default call to action'),
                const SizedBox(height: 6),
                SocialValueBox(
                  value: prefs.defaultCta,
                  placeholder: 'None set',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// The design's 46 dp bordered switch rows, 8 dp apart.
  ///
  /// `onChanged: null` renders each dimmed and inert — the honest signal that
  /// this screen reports the stored value rather than changing it.
  List<Widget> _toggles(List<String> labels, List<bool> values) {
    final rows = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(
        ToggleRow(
          label: labels[i],
          value: values[i],
          bordered: true,
        ),
      );
    }
    return rows;
  }
}

/// States plainly that the switches report rather than change.
class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'These settings are shown as saved on the web portal. Editing '
              'them here becomes available once account connection ships.',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                height: 1.45,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
