import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class PremiumPageRoute<T> extends PageRouteBuilder<T> {
  /// [settings] is optional and defaults to null, preserving the behaviour of
  /// every existing caller. Pass it from `onGenerateRoute` when the route must
  /// be identifiable later — e.g. `Navigator.popUntil` matching on
  /// `route.settings.name`. Without it `settings.name` is null and no
  /// name-based navigation predicate can ever match.
  PremiumPageRoute({required WidgetBuilder builder, super.settings})
    : super(
        pageBuilder: (ctx, _, __) => builder(ctx),
        transitionDuration: const Duration(
          milliseconds: AppConstants.pageTransitionMs,
        ),
        transitionsBuilder: (ctx, anim, _, child) {
          return SlideTransition(
            position: Tween(begin: const Offset(0.04, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
            child: FadeTransition(opacity: anim, child: child),
          );
        },
      );
}
