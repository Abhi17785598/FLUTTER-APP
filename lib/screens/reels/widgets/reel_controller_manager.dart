import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

import '../../../models/reel_model.dart';

/// Manages [VideoPlayerController] lifecycle for the reels feed.
///
/// Why a dedicated manager instead of one controller per page widget?
///   • TikTok/Instagram-style feeds must PRELOAD the neighbouring videos so a
///     swipe starts playing instantly instead of showing a spinner.
///   • Controllers are expensive (native decoders, buffers). We therefore keep
///     a small sliding window of controllers alive (previous, current, next)
///     and dispose everything outside it — bounding memory use regardless of
///     feed length.
///   • Centralising lifecycle here removes the per-page init/dispose races that
///     caused the old screen's flicker and "wrong video playing" glitches.
///
/// [ReelControllerManager] is a [ChangeNotifier]: it notifies whenever a
/// controller's readiness changes (becomes initialized, fails, or times out).
/// The screen listens to this via `AnimatedBuilder` so the UI rebuilds at the
/// exact moment a controller is ready — this is what makes the first reel
/// actually appear instead of being frozen on its pre-init placeholder.
class ReelControllerManager extends ChangeNotifier {
  ReelControllerManager({
    this.windowRadius = 1,
    this.initTimeout = const Duration(seconds: 20),
  });

  /// How many neighbours on each side of the active index to keep initialised.
  final int windowRadius;

  /// How long to wait for `initialize()` before treating a reel as failed.
  /// Without this, a slow/flaky mobile network can leave the UI spinning
  /// forever with no way to recover.
  final Duration initTimeout;

  final Map<int, VideoPlayerController> _controllers = {};
  final Set<int> _failedIndices = {};
  List<ReelModel> _reels = const [];
  int _activeIndex = 0;
  bool _disposed = false;

  VideoPlayerController? controllerAt(int index) => _controllers[index];

  bool hasFailed(int index) => _failedIndices.contains(index);

  void setReels(List<ReelModel> reels) {
    _reels = reels;
  }

  /// Called on page change / first build. Ensures the sliding window around
  /// [index] is initialised, plays the active video (looping, full volume),
  /// mutes + pauses the rest, and disposes controllers that fell outside the
  /// window.
  Future<void> onActiveIndexChanged(int index) async {
    _activeIndex = index;
    if (_reels.isEmpty) return;

    final int lower = (index - windowRadius).clamp(0, _reels.length - 1);
    final int upper = (index + windowRadius).clamp(0, _reels.length - 1);

    // Dispose anything outside the window.
    final toRemove =
        _controllers.keys.where((i) => i < lower || i > upper).toList();
    for (final i in toRemove) {
      await _disposeAt(i);
    }

    // Initialize the active reel first and wait for it to complete. This
    // guarantees the active controller gets the first hardware MediaCodec
    // decoder allocation. Concurrent initialization of all three controllers
    // previously caused the third request to fall back to a software decoder
    // (wrong pixel stride) or to share a slot with a neighbour — producing
    // the green-block / diagonal-artifact corruption.
    await _ensureInitialized(index);

    // Active decoder is now allocated. Apply playback state so the video
    // starts as soon as possible rather than waiting for the neighbours.
    _applyPlaybackState(index);

    // Kick off neighbour preloads in the background. They notify the UI
    // independently as each one finishes so the swipe-to-next transition
    // remains instant, but they no longer race for the decoder slot.
    for (int i = lower; i <= upper; i++) {
      if (i == index) continue;
      // ignore: unawaited_futures
      _ensureInitialized(i);
    }
  }

  void _applyPlaybackState(int activeIndex) {
    for (final entry in _controllers.entries) {
      final c = entry.value;
      if (!c.value.isInitialized) continue;
      if (entry.key == activeIndex) {
        // The active reel plays with full audio — this is the fix for
        // Issue 2: previously this branch called setVolume(0.0), muting
        // every reel with no code path ever restoring volume.
        c
          ..setVolume(1.0)
          ..setLooping(true)
          ..play();
      } else {
        // Preloaded neighbours stay muted and paused so only the active
        // reel is ever heard.
        c
          ..setVolume(0.0)
          ..pause()
          ..seekTo(Duration.zero);
      }
    }
  }

  Future<void> _ensureInitialized(int index) async {
    if (_controllers.containsKey(index)) return;
    if (index < 0 || index >= _reels.length) return;

    final url = _reels[index].videoUrl;
    if (url.isEmpty) {
      _failedIndices.add(index);
      _safeNotify();
      return;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _controllers[index] = controller;
    _failedIndices.remove(index);

    try {
      if (kDebugMode) {
        final filename = Uri.parse(url).pathSegments.lastOrNull ?? url;
        debugPrint('[ReelDebug] init start    [$index]: $filename');
      }
      await controller.initialize().timeout(initTimeout);

      // The controller may have been evicted from the window (user swiped
      // past it) while we were awaiting initialize(). Calling further
      // methods on a disposed controller throws, so bail out here rather
      // than touching it.
      if (_controllers[index] != controller) return;

      if (kDebugMode) {
        final v = controller.value;
        debugPrint(
          '[ReelDebug] init complete [$index]: '
          '${v.size.width.toStringAsFixed(0)}×${v.size.height.toStringAsFixed(0)} '
          'dur=${v.duration.inMilliseconds}ms',
        );
        // One-shot listener: fires on first decoded frame or on playback error.
        late VoidCallback onFirstFrame;
        onFirstFrame = () {
          if (controller.value.hasError) {
            debugPrint(
              '[ReelDebug] playback error [$index]: '
              '${controller.value.errorDescription}',
            );
            controller.removeListener(onFirstFrame);
          } else if (controller.value.position > Duration.zero) {
            debugPrint('[ReelDebug] first frame    [$index]');
            controller.removeListener(onFirstFrame);
          }
        };
        controller.addListener(onFirstFrame);
      }

      await controller.setLooping(true);
      await controller.setVolume(index == _activeIndex ? 1.0 : 0.0);

      if (_controllers[index] != controller) return;
      if (index == _activeIndex) {
        // Deliberately NOT awaited: play() only needs to be *issued*, not
        // settled, before we notify the UI that this controller is ready.
        // Awaiting it here previously left `finally`'s _safeNotify() (the
        // only thing that tells ReelVideoView to rebuild and show the
        // video) stuck behind however long play() took to resolve — on a
        // slow network that could be indefinitely, producing a permanent
        // black screen despite the controller being fully initialized.
        controller.play();
      }
    } catch (e) {
      debugPrint('Reel controller init failed [$index]: $e');
      if (kDebugMode) debugPrint('[ReelDebug] init FAILED    [$index]: $e');
      // Only mark as failed if this controller is still the tracked one for
      // this index (i.e. wasn't already disposed/replaced during the await).
      if (_controllers[index] == controller) {
        _failedIndices.add(index);
      }
    } finally {
      // Notify regardless of outcome: either the controller is now ready and
      // the UI should show the video, or it failed/timed out and the UI
      // should show the error fallback instead of spinning forever.
      _safeNotify();
    }
  }


  Future<void> _disposeAt(int index) async {
    final c = _controllers.remove(index);
    _failedIndices.remove(index);
    if (c != null) {
      try {
        await c.pause();
      } catch (_) {
        // Already disposed or in a bad state — safe to ignore during cleanup.
      }
      await c.dispose();
    }
  }

  void pauseActive() {
    _controllers[_activeIndex]?.pause();
  }

  void playActive() {
    _controllers[_activeIndex]?.play();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> disposeAll() async {
    _disposed = true;
    for (final c in _controllers.values) {
      try {
        await c.pause();
      } catch (_) {
        // Ignore — controller may already be in a torn-down state.
      }
      await c.dispose();
    }
    _controllers.clear();
    _failedIndices.clear();
    super.dispose();
  }
}