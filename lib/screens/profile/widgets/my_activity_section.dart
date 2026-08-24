import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/compare_toggle_handler.dart';
import '../../../models/project_model.dart';
import '../../../models/reel_model.dart';
import '../../../providers/compare_provider.dart';
import '../../../providers/projects_provider.dart';
import '../../../providers/property_provider.dart';
import '../../../providers/reels_provider.dart';
import '../../../widgets/property_card_compact.dart';
import '../../dashboard/widgets/my_projects_section.dart'
    show projectPriceRangeLabel;

/// "My Activity" — Liked / Saved tabs, mirroring the portal's
/// `IndividualUserActivity.tsx` (rendered inside `ProfileDashboardShell`).
/// Both tabs expose the same Properties/Projects/Reels filter pills the
/// portal shows inside each of its own Liked/Saved tabs, backed by:
///  - Properties: `PropertyProvider`'s existing `user_likes`/
///    `saved_properties`-backed state.
///  - Reels: `ReelsProvider`'s existing `user_likes`/`saved_reels`-backed
///    state.
///  - Projects: `ProjectsProvider`'s `user_likes`/`saved_projects`-backed
///    state.
/// No new data source beyond what each provider already persists.
class MyActivitySection extends StatefulWidget {
  const MyActivitySection({super.key});

  @override
  State<MyActivitySection> createState() => _MyActivitySectionState();
}

/// Which content type is shown inside a Liked/Saved tab — mirrors the
/// portal's Properties/Projects/Reels filter pills.
enum _ContentFilter { properties, projects, reels }

class _MyActivitySectionState extends State<MyActivitySection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  _ContentFilter _likedFilter = _ContentFilter.properties;
  _ContentFilter _savedFilter = _ContentFilter.properties;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final compareProvider = context.watch<CompareProvider>();
    return Consumer3<PropertyProvider, ReelsProvider, ProjectsProvider>(
      builder: (context, propertyProvider, reelsProvider, projectsProvider, _) {
        final likedProperties = propertyProvider.getLikedProperties();
        final likedProjects = projectsProvider.getLikedProjects();
        final likedReels = reelsProvider.getLikedReels();

        final savedProperties = propertyProvider.getShortlistedProperties();
        final savedProjects = projectsProvider.getSavedProjects();
        final savedReels = reelsProvider.getSavedReels();

        final likedTotal =
            likedProperties.length + likedProjects.length + likedReels.length;
        final savedTotal =
            savedProperties.length + savedProjects.length + savedReels.length;

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
                        Text('Liked ($likedTotal)'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bookmark, size: 16),
                        const SizedBox(width: 6),
                        Text('Saved ($savedTotal)'),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 300,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    Column(
                      children: [
                        _ContentFilterPills(
                          current: _likedFilter,
                          propertiesCount: likedProperties.length,
                          projectsCount: likedProjects.length,
                          reelsCount: likedReels.length,
                          onChanged: (f) => setState(() => _likedFilter = f),
                        ),
                        Expanded(
                          child: switch (_likedFilter) {
                            _ContentFilter.properties => _ActivityList(
                              properties: likedProperties,
                              emptyText: 'No liked properties yet',
                              onFavoriteToggle: (id) =>
                                  propertyProvider.toggleLike(id),
                              compareProvider: compareProvider,
                            ),
                            _ContentFilter.projects => _ProjectsList(
                              projects: likedProjects,
                              emptyText: 'No liked projects yet',
                            ),
                            _ContentFilter.reels => _ReelsList(
                              reels: likedReels,
                              emptyText: 'No liked reels yet',
                            ),
                          },
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        _ContentFilterPills(
                          current: _savedFilter,
                          propertiesCount: savedProperties.length,
                          projectsCount: savedProjects.length,
                          reelsCount: savedReels.length,
                          onChanged: (f) => setState(() => _savedFilter = f),
                        ),
                        Expanded(
                          child: switch (_savedFilter) {
                            _ContentFilter.properties => _ActivityList(
                              properties: savedProperties,
                              emptyText: 'No saved properties yet',
                              onFavoriteToggle: (id) =>
                                  propertyProvider.toggleShortlist(id),
                              compareProvider: compareProvider,
                            ),
                            _ContentFilter.projects => _ProjectsList(
                              projects: savedProjects,
                              emptyText: 'No saved projects yet',
                            ),
                            _ContentFilter.reels => _ReelsList(
                              reels: savedReels,
                              emptyText: 'No saved reels yet',
                            ),
                          },
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

/// Properties/Projects/Reels filter pills inside a Liked/Saved tab — mirrors
/// the portal's filter buttons inside `IndividualUserActivity`'s Liked/Saved
/// tabs.
class _ContentFilterPills extends StatelessWidget {
  const _ContentFilterPills({
    required this.current,
    required this.propertiesCount,
    required this.projectsCount,
    required this.reelsCount,
    required this.onChanged,
  });

  final _ContentFilter current;
  final int propertiesCount;
  final int projectsCount;
  final int reelsCount;
  final ValueChanged<_ContentFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _FilterChip(
            label: 'Properties ($propertiesCount)',
            icon: Icons.home_outlined,
            selected: current == _ContentFilter.properties,
            onTap: () => onChanged(_ContentFilter.properties),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Projects ($projectsCount)',
            icon: Icons.apartment_outlined,
            selected: current == _ContentFilter.projects,
            onTap: () => onChanged(_ContentFilter.projects),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Reels ($reelsCount)',
            icon: Icons.video_collection_outlined,
            selected: current == _ContentFilter.reels,
            onTap: () => onChanged(_ContentFilter.reels),
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

/// Renders liked/saved reels as compact thumbnail rows — mirrors the portal's
/// `ReelItem` inside `IndividualUserActivity` (thumbnail + title + "Reel"
/// label, no inline unlike/unsave affordance there either; that happens via
/// the reel player's own like/bookmark icons). Tapping opens the reel player
/// scrolled to that reel.
class _ReelsList extends StatelessWidget {
  const _ReelsList({required this.reels, required this.emptyText});

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

/// Renders liked/saved projects as compact thumbnail rows — mirrors the
/// portal's `ProjectItem` inside `IndividualUserActivity` (thumbnail + name +
/// location + price range, no inline unlike/unsave affordance there either).
/// Tapping opens the project's existing detail screen.
class _ProjectsList extends StatelessWidget {
  const _ProjectsList({required this.projects, required this.emptyText});

  final List<ProjectModel> projects;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (projects.isEmpty) {
      return Center(child: Text(emptyText, style: AppTextStyles.caption));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        final thumbnailUrl = project.logoUrl.isNotEmpty
            ? project.logoUrl
            : project.masterLayoutUrl;

        return GestureDetector(
          onTap: () => Navigator.pushNamed(
            context,
            AppConstants.projectDetailScreen,
            arguments: {'projectId': project.id},
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: thumbnailUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: thumbnailUrl,
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
                            child: const Icon(Icons.apartment_outlined),
                          ),
                        )
                      : Container(
                          width: 56,
                          height: 56,
                          color: AppColors.textHint.withOpacity(0.1),
                          child: const Icon(Icons.apartment_outlined),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.title.isNotEmpty
                            ? project.title
                            : 'Untitled project',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (project.location.isNotEmpty)
                        Text(
                          project.location,
                          style: AppTextStyles.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (project.hasPriceRange) ...[
                        const SizedBox(height: 2),
                        Text(
                          projectPriceRangeLabel(project),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
    required this.compareProvider,
  });

  final List properties;
  final String emptyText;
  final void Function(String propertyId) onFavoriteToggle;
  final CompareProvider compareProvider;

  @override
  Widget build(BuildContext context) {
    if (properties.isEmpty) {
      return Center(child: Text(emptyText, style: AppTextStyles.caption));
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
          isInCompare: compareProvider.isSelected(property.id),
          onCompareToggle: () => handleCompareToggle(context, property),
        );
      },
    );
  }
}
