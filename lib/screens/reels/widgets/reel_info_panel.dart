import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/reel_model.dart';

/// Compact glassmorphism row overlaid on the video itself, bottom-left —
/// builder avatar, name, verified badge, location, and follow action.
///
/// This used to also carry title/price/description, but that content now
/// lives in [ReelPropertyCard] below the video (see the reference design).
/// Kept as its own widget (rather than folded into [ReelPropertyCard]) so it
/// can keep living directly on top of the video surface.
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

  @override
  Widget build(BuildContext context) {
    if (!reel.hasBuilder) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.32),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
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
                        radius: 16,
                        backgroundColor: Colors.white24,
                        backgroundImage: (reel.builderAvatarUrl != null &&
                                reel.builderAvatarUrl!.isNotEmpty)
                            ? NetworkImage(reel.builderAvatarUrl!)
                            : null,
                        child: (reel.builderAvatarUrl == null ||
                                reel.builderAvatarUrl!.isEmpty)
                            ? const Icon(Icons.apartment_rounded,
                                color: Colors.white, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    reel.builderName!,
                                    style: AppTextStyles.body.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (reel.isVerified) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified_rounded,
                                      color: AppColors.verifiedBadge, size: 14),
                                ],
                              ],
                            ),
                            if (reel.hasLocation) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      color: Colors.white70, size: 12),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      reel.location!,
                                      style: AppTextStyles.caption.copyWith(
                                        color: Colors.white.withOpacity(0.85),
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
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
              const SizedBox(width: 10),
              _FollowButton(isFollowing: isFollowing, onTap: onFollow),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, curve: Curves.easeOutCubic);
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          gradient: isFollowing ? null : AppColors.primaryGradient,
          color: isFollowing ? Colors.white.withOpacity(0.15) : null,
          borderRadius: BorderRadius.circular(18),
          border: isFollowing
              ? Border.all(color: Colors.white.withOpacity(0.4))
              : null,
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: AppTextStyles.chip.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
