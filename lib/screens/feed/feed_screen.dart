// screens/feed/feed_screen.dart
//
// The "Feed" destination reached from the Workspace Drawer / More sheet —
// previously a stub that pushed Home (see WorkspaceDestinations.feed). Mirrors
// the portal's CombinedFeed.tsx: a single bounded fetch across properties,
// builder_projects and influencer_videos, with a client-side All/Brokers/
// Builders/Influencers filter row. Built entirely from this app's existing
// theme tokens (AppColors/AppTextStyles/AppConstants) — no new visual system.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/feed_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import 'feed_video_player_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeedProvider()
        ..load(context.read<AuthProvider>().userId),
      child: const _FeedView(),
    );
  }
}

class _FeedView extends StatelessWidget {
  const _FeedView();

  @override
  Widget build(BuildContext context) {
    final feed = context.watch<FeedProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Feed', style: AppTextStyles.heading2),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => context
            .read<FeedProvider>()
            .load(context.read<AuthProvider>().userId),
        child: Column(
          children: [
            _FilterRow(
              selected: feed.filter,
              onSelected: (f) => context.read<FeedProvider>().setFilter(f),
            ),
            Expanded(child: _FeedBody(feed: feed)),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final FeedRoleFilter selected;
  final ValueChanged<FeedRoleFilter> onSelected;

  const _FilterRow({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingL,
        vertical: AppConstants.spacingS,
      ),
      child: Row(
        children: [
          for (final role in FeedRoleFilter.values) ...[
            if (role != FeedRoleFilter.values.first)
              const SizedBox(width: AppConstants.spacingS),
            _FilterChip(
              role: role,
              isSelected: role == selected,
              onTap: () => onSelected(role),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final FeedRoleFilter role;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: role.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingM,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.pillRadius),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.hairline,
            ),
          ),
          child: Text(
            role.label,
            style: AppTextStyles.chip.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.cardBackground : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedBody extends StatelessWidget {
  final FeedProvider feed;

  const _FeedBody({required this.feed});

  @override
  Widget build(BuildContext context) {
    if (feed.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (feed.error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              feed.error!,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    final items = feed.visibleItems;
    if (items.isEmpty) {
      // Matches the portal's own copy for an empty feed.
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(
              'No content available',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingL,
        0,
        AppConstants.spacingL,
        AppConstants.spacingL,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) =>
          _FeedItemCard(item: items[index]),
    );
  }
}

class _FeedItemCard extends StatelessWidget {
  final FeedItem item;

  const _FeedItemCard({required this.item});

  void _open(BuildContext context) {
    switch (item.type) {
      case FeedItemType.property:
        Navigator.pushNamed(
          context,
          AppConstants.propertyDetailScreen,
          arguments: {'propertyId': item.id},
        );
        break;
      case FeedItemType.project:
        Navigator.pushNamed(
          context,
          AppConstants.projectDetailScreen,
          arguments: {'projectId': item.id},
        );
        break;
      case FeedItemType.video:
        if (item.videoUrl == null || item.videoUrl!.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FeedVideoPlayerScreen(
              videoUrl: item.videoUrl!,
              title: item.title,
            ),
          ),
        );
        break;
    }
  }

  /// Opens the poster's own public profile — distinct from [_open], which
  /// opens the content itself. Uses `item.posterUserId` (the same id the
  /// feed already resolved the poster's profile fields from), never the
  /// signed-in viewer's id.
  void _openProfile(BuildContext context) {
    final userId = item.posterUserId;
    if (userId == null || userId.isEmpty) return;
    Navigator.pushNamed(
      context,
      AppConstants.publicProfileScreen,
      arguments: {'userId': userId},
    );
  }

  String get _roleLabel {
    final type = item.posterUserType;
    if (type == null || type.isEmpty) return '';
    return type[0].toUpperCase() + type.substring(1);
  }

  String get _typeBadge => switch (item.type) {
        FeedItemType.property => 'Property',
        FeedItemType.project => 'Project',
        FeedItemType.video => 'Video',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppColors.surfaceCardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _openProfile(context),
                      borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage: (item.posterAvatarUrl?.isNotEmpty ?? false)
                                ? CachedNetworkImageProvider(item.posterAvatarUrl!)
                                : null,
                            child: (item.posterAvatarUrl?.isNotEmpty ?? false)
                                ? null
                                : const Icon(Icons.person, size: 18, color: AppColors.primary),
                          ),
                          const SizedBox(width: AppConstants.spacingS),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.posterName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.body.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                                if (_roleLabel.isNotEmpty)
                                  Text(
                                    _roleLabel,
                                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingS),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppConstants.chipRadius),
                    ),
                    child: Text(
                      _typeBadge,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          Container(color: AppColors.background),
                      errorWidget: (_, _, _) =>
                          Container(color: AppColors.background),
                    ),
                    if (item.type == FeedItemType.video)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.heading3.copyWith(fontSize: 14.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                  if (item.location.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: AppColors.textSecondary),
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
                  const SizedBox(height: AppConstants.spacingS),
                  Row(
                    children: [
                      const Icon(Icons.favorite_border,
                          size: 15, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text('${item.likes}', style: AppTextStyles.caption),
                      const SizedBox(width: AppConstants.spacingM),
                      const Icon(Icons.visibility_outlined,
                          size: 15, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text('${item.views}', style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
