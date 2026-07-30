import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_navigator.dart';
import '../providers/voice_agent_provider.dart';
import 'voice_agent_panel.dart';

/// Visual/interaction redesign of `VoiceAgentButton` — a draggable, premium
/// "orb" that snaps to the nearest screen edge on release. AI behavior is
/// untouched: tap and long-press call exactly the same `_openPanel()` /
/// `provider.startListening()` this button always called; no new gestures,
/// no `VoiceAgentProvider` changes.
class FloatingAiOrb extends StatefulWidget {
  const FloatingAiOrb({super.key});

  @override
  State<FloatingAiOrb> createState() => _FloatingAiOrbState();
}

class _FloatingAiOrbState extends State<FloatingAiOrb>
    with TickerProviderStateMixin {
  static const double _size = 56;
  static const double _edgeMargin = 12;

  Offset? _position;
  late final AnimationController _snapController;
  Animation<Offset>? _snapAnimation;
  late final AnimationController _breatheController;
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
    _snapController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addListener(() {
          final anim = _snapAnimation;
          if (anim != null) setState(() => _position = anim.value);
        });
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _orbitController.dispose();
    _snapController.dispose();
    super.dispose();
  }

  // ── Same behavior as VoiceAgentButton, verbatim ─────────────────────────

  void _openPanel() {
    final overlayContext = appNavigatorKey.currentState?.overlay?.context;
    if (overlayContext == null) return;
    showModalBottomSheet(
      context: overlayContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceAgentPanel(),
    );
  }

  void _onLongPress(VoiceAgentProvider provider) {
    _openPanel();
    Future.delayed(const Duration(milliseconds: 350), () {
      final overlayCtx = appNavigatorKey.currentState?.overlay?.context;
      if (overlayCtx != null) provider.startListening(overlayCtx);
    });
  }

  // ── Drag + edge-snap (new, purely visual/interaction) ───────────────────

  void _onPanUpdate(DragUpdateDetails details, Size screenSize) {
    final current = _position!;
    final next = current + details.delta;
    setState(() {
      _position = Offset(
        next.dx.clamp(_edgeMargin, screenSize.width - _size - _edgeMargin),
        next.dy.clamp(40, screenSize.height - _size - 40),
      );
    });
  }

  void _onPanEnd(Size screenSize) {
    final current = _position!;
    final snapToLeft = current.dx < (screenSize.width - _size) / 2;
    final targetX = snapToLeft
        ? _edgeMargin
        : screenSize.width - _size - _edgeMargin;
    _snapAnimation =
        Tween<Offset>(begin: current, end: Offset(targetX, current.dy)).animate(
          CurvedAnimation(parent: _snapController, curve: Curves.easeOutCubic),
        );
    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    _position ??= Offset(
      screenSize.width - _size - 16,
      screenSize.height - _size - 80,
    );

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: Consumer<VoiceAgentProvider>(
        builder: (context, provider, _) {
          final agentState = provider.agentState;
          final isListening = agentState == VoiceAgentStateEnum.listening;
          final isProcessing = agentState == VoiceAgentStateEnum.processing;
          final isSpeaking = agentState == VoiceAgentStateEnum.speaking;

          Widget icon;
          Color bg;

          if (isListening) {
            icon = const Icon(Icons.mic, color: Colors.white);
            bg = Colors.red;
          } else if (isProcessing) {
            icon = SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            );
            bg = Theme.of(context).colorScheme.primary;
          } else if (isSpeaking) {
            icon = const Icon(Icons.volume_up, color: Colors.white);
            bg = Colors.deepPurple;
          } else {
            icon = Icon(
              Icons.support_agent_rounded,
              color: Theme.of(context).colorScheme.onPrimary,
            );
            bg = Theme.of(context).colorScheme.primary;
          }

          return GestureDetector(
            onTap: _openPanel,
            onPanUpdate: (details) => _onPanUpdate(details, screenSize),
            onPanEnd: (_) => _onPanEnd(screenSize),
            onLongPress: () => _onLongPress(provider),
            // Deliberately NOT wrapped in a SizedBox any larger than _size —
            // the decorative layers below overflow past this box (via
            // Clip.none), but the box itself must stay _size×_size so the
            // drag/clamp math in _onPanUpdate/_onPanEnd (all keyed off
            // `_size`) matches where the orb actually renders.
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Slow-orbiting particle glow.
                AnimatedBuilder(
                  animation: _orbitController,
                  builder: (context, _) {
                    return Stack(
                      clipBehavior: Clip.none,
                      children: List.generate(3, (i) {
                        final angle =
                            _orbitController.value * 2 * math.pi +
                            i * (2 * math.pi / 3);
                        final radius = _size / 2 + 9;
                        final dx = radius * math.cos(angle);
                        final dy = radius * math.sin(angle);
                        return Positioned(
                          left: _size / 2 + dx - 3,
                          top: _size / 2 + dy - 3,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: bg.withOpacity(0.7),
                              boxShadow: [
                                BoxShadow(
                                  color: bg.withOpacity(0.55),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
                // Translucent glass ring — blurs whatever is scrolling
                // underneath the orb for a genuine glassmorphism look.
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(
                      width: _size + 10,
                      height: _size + 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                        ),
                      ),
                    ),
                  ),
                ),
                AnimatedBuilder(
                  animation: _breatheController,
                  builder: (context, child) {
                    final t = _breatheController.value;
                    return Container(
                      width: _size,
                      height: _size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [bg.withOpacity(0.35), bg.withOpacity(0.05)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: bg.withOpacity(0.30 + 0.18 * t),
                            blurRadius: 18 + 10 * t,
                            spreadRadius: 1 + t,
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: bg,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(child: icon),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
