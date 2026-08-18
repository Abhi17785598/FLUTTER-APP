import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/conversation_summary.dart';
import '../../services/messaging_service.dart';
import 'widgets/chat_avatar.dart';

/// Channel participants + role management — mirrors the portal's
/// `ChannelSettingsModal.tsx`. Promote/demote calls are gated client-side by
/// [_isAdmin] purely for UX (hiding controls a non-admin couldn't use
/// anyway); the real enforcement is the `channel_participants` UPDATE RLS
/// policy (admin/moderator/creator only) on the server.
class ChannelSettingsScreen extends StatefulWidget {
  final String channelId;
  final String channelName;
  final String currentUserId;
  final bool isAdmin;

  const ChannelSettingsScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.currentUserId,
    required this.isAdmin,
  });

  @override
  State<ChannelSettingsScreen> createState() => _ChannelSettingsScreenState();
}

class _ChannelSettingsScreenState extends State<ChannelSettingsScreen> {
  final _service = MessagingService();
  List<({ConversationParticipant profile, String role})> _participants = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final loaded = await _service.fetchChannelParticipants(widget.channelId);
      if (!mounted) return;
      setState(() => _participants = loaded);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _setRole(String userId, String role) async {
    try {
      await _service.setChannelParticipantRole(
        channelId: widget.channelId,
        userId: userId,
        role: role,
      );
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update that member's role.")),
        );
      }
    }
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave channel?'),
        content: Text("You'll stop receiving messages from ${widget.channelName}."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.leaveChannel(widget.channelId, widget.currentUserId);
      if (mounted) {
        // Pops both this settings screen and the thread behind it — the
        // thread's provider would otherwise keep polling a channel this
        // user is no longer a participant of.
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't leave the channel.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.channelName),
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: _leave,
            child: const Text('Leave channel'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) {
      return Center(
        child: TextButton(onPressed: _load, child: const Text('Retry')),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _participants.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = _participants[index];
        final isSelf = entry.profile.userId == widget.currentUserId;

        return ListTile(
          leading: ChatAvatar(
            avatarUrl: entry.profile.avatarUrl,
            initials: entry.profile.initial,
            size: 40,
          ),
          title: Text(
            isSelf ? '${entry.profile.displayName} (you)' : entry.profile.displayName,
            style: AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            entry.role[0].toUpperCase() + entry.role.substring(1),
            style: AppTextStyles.caption.copyWith(fontSize: 12),
          ),
          trailing: (widget.isAdmin && !isSelf)
              ? PopupMenuButton<String>(
                  onSelected: (role) => _setRole(entry.profile.userId, role),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'admin', child: Text('Make admin')),
                    PopupMenuItem(value: 'moderator', child: Text('Make moderator')),
                    PopupMenuItem(value: 'member', child: Text('Make member')),
                  ],
                )
              : null,
        );
      },
    );
  }
}
