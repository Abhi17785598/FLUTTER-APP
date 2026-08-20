import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/reel_model.dart';
import '../../../providers/property_provider.dart';
import '../../../providers/reels_provider.dart';
import '../../../widgets/property_card_compact.dart';

/// "My Activity" — Liked / Saved tabs, mirroring the portal's
/// `IndividualUserActivity.tsx` (rendered inside `ProfileDashboardShell`).
/// Reads straight from `PropertyProvider`'s existing, already-persisted
/// `user_likes`/`saved_properties`-backed state — no new data source, no new
/// table. Scoped to properties only, except the "Saved" tab which also
/// exposes a Properties/Reels filter (mirroring the portal's Properties/
/// Projects/Reels filter pills inside its own "Saved" tab), backed by
/// `ReelsProvider`'s `saved_reels`-persisted state. Projects and the "Liked"
/// tab's Reels filter aren't replicated — out of scope for this fix.
class MyActivitySection extends StatefulWidget {
  const MyActivitySection({super.key});

  @override
  State<MyActivitySection> createState() => _MyActivitySectionState();
}

class _MyActivitySectionState extends State<MyActivitySection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 2, vsync: this);

  /// Which filter is active inside the "Saved" tab — mirrors the portal's
  /// Properties/Reels filter pills. Defaults to Properties, matching the
  /// tab's pre-existing behavior.
  bool _showSavedReels = false;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<PropertyProvider, ReelsProvider>(
      builder: (context, propertyProvider, reelsProvider, _) {
        final liked = propertyProvider.getLikedProperties();
        final saved = propertyProvider.getShortlistedProperties();
        final savedReels = reelsProvider.getSavedReels();

        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textHint.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.favorite, size: 16),
                        const SizedBox(width: 6),
                        Text('Liked (${liked.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bookmark, size: 16),
                        const SizedBox(width: 6),
                        Text('Saved (${saved.length})'),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 260,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _ActivityList(
                      properties: liked,
                      emptyText: 'No liked properties yet',
                      onFavoriteToggle: (id) => propertyProvider.toggleLike(id),
                    ),
                    Column(
                      children: [
                        _SavedFilterPills(
                          showReels: _showSavedReels,
                          savedCount: saved.length,
                          savedReelsCount: savedReels.length,
                          onChanged: (showReels) =>
                              setState(() => _showSavedReels = showReels),
                        ),
                        Expanded(
                          child: _showSavedReels
                              ? _SavedReelsList(
                                  reels: savedReels,
                                  emptyText: 'No saved reels yet',
                                )
                              : _ActivityList(
                                  properties: saved,
                                  emptyText: 'No saved properties yet',
                                  onFavoriteToggle: (id) =>
                                      propertyProvider.toggleShortlist(id),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Properties/Reels filter pills inside the "Saved" tab — mirrors the
/// portal's filter buttons inside `IndividualUserActivity`'s "Saved" tab
/// (Projects isn't replicated here; out of scope).
class _SavedFilterPills extends StatelessWidget {
  const _SavedFilterPills({
    required this.showReels,
    required this.savedCount,
    required this.savedReelsCount,
    required this.onChanged,
  });

  final bool showReels;
  final int savedCount;
  final int savedReelsCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _FilterChip(
            label: 'Properties ($savedCount)',
            icon: Icons.home_outlined,
            selected: !showReels,
            onTap: () => onChanged(false),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Reels ($savedReelsCount)',
            icon: Icons.video_collection_outlined,
            selected: showReels,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : AppColors.textHint.withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: selected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders saved reels as compact thumbnail rows — mirrors the portal's
/// `ReelItem` inside `IndividualUserActivity` (thumbnail + title + "Reel"
/// label, no inline unsave affordance there either; unsaving happens via the
/// bookmark icon in the reel player itself). Tapping opens the reel player
/// scrolled to that reel.
class _SavedReelsList extends StatelessWidget {
  const _SavedReelsList({required this.reels, required this.emptyText});

  final List<ReelModel> reels;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (reels.isEmpty) {
      return Center(child: Text(emptyText, style: AppTextStyles.caption));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: reels.length,
      itemBuilder: (context, index) {
        final reel = reels[index];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            AppConstants.reelsScreen,
            arguments: {'reelId': reel.id},
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: reel.previewImageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 56,
                          height: 56,
                          color: AppColors.textHint.withOpacity(0.1),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 56,
                          height: 56,
                          color: AppColors.textHint.withOpacity(0.1),
                          child: const Icon(Icons.video_collection_outlined),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reel.title.isNotEmpty ? reel.title : 'Untitled reel',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text('Reel', style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({
    required this.properties,
    required this.emptyText,
    required this.onFavoriteToggle,
  });

  final List properties;
  final String emptyText;
  final void Function(String propertyId) onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return Center(
        child: Text(emptyText, style: AppTextStyles.caption),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index];
        return PropertyCardCompact(
          property: property,
          onTap: () => Navigator.pushNamed(
            context,
            AppConstants.propertyDetailScreen,
            arguments: {'propertyId': property.id},
          ),
          onFavoriteToggle: () => onFavoriteToggle(property.id),
        );
      },
    );
  }
}
