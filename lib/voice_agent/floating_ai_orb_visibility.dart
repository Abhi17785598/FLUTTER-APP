import 'package:flutter/foundation.dart';

/// Whether `FloatingAiOrb` (the globally-mounted draggable assistant button
/// in `app.dart`) should paint itself right now. Defaults to `true`, so
/// every existing screen is completely unaffected unless something
/// explicitly sets this to `false` — and must set it back to `true` when
/// it no longer applies, since this is process-wide, shared state.
///
/// Added for exactly one caller today: `AuthScreen` sets this to `false` in
/// `initState` (the orb visually covers the Sign In button there) and
/// restores it to `true` in `dispose`, so the auth screen surfaces the same
/// assistant through its own inline "Need help?" action instead — see that
/// screen's `_openHelpPanel`. `FloatingAiOrb` itself keeps its tap/long-press
/// handlers, drag/edge-snap state and animations completely unchanged; only
/// whether it is painted is gated by this flag.
final ValueNotifier<bool> floatingAiOrbVisible = ValueNotifier<bool>(true);
