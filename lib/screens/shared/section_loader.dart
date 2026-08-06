import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/animations/page_transitions.dart';
import '../../providers/auth_provider.dart';
import '../stubs/coming_soon_screen.dart';

/// The once-per-user deferred load every module's leaf screen performs.
///
/// Factored into a mixin because all six repeat the identical lifecycle fix:
/// a section's `load()` raises its loading flag and notifies before its first
/// `await`, and `didChangeDependencies` runs inside the build phase, so calling
/// it directly marks the element dirty while it is still building and trips
/// `assert(!_dirty)`. Deferring to the end of the frame lets the first build
/// complete against the initial state.
///
/// Same fix as Profile, Messages and Subscription. Promoted out of the Social
/// module in Phase 9 so the Network leaves share the one copy.
mixin DeferredSectionLoader<T extends StatefulWidget> on State<T> {
  String? _loadedUserId;

  /// The user the section was loaded for, so a Refresh control can re-run the
  /// same fetch without looking the id up again.
  String? get loadedUserId => _loadedUserId;

  /// Kick off the section's fetch. Called at most once per user id, always
  /// after the current frame.
  void loadSection(String userId);

  /// Re-runs [loadSection] for the already-resolved user. No-op before the
  /// first load.
  void reloadSection() {
    final userId = _loadedUserId;
    if (userId == null) return;
    loadSection(userId);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final userId = context.read<AuthProvider>().userId;
    if (userId == null || userId == _loadedUserId) return;
    _loadedUserId = userId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      loadSection(userId);
    });
  }
}

/// Opens the shared placeholder for an action a phase does not implement, so a
/// control never dead-ends.
void openSectionPlaceholder(BuildContext context, String title) {
  Navigator.of(context).push(
    PremiumPageRoute(builder: (_) => ComingSoonScreen(title: title)),
  );
}
