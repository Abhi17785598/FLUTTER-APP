import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The app-wide ambient background every screen's glass surfaces float over.
///
/// Painted once, behind every route (see `PropertyApp.builder` in
/// `app.dart`), rather than duplicated per screen. Soft, static, blurred
/// colour blobs — the actual visual depth that makes translucent cards read
/// as "glass" rather than just sitting on a flat tint.
///
/// Deliberately still not a `BackdropFilter`: that filter samples and
/// re-blurs whatever is currently rendered *behind* it, every single frame
/// anything behind it moves — which is exactly what caused real scroll jank
/// when tried on the Home header earlier, and would be far worse repeated
/// behind every scrolling screen in the app. Each [_Orb] below instead blurs
/// only its own simple, unmoving shape via [ImageFiltered] — a fixed cost
/// paid once at first paint, independent of whatever scrolls on top of it in
/// later, separately-composited layers.
///
/// Individual screens opt into showing this by setting their own
/// `Scaffold.backgroundColor` to `Colors.transparent` instead of
/// `AppColors.background` — this widget does not touch any screen's content,
/// cards, or layout, only what shows through the gaps between them.
class AppGlassBackdrop extends StatelessWidget {
  const AppGlassBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.background),
          Positioned(
            top: -size.width * 0.28,
            left: -size.width * 0.22,
            child: const _Orb(
              diameter: 260,
              color: Color(0x80F97316), // primary, half alpha
            ),
          ),
          Positioned(
            top: size.height * 0.18,
            right: -size.width * 0.3,
            child: const _Orb(
              diameter: 300,
              color: Color(0x66FDBA74), // warm gold, soft
            ),
          ),
          Positioned(
            bottom: -size.height * 0.12,
            left: -size.width * 0.28,
            child: const _Orb(
              diameter: 280,
              color: Color(0x73FFB37A),
            ),
          ),
          Positioned(
            bottom: size.height * 0.05,
            right: -size.width * 0.18,
            child: const _Orb(
              diameter: 220,
              color: Color(0x59F97316),
            ),
          ),
          // A light overall wash on top of the blobs so cards/text never sit
          // directly against a saturated colour — keeps every screen's
          // existing content exactly as readable as it was on the flat
          // background.
          const ColoredBox(color: Color(0xCCF4F4F8)),
        ],
      ),
    );
  }
}

/// One soft, blurred colour blob. Self-blurring (not a `BackdropFilter`) —
/// see the class doc above for why that distinction matters for scroll
/// performance.
class _Orb extends StatelessWidget {
  const _Orb({required this.diameter, required this.color});

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
