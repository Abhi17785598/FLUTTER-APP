import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../models/conversation_summary.dart';
import 'chat_avatar.dart';
import 'relative_time.dart';
import 'unread_badge.dart';

/// One row in the Chats tab: avatar, name, last message, time and unread
/// badge (blueprint §16.6).
///
/// The prototype also shows a green presence dot. It is intentionally absent:
/// ChatModal.tsx does not read a presence field for this list, and while
/// `profiles_public.is_online` exists, 19 of 22 profiles currently report
/// online — it reads as a login flag that is never cleared, not live presence.
/// §16.6 forbids inventing an online-status heuristic, so the dot is omitted
/// and flagged rather than shown from an unreliable source.
class ConversationTile extends StatelessWidget {
  final ConversationSummary conversation;
  final VoidCallback onTap;

  const ConversationTile({
    super.key,
    required this.conversation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final participant = conversation.otherParticipant;
    final unread = conversation.unreadCount;
    final hasUnread = unread > 0;

    return Semantics(
      label: hasUnread
          ? '${conversation.title}, $unread unread'
          : conversation.title,
      button: true,
      child: ScaleTap(
        onTap: onTap,
        child: ColoredBox(
          color: AppColors.background,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEDEDF2)),
              ),
            ),
            child: Row(
              children: [
                ChatAvatar(
                  avatarUrl: participant?.avatarUrl,
                  initials: participant?.initial ?? '?',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body.copyWith(
                                fontSize: 14,
                                fontWeight: hasUnread
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formatRelativeTime(conversation.lastMessageAt),
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 11,
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.lastMessage.isEmpty
                                  ? 'No messages yet'
                                  : conversation.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12.5,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: hasUnread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            UnreadBadge(count: unread),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
