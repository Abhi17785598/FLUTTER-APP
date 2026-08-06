import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/scale_tap.dart';

/// The message input bar (blueprint §16.7).
///
/// Prototype spec: a 38 dp attach button, a pill text field on the app canvas
/// colour, and a 40 dp primary send button carrying
/// `0 4px 12px rgba(91,80,232,0.28)`.
///
/// The attach button is rendered because the prototype shows it, but it is
/// disabled: attachment upload is not part of this milestone and the schema's
/// `image` message type has no upload path in the app yet. A visibly disabled
/// control is honest; a live one that does nothing is not.
class MessageComposer extends StatefulWidget {
  /// Returns an error string to surface, or null on success.
  final Future<String?> Function(String text) onSend;

  final bool sending;

  const MessageComposer({
    super.key,
    required this.onSend,
    this.sending = false,
  });

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.sending) return;

    // Cleared up front so a fast second message is not blocked; restored below
    // if the send fails, so the user never loses what they typed.
    _controller.clear();
    final error = await widget.onSend(text);

    if (!mounted) return;
    if (error != null) {
      _controller.text = text;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _hasText && !widget.sending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: Color(0xFFEDEDF2))),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              label: 'Attachments — not available yet',
              child: Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.attach_file,
                  size: 18,
                  color: AppColors.textHint.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, maxHeight: 120),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.circular(AppConstants.pillRadius),
                ),
                child: Center(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      hintText: 'Type a message...',
                      hintStyle: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Semantics(
              label: 'Send message',
              button: true,
              enabled: canSend,
              child: ScaleTap(
                onTap: canSend ? _submit : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: canSend
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    boxShadow: canSend ? AppColors.primaryActionShadow : null,
                  ),
                  child: widget.sending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send, size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
