import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_navigator.dart';
import '../providers/voice_agent_provider.dart';
import 'voice_agent_panel.dart';

class VoiceAgentButton extends StatelessWidget {
  const VoiceAgentButton({super.key});

  void _openPanel() {
    // The button lives in MaterialApp.builder — above the Navigator — so the
    // local BuildContext has no Navigator ancestor. Use the overlay context,
    // which is built INSIDE the Navigator and correctly resolves Navigator.of().
    final overlayContext = appNavigatorKey.currentState?.overlay?.context;
    if (overlayContext == null) return;
    showModalBottomSheet(
      context: overlayContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceAgentPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceAgentProvider>(
      builder: (context, provider, _) {
        final agentState = provider.agentState;
        final isListening = agentState == VoiceAgentStateEnum.listening;
        final isProcessing = agentState == VoiceAgentStateEnum.processing;
        final isSpeaking = agentState == VoiceAgentStateEnum.speaking;

        Widget icon;
        Color? bg;

        if (isListening) {
          icon = const Icon(Icons.mic, color: Colors.white);
          bg = Colors.red;
        } else if (isProcessing) {
          icon = SizedBox(
            width: 24,
            height: 24,
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
            Icons.auto_awesome,
            color: Theme.of(context).colorScheme.onPrimary,
          );
          bg = Theme.of(context).colorScheme.primary;
        }

        return GestureDetector(
          onLongPress: () {
            _openPanel();
            // Small delay so panel opens before listening starts.
            Future.delayed(const Duration(milliseconds: 350), () {
              final overlayCtx = appNavigatorKey.currentState?.overlay?.context;
              if (overlayCtx != null) {
                provider.startListening(overlayCtx);
              }
            });
          },
          child: FloatingActionButton(
            heroTag: 'voice_agent_fab',
            backgroundColor: bg,
            onPressed: _openPanel,
            child: icon,
          ),
        );
      },
    );
  }
}
