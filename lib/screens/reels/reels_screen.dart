import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/reel_model.dart';
import '../../providers/reels_provider.dart';
import '../../widgets/bottom_nav_bar.dart';
import 'widgets/reel_action_button.dart';
import 'widgets/reel_action_row.dart';
import 'widgets/reel_controller_manager.dart';
import 'widgets/reel_cta_buttons.dart';
import 'widgets/reel_info_panel.dart';
import 'widgets/reel_property_card.dart';
import 'widgets/reel_video_view.dart';

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
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  final PageController _pageController = PageController();
  final ReelControllerManager _manager = ReelControllerManager(windowRadius: 1);

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

  /// Called once reels are available: primes the controller window.
  void _maybeInitFeed(List<ReelModel> reels) {
    if (_initializedFeed || reels.isEmpty) return;
    _initializedFeed = true;
    _manager.setReels(reels);
    _manager.onActiveIndexChanged(0);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isPaused = false;
    });
    _manager.onActiveIndexChanged(index);
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
    if (reel.propertyId == null || reel.propertyId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property details are not available for this reel')),
      );
      return;
    }
    Navigator.pushNamed(
      context,
      AppConstants.propertyDetailScreen,
      arguments: {'propertyId': reel.propertyId},
    );
  }

  Future<void> _onContactBuilder(ReelModel reel) async {
    final phone = reel.builderPhone;
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No contact number available for this builder')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a call')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a call')),
        );
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
              return AnimatedBuilder(
                animation: _manager,
                builder: (context, _) {
                  return ReelVideoView(
                    key: ValueKey(provider.reels[index].id),
                    reel: provider.reels[index],
                    controller: _manager.controllerAt(index),
                    hasFailed: _manager.hasFailed(index),
                    isPaused: index == _currentIndex && _isPaused,
                    onTogglePlayPause: _togglePlayPause,
                  );
                },
              );
            },
          ),
          _buildTopBar(),
          _buildBuilderOverlay(provider),
          _buildVideoActionRail(provider),
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
            ReelActionButton(
              showIconBackground: false,
              showLabelShadow: true,
              iconSize: 28,
              iconBoxSize: 36,
              icon: Icons.mode_comment_outlined,
              label: 'Comment',
              onTap: _showComments,
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

  static String _formatActionCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Widget _buildTopBar() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _circleIcon(Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.maybePop(context)),
            const Spacer(),
            Text(
              'Reels',
              style: AppTextStyles.heading2.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                shadows: const [Shadow(color: Colors.black45, blurRadius: 6)],
              ),
            ),
            const Spacer(),
            _circleIcon(Icons.camera_alt_outlined, onTap: () {}),
          ],
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
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
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
        ),
      ),
    );
  }

  // ── Property card (sized to its own content, ~20% of screen on most devices) ──
  Widget _buildPropertyCard(ReelModel reel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 16, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
       child: Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReelPropertyCard(reel: reel, compact: true),
                  const Divider(height: 18),
                  // Wrapped in a horizontally-scrolling strip as a safety
                  // net: on very narrow screens the 4 action buttons could
                  // otherwise overflow the left column's width once it's
                  // sharing the row with the fixed-width CTA column.
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const ClampingScrollPhysics(),
                    child: ReelActionRow(
                      reel: reel,
                      onComment: _showComments,
                      onShare: () => _shareReel(reel),
                      bordered: false,
                      mainAxisAlignment: MainAxisAlignment.start,
                      spacing: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 128,
              child: ReelCtaButtons(
                axis: Axis.vertical,
                onViewDetails: () => _onViewDetails(reel),
                onContactBuilder: () => _onContactBuilder(reel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Comments (placeholder) ───────────────────────────────────────────────
  void _showComments() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _CommentsSheet(),
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
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white),
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
                      color: Colors.white.withOpacity(0.35),
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
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                      label: Text(
                        'Retry',
                        style: AppTextStyles.button.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.4)),
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
// Comments placeholder sheet
// ─────────────────────────────────────────────────────────────────────────────
class _CommentsSheet extends StatelessWidget {
  const _CommentsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
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
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('Comments',
                    style: AppTextStyles.heading3
                        .copyWith(color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.mode_comment_outlined,
                      size: 56, color: Colors.white.withOpacity(0.25)),
                  const SizedBox(height: 12),
                  Text(
                    'Comments coming soon',
                    style: AppTextStyles.body.copyWith(
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
