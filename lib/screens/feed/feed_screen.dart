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
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/profile_link.dart';
import '../../models/feed_item.dart';
import '../../models/reel_comment.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feed_provider.dart';
import '../../providers/property_provider.dart';
import '../../services/comment_service.dart';
import '../reels/widgets/reel_action_button.dart';
import 'feed_video_player_screen.dart';

/// `post_comments.post_type` for a Feed property card's comment thread —
/// mirrors the portal's `CombinedFeed.tsx` `CommentsPanel postType="property"`.
const String _kPropertyCommentPostType = 'property';

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
                  // Like / Save / Comment / Share — property cards only, matching
                  // the portal's CombinedFeed.tsx PropertyCard action row exactly
                  // (same order, same icons, view count pinned to the right).
                  // Project/video cards keep the plain likes+views row below.
                  if (item.type == FeedItemType.property)
                    _PropertyFeedActions(item: item)
                  else
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

// ─────────────────────────────────────────────────────────────────────────────
// Property card action row — Like / Save / Comment / Share, matching the
// portal's CombinedFeed.tsx PropertyCard exactly (same order, same targets):
//   Like    -> user_likes, via the existing PropertyProvider.toggleLike/isLiked
//   Save    -> saved_properties, via PropertyProvider.toggleShortlist/isShortlisted
//   Comment -> post_comments (post_type='property'), via the existing CommentService
//   Share   -> the app's own property share link (profile_link.dart)
// Every backend call here already existed and is already used elsewhere in the
// app (Home rails use the same toggleLike/toggleShortlist; Reels uses the same
// CommentService); this only wires the same existing calls into the Feed card.
// ─────────────────────────────────────────────────────────────────────────────
class _PropertyFeedActions extends StatelessWidget {
  const _PropertyFeedActions({required this.item});

  final FeedItem item;

  void _signInRequired(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sign in required')),
    );
  }

  Future<void> _like(BuildContext context, PropertyProvider properties) async {
    if (context.read<AuthProvider>().userId == null) {
      _signInRequired(context);
      return;
    }
    await properties.toggleLike(item.id);
  }

  Future<void> _save(BuildContext context, PropertyProvider properties) async {
    if (context.read<AuthProvider>().userId == null) {
      _signInRequired(context);
      return;
    }
    await properties.toggleShortlist(item.id);
  }

  Future<void> _share(BuildContext context) async {
    try {
      await Share.share(
        propertyShareUrl(item.id, title: item.title),
        subject: item.title,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open share sheet')),
        );
      }
    }
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FeedCommentsSheet(item: item),
    );
  }

  static String _count(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final properties = context.watch<PropertyProvider>();
    final liked = properties.isLiked(item.id);
    final saved = properties.isShortlisted(item.id);

    return Row(
      children: [
        ReelActionButton(
          axis: Axis.horizontal,
          showIconBackground: false,
          baseColor: AppColors.textHint,
          activeColor: AppColors.error,
          icon: Icons.favorite_border_rounded,
          activeIcon: Icons.favorite_rounded,
          isActive: liked,
          iconSize: 16,
          iconBoxSize: 16,
          label: _count(item.likes),
          onTap: () => _like(context, properties),
        ),
        const SizedBox(width: AppConstants.spacingM),
        ReelActionButton(
          axis: Axis.horizontal,
          showIconBackground: false,
          baseColor: AppColors.textHint,
          activeColor: AppColors.primary,
          icon: Icons.bookmark_border_rounded,
          activeIcon: Icons.bookmark_rounded,
          isActive: saved,
          iconSize: 16,
          iconBoxSize: 16,
          label: 'Save',
          onTap: () => _save(context, properties),
        ),
        const SizedBox(width: AppConstants.spacingM),
        ReelActionButton(
          axis: Axis.horizontal,
          showIconBackground: false,
          baseColor: AppColors.textHint,
          icon: Icons.mode_comment_outlined,
          iconSize: 16,
          iconBoxSize: 16,
          label: 'Comment',
          onTap: () => _openComments(context),
        ),
        const SizedBox(width: AppConstants.spacingM),
        ReelActionButton(
          axis: Axis.horizontal,
          showIconBackground: false,
          baseColor: AppColors.textHint,
          icon: Icons.share_outlined,
          iconSize: 16,
          iconBoxSize: 16,
          label: 'Share',
          onTap: () => _share(context),
        ),
        const Spacer(),
        const Icon(Icons.visibility_outlined, size: 15, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text('${item.views}', style: AppTextStyles.caption),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments sheet for a Feed property card — same `post_comments` table and
// `CommentService` the Reels screen already uses, scoped to `post_type =
// 'property'` here instead of `'video'`.
// ─────────────────────────────────────────────────────────────────────────────
class _FeedCommentsSheet extends StatefulWidget {
  const _FeedCommentsSheet({required this.item});

  final FeedItem item;

  @override
  State<_FeedCommentsSheet> createState() => _FeedCommentsSheetState();
}

class _FeedCommentsSheetState extends State<_FeedCommentsSheet> {
  final CommentService _service = CommentService();
  final TextEditingController _input = TextEditingController();

  List<ReelComment>? _comments;
  bool _loadFailed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await _service.fetchComments(
        widget.item.id,
        _kPropertyCommentPostType,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('[Feed] fetchComments failed: $e');
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _submit() async {
    final content = _input.text.trim();
    if (content.isEmpty || _submitting) return;

    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to comment')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final comment = await _service.submitComment(
        postId: widget.item.id,
        postType: _kPropertyCommentPostType,
        userId: userId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments = [comment, ...?_comments];
        _input.clear();
      });
    } catch (e) {
      debugPrint('[Feed] submitComment failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't post comment")),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Rides above the keyboard so the input stays visible.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.6,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text('Comments', style: AppTextStyles.heading3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.hairline),
            Expanded(child: _buildBody()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load comments',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final comments = _comments;
    if (comments == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
      );
    }

    if (comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mode_comment_outlined,
                size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('No comments yet. Be the first!',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildCommentRow(comments[index]),
    );
  }

  Widget _buildCommentRow(ReelComment comment) {
    final name =
        (comment.authorName?.isNotEmpty ?? false) ? comment.authorName! : 'User';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: (comment.authorAvatarUrl?.isNotEmpty ?? false)
              ? CachedNetworkImageProvider(comment.authorAvatarUrl!)
              : null,
          child: (comment.authorAvatarUrl?.isNotEmpty ?? false)
              ? null
              : Text(name[0].toUpperCase(),
                  style: const TextStyle(color: AppColors.primary, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  )),
              const SizedBox(height: 2),
              Text(comment.content, style: AppTextStyles.body.copyWith(fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
              ),
            ),
            IconButton(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
