import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;

  /// Backdrop fill opacity. Defaults to the original 0.85 — every existing
  /// caller keeps its exact current look unless it opts into a different
  /// value.
  final double opacity;

  /// Backdrop blur strength. Defaults to the original 10.
  final double blurSigma;

  /// Border colour. Defaults to the original `AppColors.primary`-tinted
  /// rim when left null.
  final Color? borderColor;

  /// Adds a thin, fading white sheen across the top edge — a cheap "light
  /// catching the top of the glass" cue for a more premium/liquid-glass
  /// feel. Defaults to false (no visual change for existing callers).
  final bool highlight;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    this.width,
    this.height,
    this.onTap,
    this.opacity = 0.85,
    this.blurSigma = 10,
    this.borderColor,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: borderColor ?? AppColors.primary.withOpacity(0.15),
            width: 1,
          ),
          boxShadow: AppColors.cardShadow,
        ),
        foregroundDecoration: !highlight
            ? null
            : BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.0),
                  ],
                  stops: const [0.0, 0.24],
                ),
              ),
        // `BackdropFilter` is one of the most expensive things Flutter can
        // paint — it re-samples and blurs everything behind it, every
        // frame, for as long as it (or anything behind it) is moving. A
        // card that scrolls with the page pays that cost on every scroll
        // frame it's on screen. Callers on a scrolling list that don't
        // need the literal "blur what's behind me" effect (e.g. a card
        // that's already opaque enough for the blur to be invisible
        // anyway) pass `blurSigma: 0` to skip `BackdropFilter`/`ClipRRect`
        // entirely and keep just the translucent-surface look.
        child: blurSigma <= 0
            ? child
            : ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                  child: child,
                ),
              ),
      ),
    );
  }
}
