import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_agent_provider.dart';
import 'conversation_history.dart';
import 'voice_waveform.dart';

class VoiceAgentPanel extends StatefulWidget {
  const VoiceAgentPanel({super.key});

  @override
  State<VoiceAgentPanel> createState() => _VoiceAgentPanelState();
}

class _VoiceAgentPanelState extends State<VoiceAgentPanel> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _send(VoiceAgentProvider provider) {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    provider.processText(text, context);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceAgentProvider>(
      builder: (context, provider, _) {
        final isListening =
            provider.agentState == VoiceAgentStateEnum.listening;
        final isProcessing =
            provider.agentState == VoiceAgentStateEnum.processing;
        final isSpeaking =
            provider.agentState == VoiceAgentStateEnum.speaking;

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'PropCID Assistant',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          tooltip: 'Clear conversation',
                          onPressed: provider.clearConversation,
                        ),
                        IconButton(
                          icon: Icon(provider.isTtsEnabled
                              ? Icons.volume_up
                              : Icons.volume_off),
                          tooltip: provider.isTtsEnabled
                              ? 'Mute voice'
                              : 'Enable voice',
                          onPressed: provider.toggleTts,
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Conversation history
                  Expanded(
                    child: const ConversationHistory(),
                  ),
                  // Listening indicator
                  if (isListening) ...[
                    const SizedBox(height: 8),
                    VoiceWaveform(isActive: isListening),
                    const SizedBox(height: 4),
                    if (provider.liveTranscript.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          provider.liveTranscript,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  // Processing indicator
                  if (isProcessing)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                  // Speaking indicator
                  if (isSpeaking)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.volume_up, size: 16, color: Colors.grey),
                          SizedBox(width: 8),
                          Text(
                            'Speaking…',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  // Quick chips
                  if (!isListening && !isProcessing && !isSpeaking)
                    _QuickChips(provider: provider),
                  // Input row
                  _InputRow(
                    controller: _textController,
                    isListening: isListening,
                    isProcessing: isProcessing,
                    isSpeaking: isSpeaking,
                    onSend: () => _send(provider),
                    onMic: () {
                      if (isListening) {
                        provider.stopListening();
                      } else {
                        provider.startListening(context);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _InputRow extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final bool isProcessing;
  final bool isSpeaking;
  final VoidCallback onSend;
  final VoidCallback onMic;

  const _InputRow({
    required this.controller,
    required this.isListening,
    required this.isProcessing,
    required this.isSpeaking,
    required this.onSend,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            // Mic button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: IconButton.filled(
                icon: Icon(isListening ? Icons.stop : Icons.mic),
                style: IconButton.styleFrom(
                  backgroundColor: isListening
                      ? Colors.red
                      : Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: isListening
                      ? Colors.white
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                onPressed: (isProcessing || isSpeaking) ? null : onMic,
              ),
            ),
            const SizedBox(width: 8),
            // Text field
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !isListening && !isProcessing && !isSpeaking,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isListening
                      ? 'Listening…'
                      : isProcessing
                          ? 'Processing…'
                          : 'Type a command…',
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Send button
            IconButton.filled(
              icon: const Icon(Icons.send),
              onPressed: isListening || isProcessing || isSpeaking ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  final VoiceAgentProvider provider;

  const _QuickChips({required this.provider});

  static const _chips = [
    ('Search properties', 'search_properties'),
    ('My listings', 'my_listings'),
    ('Saved properties', 'saved'),
    ('My visits', 'visits'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: _chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, command) = _chips[i];
          return ActionChip(
            label: Text(label, style: const TextStyle(fontSize: 12)),
            onPressed: () => provider.processText(command, context),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          );
        },
      ),
    );
  }
}
