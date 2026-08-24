import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/reel_comment.dart';
import '../../models/reel_model.dart';
import '../../providers/reels_provider.dart';
import '../../services/comment_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'widgets/reel_action_button.dart';
import 'widgets/reel_controller_manager.dart';
import 'widgets/reel_info_panel.dart';
import 'widgets/reel_property_card.dart';
import 'package:video_player/video_player.dart'
    show VideoPlayerController, VideoViewType;

import 'widgets/reel_video_view.dart';

/// `post_comments.post_type` for every reel — mirrors the website's
/// ReelView.tsx (`postType={reel.type === 'influencer_video' ? 'video' :
/// 'property'}`); every Flutter reel comes from `influencer_videos`, so this
/// is always `'video'`, never the `'property'` branch that only applies to
/// the website's separate property-video feed items.
const String _kReelCommentPostType = 'video';

/// Premium vertical reels feed — matches the compact reference layout:
/// video occupies ~80% of the screen, with a slim floating white card
/// (title, price, status, actions, CTAs) beneath it.
///
/// Everything under the hood is untouched from the previous implementation:
///   • A single [ReelControllerManager] still owns the sliding window of
///     video controllers (previous / current / next) for instant swipes and
///     bounded memory.
///   • The video layer still never rebuilds on interaction — like/save/
///     follow still live in [ReelsProvider] and only small overlay/card
///     widgets rebuild via [Consumer].
///   • Pagination, autoplay, and swipe gestures are unchanged — only the
///     presentation around the video changed.
class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key, this.initialReelId});

  /// When set, the feed opens scrolled to this reel instead of the top —
  /// used when opening a reel from My Activity's saved-reels list, mirroring
  /// the portal's `handleReelClick` (which navigates into the same reel
  /// player pre-selecting that reel; there is no standalone reel-detail
  /// route on the portal either).
  final String? initialReelId;

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();

  /// Rendered through a native `SurfaceView` rather than a Flutter texture.
  ///
  /// The texture path samples the decoder's output buffer into a Flutter
  /// texture, and a driver that reports a non-standard stride or colour format
  /// makes that sampling produce green diagonal tearing — which is why the
  /// artifact follows the device, not the file. `platformView` hands frames
  /// straight to SurfaceFlinger, so there is no stride for Flutter to get wrong.
  ///
  /// Only the full-screen player. A `SurfaceView` is its own window layer and
  /// does not clip or transform with Flutter, which is fine for a full-bleed
  /// video and wrong for the Home rail's rounded, cover-cropped cards — those
  /// stay on the texture path.
  final ReelControllerManager _manager = ReelControllerManager(
    windowRadius: 1,
    viewType: VideoViewType.textureView,
  );

  int _currentIndex = 0;
  bool _isPaused = false;
  bool _initializedFeed = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Note: we deliberately do NOT trigger provider.loadReels() here.
    // ReelsProvider is an app-global singleton (see main.dart) that already
    // starts loading in its own constructor. Triggering a second, overlapping
    // fetch here raced with that one — the two loadReels() calls interleaved
    // their isLoading/notifyListeners() cycles unpredictably, which was one
    // of the causes of inconsistent first-open behaviour. If reels ever fail
    // to load, the empty-state screen already exposes an explicit Retry
    // button wired to provider.loadReels().
  }

  @override
  void dispose() {
    _pageController.dispose();
    _manager.disposeAll();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  /// Called once reels are available: primes the controller window, and —
  /// when [ReelsScreen.initialReelId] is set — starts on that reel instead
  /// of the top of the feed.
  void _maybeInitFeed(List<ReelModel> reels) {
    if (_initializedFeed || reels.isEmpty) return;
    _initializedFeed = true;

    final requestedId = widget.initialReelId;
    final matchedIndex = requestedId == null
        ? -1
        : reels.indexWhere((r) => r.id == requestedId);
    final startIndex = matchedIndex == -1 ? 0 : matchedIndex;

    _currentIndex = startIndex;
    _manager.setReels(reels);
    _manager.onActiveIndexChanged(startIndex);

    if (startIndex != 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients) {
          _pageController.jumpToPage(startIndex);
        }
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isPaused = false;
    });
    // Deferred a frame: onActiveIndexChanged disposes/initializes native
    // video surfaces (real platform-channel round trips), and starting that
    // work in the same call stack as the page-change notification meant it
    // began competing with the PageView's own settle animation for the UI
    // thread at the exact moment of the swipe. Starting it only once that
    // frame has been drawn keeps the fling/settle smooth.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index != _currentIndex) return;

      // Ignore callbacks queued for a Reel that is no longer active.
      // ignore: unawaited_futures
      _manager.onActiveIndexChanged(index);
    });
  }

  void _togglePlayPause() {
    setState(() => _isPaused = !_isPaused);
    _isPaused ? _manager.pauseActive() : _manager.playActive();
  }

  Future<void> _shareReel(ReelModel reel) async {
    try {
      await Share.share(reel.shareMessage, subject: reel.title);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open share sheet')),
        );
      }
    }
  }

  void _onViewDetails(ReelModel reel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PropertyDetailsSheet(
        reel: reel,
        onContactBuilder: () => _onContactBuilder(reel),
      ),
    );
  }

  Future<void> _onContactBuilder(ReelModel reel) async {
    final phone = reel.builderPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No contact number available for this builder'),
        ),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not start a call')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not start a call')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Must stay black, not white: the video (or its own black placeholder)
      // always paints over this, but during video_player's native decoder
      // startup (MediaCodec/AudioTrack init) nothing has painted yet, so
      // this base color is what's actually on screen. White here was the
      // regression that turned that brief, previously-invisible gap into a
      // visible blank white screen.
      backgroundColor: Colors.black,
      bottomNavigationBar: const BottomNavBar(currentIndex: 2),
      body: Consumer<ReelsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.reels.isEmpty) {
            return const _ReelsLoadingState();
          }
          if (provider.reels.isEmpty) {
            return _ReelsEmptyState(
              hasError: provider.hasError,
              onRetry: provider.loadReels,
            );
          }

          _maybeInitFeed(provider.reels);
          final activeReel = provider.reels[_currentIndex];

          return SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                // The video fills whatever space the card doesn't need —
                // this lands at ~80% on typical screens (matching the
                // reference), but crucially it's the video that flexes,
                // not the card. A hard 80/20 flex split forced the card
                // into a fixed height that didn't fit its own content on
                // shorter screens, which is what caused the overflow.
                Expanded(child: _buildVideoArea(provider)),
                _buildPropertyCard(activeReel),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Video area (top ~80%) ────────────────────────────────────────────────
  Widget _buildVideoArea(ReelsProvider provider) {
    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // PageView is stable — it does not rebuild when any controller
          // notifies. Each item wraps its own AnimatedBuilder so only that
          // item's ReelVideoView rebuilds when the manager fires (e.g. a
          // controller becomes initialized or fails). Previously the outer
          // AnimatedBuilder rebuilt the entire PageView on every notification,
          // triggering the scroll engine, gesture recognizer, and all visible
          // itemBuilder calls unnecessarily.
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: provider.reels.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              // RepaintBoundary isolates each reel's own compositing layer
              // (the video surface, especially the platform-view/SurfaceView
              // path above) from the page-transition transform and from
              // sibling rebuilds — without it every page's paint is at the
              // mercy of the same layer as its neighbours during a swipe,
              // which is a well-known source of jank for platform views
              // inside a scrollable.
              return RepaintBoundary(
                child: _ReelPageSurface(
                  key: ValueKey(provider.reels[index].id),
                  manager: _manager,
                  index: index,
                  reel: provider.reels[index],
                  isActive: index == _currentIndex,
                  isPaused: index == _currentIndex && _isPaused,
                  onTogglePlayPause: _togglePlayPause,
                ),
              );
            },
          ),
          _buildTopBar(),
          _buildBuilderOverlay(provider),
          _buildVideoActionRail(provider),
          _buildMuteButton(),
        ],
      ),
    );
  }

  // Vertical like/comment/share/save rail on the video itself — reuses the
  // same ReelActionButton + ReelsProvider wiring as ReelActionRow on the
  // card below; only the axis/styling differs (plain white, no backdrop,
  // stacked vertically) to match the reference image.
  Widget _buildVideoActionRail(ReelsProvider provider) {
    final reel = provider.reels[_currentIndex];
    final liked = provider.isLiked(reel.id);
    final saved = provider.isSaved(reel.id);

    return Positioned(
      right: 16,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReelActionButton(
              showIconBackground: false,
              showLabelShadow: true,
              iconSize: 28,
              iconBoxSize: 36,
              icon: Icons.favorite_border_rounded,
              activeIcon: Icons.favorite_rounded,
              label: _formatActionCount(provider.likeCount(reel)),
              isActive: liked,
              activeColor: AppColors.error,
              onTap: () => provider.toggleLike(reel.id),
            ),
            const SizedBox(height: 18),
            // Views — reel.views is a real column (influencer_videos.views),
            // already parsed by ReelModel but never displayed anywhere;
            // mirrors the website's Eye icon + count in the same rail
            // position (ReelView.tsx, between Like and Comment).
            ReelActionButton(
              showIconBackground: false,
              showLabelShadow: true,
              iconSize: 28,
              iconBoxSize: 36,
              icon: Icons.visibility_outlined,
              label: _formatActionCount(reel.views),
              onTap: () {},
            ),
            const SizedBox(height: 18),
            ReelActionButton(
              showIconBackground: false,
              showLabelShadow: true,
              iconSize: 28,
              iconBoxSize: 36,
              icon: Icons.mode_comment_outlined,
              label: 'Comment',
              onTap: () => _showComments(reel),
            ),
            const SizedBox(height: 18),
            ReelActionButton(
              showIconBackground: false,
              showLabelShadow: true,
              iconSize: 28,
              iconBoxSize: 36,
              icon: Icons.send_outlined,
              label: 'Share',
              onTap: () => _shareReel(reel),
            ),
            const SizedBox(height: 18),
            ReelActionButton(
              showIconBackground: false,
              showLabelShadow: true,
              iconSize: 28,
              iconBoxSize: 36,
              icon: Icons.bookmark_border_rounded,
              activeIcon: Icons.bookmark_rounded,
              label: 'Save',
              isActive: saved,
              onTap: () => provider.toggleSave(reel.id),
            ),
          ],
        ),
      ),
    );
  }

  /// Top-right sound toggle — mirrors the website's mute/unmute button
  /// (ReelView.tsx, `top-4 right-4`, Volume2/VolumeX). Scoped to its own
  /// AnimatedBuilder so toggling sound repaints only this small icon, not
  /// the rest of the video overlay.
  Widget _buildMuteButton() {
    return Positioned(
      top: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 0),
          child: AnimatedBuilder(
            animation: _manager,
            builder: (context, _) {
              return _circleIcon(
                _manager.isMuted
                    ? Icons.volume_off_rounded
                    : Icons.volume_up_rounded,
                onTap: _manager.toggleMute,
              );
            },
          ),
        ),
      ),
    );
  }

  static String _formatActionCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _circleIcon(
              Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.maybePop(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleIcon(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  /// Opens the reel uploader's own public profile — `reel.builderUserId`
  /// (`influencer_videos.user_id`), never the signed-in viewer's id.
  ///
  /// This pushes a new route on top of Reels rather than replacing it, so
  /// `ReelsScreen`'s State (and its `_manager`) stays alive underneath —
  /// `dispose()` never runs, and without an explicit pause the active
  /// video's audio kept playing behind the profile screen. `pauseAll()` /
  /// `resumeWindow()` already existed on [ReelControllerManager] for exactly
  /// this "leaving the viewport" case; this was the one navigation path that
  /// never called them.
  Future<void> _openUploaderProfile(String userId) async {
    _manager.pauseAll();
    await Navigator.pushNamed(
      context,
      AppConstants.publicProfileScreen,
      arguments: {'userId': userId},
    );
    if (mounted) _manager.resumeWindow();
  }

  Widget _buildBuilderOverlay(ReelsProvider provider) {
    final reel = provider.reels[_currentIndex];
    return Positioned(
      left: 16,
      right: 72,
      bottom: 16,
      child: SafeArea(
        top: false,
        child: ReelInfoPanel(
          reel: reel,
          isFollowing: provider.isFollowed(reel.id),
          onFollow: () => provider.toggleFollow(reel.id),
          onTapProfile: reel.builderUserId == null
              ? null
              : () => _openUploaderProfile(reel.builderUserId!),
        ),
      ),
    );
  }

  // ── Property card ────────────────────────────────────────────────────────
  Widget _buildPropertyCard(ReelModel reel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                reel.title.isNotEmpty ? reel.title : 'Featured Property',
                style: AppTextStyles.heading2.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            _buildViewDetailsButton(reel),
            const SizedBox(width: 8),
            _buildContactButton(reel),
          ],
        ),
      ),
    );
  }

  Widget _buildViewDetailsButton(ReelModel reel) {
    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: () => _onViewDetails(reel),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View Details',
              style: AppTextStyles.chip.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactButton(ReelModel reel) {
    return SizedBox(
      height: 38,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            onTap: () => _onContactBuilder(reel),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.call_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Contact',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Comments ──────────────────────────────────────────────────────────────
  void _showComments(ReelModel reel) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CommentsSheet(reel: reel),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// One PageView slot's video surface — rebuilds only for its own state
// ─────────────────────────────────────────────────────────────────────────────

/// Renders one page's [ReelVideoView], listening to [manager] but rebuilding
/// only when THIS index's own (controller, ready, failed) state actually
/// changes — not on every notification the manager fires.
///
/// [ReelControllerManager] is one [ChangeNotifier] shared by the whole
/// sliding window: muting, a neighbour finishing its preload-init, or a
/// far-out-of-window controller being disposed all call `notifyListeners()`.
/// The previous code wrapped every built page in an `AnimatedBuilder` keyed
/// to that same notifier, so any one of those unrelated events rebuilt every
/// visible/preloading page at once — right as the swipe's settle animation
/// was running. Comparing before calling `setState` bounds each page's
/// rebuilds to changes that are actually its own.
class _ReelPageSurface extends StatefulWidget {
  const _ReelPageSurface({
    super.key,
    required this.manager,
    required this.index,
    required this.reel,
    required this.isActive,
    required this.isPaused,
    required this.onTogglePlayPause,
  });

  final ReelControllerManager manager;
  final int index;
  final ReelModel reel;
  final bool isActive;
  final bool isPaused;
  final VoidCallback onTogglePlayPause;

  @override
  State<_ReelPageSurface> createState() => _ReelPageSurfaceState();
}

class _ReelPageSurfaceState extends State<_ReelPageSurface> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _hasFailed = false;

  @override
  void initState() {
    super.initState();
    _sync();
    widget.manager.addListener(_onManagerChanged);
  }

  @override
  void didUpdateWidget(_ReelPageSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.manager != widget.manager) {
      oldWidget.manager.removeListener(_onManagerChanged);
      widget.manager.addListener(_onManagerChanged);
    }
    if (oldWidget.manager != widget.manager ||
        oldWidget.index != widget.index) {
      _sync();
    }
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onManagerChanged);
    super.dispose();
  }

  void _sync() {
    _controller = widget.manager.controllerAt(widget.index);
    _ready = _controller?.value.isInitialized ?? false;
    _hasFailed = widget.manager.hasFailed(widget.index);
  }

  void _onManagerChanged() {
    final controller = widget.manager.controllerAt(widget.index);
    final ready = controller?.value.isInitialized ?? false;
    final hasFailed = widget.manager.hasFailed(widget.index);
    if (controller == _controller &&
        ready == _ready &&
        hasFailed == _hasFailed) {
      return;
    }
    setState(() {
      _controller = controller;
      _ready = ready;
      _hasFailed = hasFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ReelVideoView(
      reel: widget.reel,

      // Keep neighbouring controllers initialized, but don't attach additional
      // native SurfaceViews while PageView is scrolling.
      controller: widget.isActive ? _controller : null,
      hasFailed: widget.isActive && _hasFailed,
      showLoadingIndicator: widget.isActive,
      isPaused: widget.isPaused,
      onTogglePlayPause: widget.onTogglePlayPause,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Property details sheet — slides up while the reel keeps playing
// ─────────────────────────────────────────────────────────────────────────────
class _PropertyDetailsSheet extends StatelessWidget {
  const _PropertyDetailsSheet({
    required this.reel,
    required this.onContactBuilder,
  });

  final ReelModel reel;
  final VoidCallback onContactBuilder;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      snap: true,
      snapSizes: const [0.65, 0.92],
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── handle + close ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.textHint,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.cardBackground,
                      padding: const EdgeInsets.all(6),
                      minimumSize: const Size(36, 36),
                    ),
                  ),
                ],
              ),
            ),
            // ── scrollable body ─────────────────────────────────────────
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  ReelPropertyCard(reel: reel, compact: false),
                  if (reel.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text(
                      'Description',
                      style: AppTextStyles.heading3.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      reel.description.trim(),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary.withValues(alpha: 0.75),
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // ── contact CTA ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(
                          AppConstants.buttonRadius,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppConstants.buttonRadius,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            onContactBuilder();
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.call_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Contact Builder',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
// Loading state
// ─────────────────────────────────────────────────────────────────────────────
class _ReelsLoadingState extends StatelessWidget {
  const _ReelsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / error state
// ─────────────────────────────────────────────────────────────────────────────
class _ReelsEmptyState extends StatelessWidget {
  const _ReelsEmptyState({required this.hasError, required this.onRetry});

  final bool hasError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      hasError
                          ? Icons.wifi_off_rounded
                          : Icons.video_library_outlined,
                      size: 72,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      hasError
                          ? 'Something went wrong'
                          : 'No reels available yet',
                      style: AppTextStyles.heading3.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hasError
                          ? 'Check your connection and try again.'
                          : 'Property reels will appear here soon.',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Retry',
                        style: AppTextStyles.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Comments sheet — real data via `post_comments` (post_type = 'video'),
// mirroring the website's CommentsPanel usage in ReelView.tsx.
// ─────────────────────────────────────────────────────────────────────────────
class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.reel});

  final ReelModel reel;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
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
        widget.reel.id,
        _kReelCommentPostType,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('[Reels] fetchComments failed: $e');
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _submit() async {
    final content = _input.text.trim();
    if (content.isEmpty || _submitting) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to comment')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final comment = await _service.submitComment(
        postId: widget.reel.id,
        postType: _kReelCommentPostType,
        userId: userId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments = [comment, ...?_comments];
        _input.clear();
      });
    } catch (e) {
      debugPrint('[Reels] submitComment failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Couldn't post comment")));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool commentsEnabled = widget.reel.commentsEnabled;

    return Padding(
      // Rides above the keyboard so the input stays visible.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.textPrimary,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Text(
                    'Comments',
                    style: AppTextStyles.heading3.copyWith(color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(child: _buildBody()),
            if (commentsEnabled) _buildInputBar() else _buildDisabledNotice(),
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
            Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'Could not load comments',
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final comments = _comments;
    if (comments == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 2),
      );
    }

    if (comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mode_comment_outlined,
              size: 56,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 12),
            Text(
              'No comments yet',
              style: AppTextStyles.body.copyWith(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
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
    final name = (comment.authorName?.isNotEmpty ?? false)
        ? comment.authorName!
        : 'User';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.white24,
          backgroundImage: (comment.authorAvatarUrl?.isNotEmpty ?? false)
              ? NetworkImage(comment.authorAvatarUrl!)
              : null,
          child: (comment.authorAvatarUrl?.isNotEmpty ?? false)
              ? null
              : Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                comment.content,
                style: AppTextStyles.body.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                ),
              ),
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
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                        color: Colors.white70,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledNotice() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Comments are turned off for this creator',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
