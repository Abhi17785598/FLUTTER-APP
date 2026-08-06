import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/chat_message.dart';
import 'relative_time.dart';

/// One message bubble (blueprint §16.7).
///
/// Prototype spec: max 78% width, 16 dp radius, own messages solid primary
/// with white text and no shadow, incoming white with
/// `0 2px 8px rgba(26,26,46,0.05)`, timestamp beneath in 10 dp hint colour.
///
/// Non-text types (`property_share`, `image`) render their stored body with a
/// small type chip rather than a blank bubble — §16.7 requires they degrade
/// gracefully until rich rendering exists.
class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;

  /// Sender name, shown above incoming bubbles in channel threads only.
  final String? senderName;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.senderName,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isRich = message.messageType != 'text';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (senderName != null && !isMine) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 3),
              child: Text(
                senderName!,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
          Container(
            constraints: BoxConstraints(maxWidth: width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: isMine ? AppColors.primary : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isMine ? null : AppColors.surfaceCardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isRich) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        message.isPropertyShare
                            ? Icons.home_work_outlined
                            : Icons.attachment_outlined,
                        size: 13,
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.85)
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        message.isPropertyShare ? 'Property' : 'Attachment',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.85)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message.displayContent,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    height: 1.45,
                    color: isMine ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
            child: Text(
              formatClockTime(message.createdAt),
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
