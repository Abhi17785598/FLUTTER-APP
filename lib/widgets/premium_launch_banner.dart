import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/widgets/scale_tap.dart';
import '../models/launch_offer_content.dart';

/// Premium banner promoting "PropCID Pro" for builders/brokers.
///
/// Placed between the [HeroBannerCarousel] and the category grid on the home
/// screen. Every color/gradient/text style is pulled from the app's existing
/// theme tokens — the "wow" comes from layering (glow orbs, a looping glass
/// sheen sweep, a shimmering price, a pulsing live badge) rather than from
/// introducing a new visual language.
class PremiumLaunchBanner extends StatefulWidget {
  const PremiumLaunchBanner({super.key});

  @override
  State<PremiumLaunchBanner> createState() => _PremiumLaunchBannerState();
}

class _PremiumLaunchBannerState extends State<PremiumLaunchBanner>
    with SingleTickerProviderStateMixin {
  // Single ticker drives every ambient animation (sheen sweep, pulsing badge
  // dot, glowing CTA, premium glyph ring) — keeps the card cheap to render.
  late final AnimationController _ambient;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _ambient.dispose();
    super.dispose();
  }

  void _openPaymentMethod(BuildContext context) {
    Navigator.pushNamed(
      context,
      AppConstants.paymentMethodScreen,
      arguments: {
        'amountLabel': LaunchOfferContent.amountLabel,
        'title': 'PropCID Pro',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            boxShadow: AppColors.primaryGlow,
          ),
          child: Stack(
            children: [
              // ── Ambient depth: soft glow orbs ─────────────────────────
              Positioned(
                top: -46,
                right: -34,
                child: _glowOrb(190, Colors.white.withOpacity(0.16)),
              ),
              Positioned(
                bottom: -60,
                left: -46,
                child: _glowOrb(180, Colors.black.withOpacity(0.18)),
              ),

              // ── Looping diagonal sheen sweep ──────────────────────────
              _buildSheen(),

              // ── Content ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _badge(),
                        const Spacer(),
                        _premiumGlyph(),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      LaunchOfferContent.title,
                      style: AppTextStyles.heading2.copyWith(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            color: Colors.white.withOpacity(0.75), size: 14),
                        const SizedBox(width: 5),
                        Text(
                          LaunchOfferContent.tagline,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _divider(),
                    const SizedBox(height: 14),
                    _buildBenefitsRow(),
                    const SizedBox(height: 16),
                    _buildPricePanel(context),
                    const SizedBox(height: 10),
                    _buildTrustRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }

  // ── Decorative helpers ─────────────────────────────────────────────────

  Widget _glowOrb(double size, Color color) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }

  Widget _buildSheen() {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double w = constraints.maxWidth;
              return AnimatedBuilder(
                animation: _ambient,
                builder: (context, _) {
                  final double t = const Interval(
                    0.0,
                    0.45,
                    curve: Curves.easeInOutCubic,
                  ).transform(_ambient.value);
                  final double dx = (-1.3 + 2.6 * t) * w;

                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: w * 0.45,
                        height: 420,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.16),
                              Colors.white.withOpacity(0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(0.28),
            Colors.white.withOpacity(0),
          ],
        ),
      ),
    );
  }

  Widget _badge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) {
              final double pulse =
                  (math.sin(_ambient.value * 2 * math.pi).abs());
              return Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.55 + 0.45 * pulse),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
          Text(
            LaunchOfferContent.badgeLabel,
            style: AppTextStyles.chip.copyWith(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _premiumGlyph() {
    return AnimatedBuilder(
      animation: _ambient,
      builder: (context, _) {
        final double pulse = 0.55 + 0.45 * math.sin(_ambient.value * 2 * math.pi);
        return Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.16),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(0.32 * pulse),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white.withOpacity(0.85 + 0.15 * pulse),
            size: 18,
          ),
        );
      },
    );
  }

  Widget _buildBenefitsRow() {
    final items = LaunchOfferContent.benefits;
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final b = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.22)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(b.icon, size: 13, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  b.label,
                  style: AppTextStyles.chip.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(delay: (110 * i).ms, duration: 380.ms)
              .slideX(begin: 0.15, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildPricePanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Launch Price',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Shimmer.fromColors(
                  baseColor: Colors.white,
                  highlightColor: const Color(0xFFFFE9B8),
                  period: const Duration(milliseconds: 2200),
                  child: Text(
                    LaunchOfferContent.priceLabel,
                    style: AppTextStyles.price.copyWith(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _upgradeButton(context),
        ],
      ),
    );
  }

  Widget _upgradeButton(BuildContext context) {
    return ScaleTap(
      onTap: () => _openPaymentMethod(context),
      child: AnimatedBuilder(
        animation: _ambient,
        builder: (context, child) {
          final double pulse = 0.5 + 0.5 * math.sin(_ambient.value * 2 * math.pi);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.32 + 0.22 * pulse),
                  blurRadius: 14 + 6 * pulse,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Upgrade Now',
              style: AppTextStyles.button.copyWith(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_rounded,
                color: AppColors.primary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustRow() {
    return Row(
      children: [
        Icon(Icons.lock_rounded, size: 12, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 5),
        Text(
          'Secure checkout • Cancel anytime',
          style: AppTextStyles.caption.copyWith(
            color: Colors.white.withOpacity(0.65),
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}