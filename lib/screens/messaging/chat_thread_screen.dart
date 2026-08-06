import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_thread_provider.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/message_composer.dart';

/// A single conversation, 1:1 or channel (blueprint §16.7 and §16.8).
///
/// One screen serves both. §16.8 suggests a shared base widget rather than
/// duplicating the thread; parameterising the single screen by
/// [ChatThreadKind] achieves that with no second class to keep in sync — the
/// only differences are which table is read (owned by [ChatThreadProvider])
/// and whether bubbles are attributed to a sender.
class ChatThreadScreen extends StatelessWidget {
  final ChatThreadKind kind;
  final String threadId;
  final String title;

  /// Secondary header line — a member count for channels. Nothing is shown for
  /// 1:1 threads: the prototype's "Online" label has no reliable presence
  /// source (see the note on ConversationTile).
  final String? subtitle;

  final String? avatarUrl;
  final String initials;

  /// The other person in a 1:1 thread, when known — makes the header's avatar and
  /// title open their public profile.
  ///
  /// Optional and null by default, so every existing caller compiles and behaves
  /// exactly as before. Null for channels (a group has no single participant) and
  /// for any 1:1 thread whose participant could not be resolved, in which case the
  /// header stays inert, as it was.
  final String? participantUserId;

  const ChatThreadScreen({
    super.key,
    required this.kind,
    required this.threadId,
    required this.title,
    required this.initials,
    this.subtitle,
    this.avatarUrl,
    this.participantUserId,
  });

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ChatThreadProvider(
        kind: kind,
        threadId: threadId,
        userId: userId,
      )..load(),
      child: _ChatThreadView(
        title: title,
        subtitle: subtitle,
        avatarUrl: avatarUrl,
        initials: initials,
        currentUserId: userId,
        // Never offer a profile tap on your own thread with yourself; and a
        // channel passes null already.
        participantUserId:
            participantUserId == userId ? null : participantUserId,
      ),
    );
  }
}

class _ChatThreadView extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final String initials;
  final String currentUserId;
  final String? participantUserId;

  const _ChatThreadView({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    required this.currentUserId,
    this.participantUserId,
  });

  @override
  Widget build(BuildContext context) {
    final thread = context.watch<ChatThreadProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(
            title: title,
            subtitle: subtitle,
            avatarUrl: avatarUrl,
            initials: initials,
            participantUserId: participantUserId,
          ),
          Expanded(child: _buildBody(context, thread)),
          MessageComposer(
            sending: thread.sending,
            onSend: thread.send,
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, ChatThreadProvider thread) {
    if (thread.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (thread.failed && thread.messages.isEmpty) {
      return Center(
        child: EmptyStateView(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load messages",
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: thread.refresh,
        ),
      );
    }

    if (thread.messages.isEmpty) {
      return const Center(
        child: EmptyStateView(
          icon: Icons.chat_bubble_outline,
          title: 'No messages yet',
          message: 'Say hello to start the conversation.',
        ),
      );
    }

    // `reverse: true` anchors the list to the newest message and keeps it
    // pinned when the keyboard opens, so no scroll controller is needed.
    final ordered = thread.messages.reversed.toList();

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: ordered.length,
      itemBuilder: (context, index) {
        final message = ordered[index];
        final isMine = message.senderId == currentUserId;

        return ChatBubble(
          message: message,
          isMine: isMine,
          senderName: thread.isChannel && !isMine
              ? thread.senderFor(message.senderId)?.displayName
              : null,
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final String initials;

  /// When non-null, the avatar and the title open that user's public profile.
  ///
  /// The avatar and title were previously inert — only the back button carried a
  /// gesture — so this adds a tap where there was none rather than re-pointing an
  /// existing one. Null restores the original inert header exactly: no
  /// `GestureDetector` is built at all.
  final String? participantUserId;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    this.participantUserId,
  });

  void _openProfile(BuildContext context) {
    final userId = participantUserId;
    if (userId == null || userId.isEmpty) return;

    Navigator.pushNamed(
      context,
      AppConstants.publicProfileScreen,
      arguments: {'userId': userId},
    );
  }

  /// Wraps [child] in a profile tap, or returns it untouched when there is no
  /// participant — so the null case is byte-identical to the original header.
  ///
  /// Uses a plain `GestureDetector` with `HitTestBehavior.opaque`, matching the
  /// back button a few lines below rather than introducing `ScaleTap`, which this
  /// header does not use anywhere.
  Widget _maybeTappable(
    BuildContext context, {
    required String semanticLabel,
    required Widget child,
  }) {
    if (participantUserId == null || participantUserId!.isEmpty) return child;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openProfile(context),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(bottom: BorderSide(color: Color(0xFFEDEDF2))),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
          child: Row(
            children: [
              Semantics(
                label: 'Back',
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      size: 17,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Row structure, sizes and spacing are unchanged; only the tap is
              // new, and only when a participant is known.
              _maybeTappable(
                context,
                semanticLabel: "Open $title's profile",
                child: ChatAvatar(
                  avatarUrl: avatarUrl,
                  initials: initials,
                  size: 38,
                ),
              ),
              const SizedBox(width: 12),
              // The Expanded stays exactly where it was — the tap wraps its
              // child, not the Expanded itself, so the Row's flex is untouched.
              Expanded(
                child: _maybeTappable(
                  context,
                  semanticLabel: "Open $title's profile",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
