import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/reels_provider.dart';
import '../../../widgets/section_header.dart';

/// Read-only preview row of the reels already being fetched app-wide by
/// `ReelsProvider` (it self-loads on construction, per `main.dart`) — no new
/// fetch logic here. Tapping any card, or "See all", opens the existing
/// `ReelsScreen` (same route the Home dropdown menu already uses).
///
/// Auto-scrolls itself slowly for a premium "alive" feel, pausing the moment
/// the user touches the list and resuming a short idle delay after they let
/// go — manual drag/scroll is the same `ListView` underneath, untouched.
class PropertyReelsSection extends StatefulWidget {
  const PropertyReelsSection({super.key});

  @override
  State<PropertyReelsSection> createState() => _PropertyReelsSectionState();
}

class _PropertyReelsSectionState extends State<PropertyReelsSection>
    with AutomaticKeepAliveClientMixin {
  static const _tick = Duration(milliseconds: 40);
  static const _pxPerTick = 0.6;
  static const _idleResumeDelay = Duration(seconds: 3);

  final ScrollController _scrollController = ScrollController();
  Timer? _autoScrollTimer;
  Timer? _idleTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAutoScroll());
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _idleTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(_tick, (timer) {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;
      final next = _scrollController.offset + _pxPerTick;
      if (next >= max) {
        _scrollController.jumpTo(0);
      } else {
        _scrollController.jumpTo(next);
      }
    });
  }

  void _pauseForUserInteraction() {
    _autoScrollTimer?.cancel();
    _idleTimer?.cancel();
  }

  void _scheduleResume() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleResumeDelay, () {
      if (mounted) _startAutoScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Consumer<ReelsProvider>(
      builder: (context, reelsProvider, _) {
        final reels = reelsProvider.reels;
        if (reels.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Property Reels',
              actionLabel: 'See all ›',
              onActionTap: () =>
                  Navigator.pushNamed(context, AppConstants.reelsScreen),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: Listener(
                onPointerDown: (_) => _pauseForUserInteraction(),
                onPointerUp: (_) => _scheduleResume(),
                onPointerCancel: (_) => _scheduleResume(),
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: reels.length,
                  itemBuilder: (context, index) {
                    final reel = reels[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppConstants.reelsScreen,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: 130,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: reel.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) =>
                                      Container(color: AppColors.primaryLight),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: AppColors.primaryLight,
                                        child: const Icon(
                                          Icons.movie_outlined,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.75),
                                      ],
                                      stops: const [0.5, 1],
                                    ),
                                  ),
                                ),
                                const Center(child: _PlayButton()),
                                Positioned(
                                  left: 10,
                                  right: 10,
                                  bottom: 10,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        reel.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.body.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                      if (reel.hasLocation) ...[
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.location_on,
                                              size: 10,
                                              color: Colors.white70,
                                            ),
                                            const SizedBox(width: 2),
                                            Expanded(
                                              child: Text(
                                                reel.location!,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.22),
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.2),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}
