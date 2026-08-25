import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/reel_model.dart';

/// Builder avatar, name, verified badge, location, and follow action —
/// overlaid directly on the video itself, bottom-left, matching the
/// reference design's plain (no glass-panel) creator row: legibility comes
/// from text shadows and the bottom scrim [ReelsScreen] paints behind this
/// whole overlay, not from a per-row backdrop blur.
class ReelInfoPanel extends StatelessWidget {
  const ReelInfoPanel({
    super.key,
    required this.reel,
    required this.isFollowing,
    required this.onFollow,
    this.onTapProfile,
  });

  final ReelModel reel;
  final bool isFollowing;
  final VoidCallback onFollow;

  /// Opens the uploader's public profile. Null when the reel has no
  /// resolvable uploader id, in which case the avatar/name stay inert.
  final VoidCallback? onTapProfile;

  static const List<Shadow> _textShadow = [
    Shadow(color: Colors.black54, blurRadius: 6),
  ];

  @override
  Widget build(BuildContext context) {
    if (!reel.hasBuilder) return const SizedBox.shrink();

    return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: GestureDetector(
                onTap: onTapProfile,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: Colors.white24,
                      backgroundImage:
                          (reel.builderAvatarUrl != null &&
                              reel.builderAvatarUrl!.isNotEmpty)
                          ? NetworkImage(reel.builderAvatarUrl!)
                          : null,
                      child:
                          (reel.builderAvatarUrl == null ||
                              reel.builderAvatarUrl!.isEmpty)
                          ? const Icon(
                              Icons.apartment_rounded,
                              color: Colors.white,
                              size: 17,
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              reel.builderName!,
                              style: AppTextStyles.body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                shadows: _textShadow,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (reel.isVerified) ...[
                            const SizedBox(width: 5),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.verifiedBadge,
                              size: 16,
                              shadows: _textShadow,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _FollowButton(isFollowing: isFollowing, onTap: onFollow),
          ],
        )
        .animate()
        .fadeIn(duration: 300.ms)
        .slideX(begin: -0.1, curve: Curves.easeOutCubic);
  }
}

class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.isFollowing, required this.onTap});

  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isFollowing ? Colors.white.withOpacity(0.15) : AppColors.primary,
          borderRadius: BorderRadius.circular(20),
          border: isFollowing
              ? Border.all(color: Colors.white.withOpacity(0.4))
              : null,
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: AppTextStyles.chip.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
