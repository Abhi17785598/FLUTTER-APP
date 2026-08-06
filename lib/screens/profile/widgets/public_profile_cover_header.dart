// screens/profile/widgets/public_profile_cover_header.dart
//
// The collapsing cover at the top of the Public Profile screen.
//
// GEOMETRY IS BORROWED, NOT INVENTED
// ----------------------------------
// 172 dp cover, 28 dp bottom corners, 88 dp avatar overhanging by 42 dp — every
// number comes from the existing `ProfileCoverHeader` so the public and private
// profiles read as the same family. That widget is NOT modified; this is a
// separate SliverAppBar-based header, because a `SliverAppBar` cannot be produced
// by a plain `StatelessWidget` box and the own-profile screen does not scroll its
// header away.
//
// The cover image falls back to `AppColors.heroGradient` — the same fallback
// `ProfileCoverHeader` uses. The portal's hardcoded Unsplash URL is deliberately
// not reproduced: it is a network dependency for a decorative surface.
import 'package:cached_network_image/cached_network_image.dart';
// `ValueListenable` is declared in foundation, not material.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glass_circle_icon_button.dart';

/// Cover height, excluding the status bar. `SliverAppBar` with `primary: true`
/// adds the top inset on top of this, so the painted cover matches
/// `ProfileCoverHeader`'s 172 + inset exactly.
const double kPublicCoverHeight = 172;

/// How far the 88 dp avatar hangs below the cover's bottom edge.
const double kPublicAvatarOverhang = 42;

/// Avatar diameter.
const double kPublicAvatarSize = 88;

/// Total height the header reserves: the cover plus the avatar's overhang.
///
/// The avatar has to live INSIDE this header, not in the sliver below it. A
/// pinned `SliverAppBar` paints above every later sliver, so an avatar in the
/// following sliver that offsets upward to straddle the cover is drawn *behind*
/// it — only the part below the header's bottom edge stays visible.
/// `Stack(clipBehavior: Clip.none)` does not help, because the clipping is the
/// viewport's paint order, not the Stack's.
///
/// Reserving the overhang here means the avatar straddles the gradient's bottom
/// edge while sitting wholly within the header's own bounds, so nothing is
/// clipped and nothing is painted over. The extra 42 dp is transparent, so the
/// page background shows through and the result is visually identical to the
/// intended design.
const double kPublicHeaderHeight = kPublicCoverHeight + kPublicAvatarOverhang;

/// Scroll distance over which the header collapses to a plain pinned bar.
///
/// Shared with the screen so the collapse fraction it publishes and the avatar's
/// scroll compensation here divide by the same number. If they disagree, the
/// avatar drifts relative to the content it belongs to.
const double kPublicHeaderCollapseRange = kPublicHeaderHeight - kToolbarHeight;

/// Fraction of the collapse at which the bar starts turning solid.
const double _kSolidStart = 0.55;

/// Fraction at which the pinned title is fully in.
const double _kTitleStart = 0.75;

class PublicProfileCoverHeader extends StatelessWidget {
  /// `profiles.background_image_url`. Null falls back to the brand gradient.
  final String? coverImageUrl;

  /// Shown beside the small avatar once the bar has collapsed.
  final String title;

  final String? avatarUrl;
  final String initials;

  /// 0 = fully expanded, 1 = fully collapsed. Driven by the screen's
  /// `ScrollController` through a `ValueNotifier`, so scrolling rebuilds only
  /// this header rather than the twelve sections below it.
  final ValueListenable<double> collapse;

  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onMore;

  /// The large overhanging avatar, supplied by the screen.
  ///
  /// Passed in rather than constructed here so this file needs no import of
  /// `public_profile_identity.dart`, which already imports this one for the
  /// geometry constants — that would be a cycle.
  final Widget? avatarOverlay;

  const PublicProfileCoverHeader({
    super.key,
    required this.coverImageUrl,
    required this.title,
    required this.avatarUrl,
    required this.initials,
    required this.collapse,
    required this.onBack,
    required this.onShare,
    required this.onMore,
    this.avatarOverlay,
  });

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      // Cover + the avatar's overhang — see [kPublicHeaderHeight].
      expandedHeight: kPublicHeaderHeight,
      pinned: true,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      // The bar paints its own background through the animated builder below, so
      // the surface tint Material 3 would add on scroll is suppressed.
      surfaceTintColor: Colors.transparent,
      flexibleSpace: ValueListenableBuilder<double>(
        valueListenable: collapse,
        builder: (context, t, _) {
          final topInset = MediaQuery.paddingOf(context).top;
          final solid = _solidProgress(t);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // The cover occupies only the top `kPublicCoverHeight`; the
              // remaining overhang strip is transparent so the page background
              // shows through behind the avatar.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: kPublicCoverHeight + topInset,
                child: _CoverBackground(
                  coverImageUrl: coverImageUrl,
                  collapse: t,
                ),
              ),
              // Dropped entirely once the bar is solid: by then it is invisible,
              // and `Clip.none` would otherwise let it paint past the collapsed
              // bar's bounds.
              if (avatarOverlay != null && solid < 1)
                Positioned(
                  left: 20,
                  // Straddles the cover's bottom edge — 46 dp above it, 42 dp
                  // below — then rides the scroll upward at 1:1, because the box
                  // this Stack fills shrinks from the bottom while its top stays
                  // pinned to the viewport. Without the `- t * range` term the
                  // avatar would hang motionless at 126 dp while the identity
                  // text slid up underneath it.
                  top: topInset +
                      kPublicCoverHeight -
                      (kPublicAvatarSize - kPublicAvatarOverhang) -
                      t * kPublicHeaderCollapseRange,
                  // Fades as the bar turns solid, so it is gone before the
                  // collapsed title's own small avatar arrives.
                  child: Opacity(opacity: 1 - solid, child: avatarOverlay),
                ),
            ],
          );
        },
      ),
      title: ValueListenableBuilder<double>(
        valueListenable: collapse,
        builder: (context, t, _) => _CollapsedTitle(
          title: title,
          avatarUrl: avatarUrl,
          initials: initials,
          collapse: t,
        ),
      ),
      titleSpacing: 0,
      leading: ValueListenableBuilder<double>(
        valueListenable: collapse,
        builder: (context, t, _) => GlassCircleIconButton(
          icon: Icons.arrow_back_ios_new_rounded,
          semanticLabel: 'Back',
          onTap: onBack,
          solidProgress: _solidProgress(t),
        ),
      ),
      leadingWidth: 52,
      actions: [
        ValueListenableBuilder<double>(
          valueListenable: collapse,
          builder: (context, t, _) => GlassCircleIconButton(
            icon: Icons.share_outlined,
            semanticLabel: 'Share this profile',
            onTap: onShare,
            solidProgress: _solidProgress(t),
          ),
        ),
        const SizedBox(width: 2),
        ValueListenableBuilder<double>(
          valueListenable: collapse,
          builder: (context, t, _) => GlassCircleIconButton(
            icon: Icons.more_vert_rounded,
            semanticLabel: 'More options',
            onTap: onMore,
            solidProgress: _solidProgress(t),
          ),
        ),
        const SizedBox(width: 6),
      ],
    );
  }

  /// Remaps the raw collapse fraction so nothing changes until the cover is
  /// mostly gone, then completes quickly. A linear fade would wash the glass
  /// buttons out while the photo is still fully visible behind them.
  static double _solidProgress(double t) {
    if (t <= _kSolidStart) return 0;
    return ((t - _kSolidStart) / (1 - _kSolidStart)).clamp(0.0, 1.0);
  }
}

/// Cover photo (or gradient), its legibility scrim, and the white fill that
/// replaces both once collapsed.
class _CoverBackground extends StatelessWidget {
  final String? coverImageUrl;
  final double collapse;

  const _CoverBackground({required this.coverImageUrl, required this.collapse});

  @override
  Widget build(BuildContext context) {
    final solid = PublicProfileCoverHeader._solidProgress(collapse);

    // The bottom corners straighten as the bar becomes a plain app bar.
    final radius = Radius.circular(28 * (1 - solid));

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: radius,
              bottomRight: radius,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _coverFill(context),
                // Bottom-up scrim: guarantees the glass buttons and the pinned
                // title stay legible over any photo, however light.
                Opacity(
                  opacity: 1 - solid,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x001A1A2E),
                          Color(0x001A1A2E),
                          Color(0x8C1A1A2E),
                        ],
                        stops: [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                // Fades in as the bar pins, so the collapsed state is an opaque
                // surface rather than a cropped photo.
                Opacity(
                  opacity: solid,
                  child: const ColoredBox(color: AppColors.cardBackground),
                ),
              ],
            ),
          ),
          // Hairline under the collapsed bar, matching how every other surface in
          // the app separates itself.
          if (solid > 0)
            Align(
              alignment: Alignment.bottomCenter,
              child: Opacity(
                opacity: solid,
                child: Container(height: 1, color: AppColors.hairline),
              ),
            ),
        ],
      ),
    );
  }

  Widget _coverFill(BuildContext context) {
    final url = coverImageUrl;
    if (url == null || url.isEmpty) return const _GradientCover();

    final width = MediaQuery.sizeOf(context).width;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      // A full-resolution cover decoded into a 172 dp box is the largest
      // avoidable allocation on this screen.
      memCacheWidth: (width * dpr).round(),
      placeholder: (_, _) => const _GradientCover(),
      errorWidget: (_, _, _) => const _GradientCover(),
    );
  }
}

class _GradientCover extends StatelessWidget {
  const _GradientCover();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient),
      );
}

/// Small avatar + name, faded in only once the cover has essentially gone.
class _CollapsedTitle extends StatelessWidget {
  final String title;
  final String? avatarUrl;
  final String initials;
  final double collapse;

  const _CollapsedTitle({
    required this.title,
    required this.avatarUrl,
    required this.initials,
    required this.collapse,
  });

  @override
  Widget build(BuildContext context) {
    if (collapse <= _kTitleStart) return const SizedBox.shrink();

    final t = ((collapse - _kTitleStart) / (1 - _kTitleStart)).clamp(0.0, 1.0);

    return Opacity(
      opacity: t,
      child: Transform.translate(
        // Slides up 8 dp as it fades, so it arrives rather than blinking on.
        offset: Offset(0, 8 * (1 - t)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SmallAvatar(avatarUrl: avatarUrl, initials: initials),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.heading3.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String initials;

  const _SmallAvatar({required this.avatarUrl, required this.initials});

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        initials,
        style: AppTextStyles.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );

    return Container(
      width: _size,
      height: _size,
      decoration: const BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: avatarUrl == null || avatarUrl!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                width: _size,
                height: _size,
                errorWidget: (_, _, _) => fallback,
              ),
      ),
    );
  }
}
