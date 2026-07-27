import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class PremiumPageRoute<T> extends PageRouteBuilder<T> {
  PremiumPageRoute({required WidgetBuilder builder})
    : super(
        pageBuilder: (ctx, _, __) => builder(ctx),
        transitionDuration: const Duration(milliseconds: AppConstants.pageTransitionMs),
        transitionsBuilder: (ctx, anim, _, child) {
          return SlideTransition(
            position: Tween(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: anim,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
      );
}
