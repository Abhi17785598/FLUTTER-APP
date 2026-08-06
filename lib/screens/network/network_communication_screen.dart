import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../core/widgets/segmented_tab_pill.dart';
import '../../models/network_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/network_section_provider.dart';
import '../../widgets/shared/app_action_button.dart';
import '../../widgets/shared/app_surface_card.dart';
import '../../widgets/shared/toggle_row.dart';
import '../shared/section_loader.dart';
import 'widgets/network_screen_shell.dart';

/// Network ▸ Communication — the design's `isCommunication` screen.
///
/// Three sub-tabs (Channels / Messaging / Settings) over `network_channels`.
///
/// Read-only: creating a channel and sending a bulk message are writes, and the
/// two Settings switches have no column of their own — `network_channels` stores
/// `is_auto_join` and `member_types` per channel, not per-network notification
/// preferences. They are therefore reported from the channels that exist rather
/// than presented as editable settings. See the note rendered on that tab.
class NetworkCommunicationScreen extends StatelessWidget {
  const NetworkCommunicationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NetworkChannelsSection(),
      child: const _CommunicationView(),
    );
  }
}

class _CommunicationView extends StatefulWidget {
  const _CommunicationView();

  @override
  State<_CommunicationView> createState() => _CommunicationViewState();
}

class _CommunicationViewState extends State<_CommunicationView>
    with DeferredSectionLoader<_CommunicationView> {
  @override
  void loadSection(String userId) {
    // `network_channels` is keyed by builder_id. A member legitimately has no
    // rows, and the query returns an empty list rather than failing.
    context.read<NetworkChannelsSection>().loadFor(userId);
  }

  @override
  Widget build(BuildContext context) {
    final section = context.watch<NetworkChannelsSection>();
    final isBuilder =
        context.read<AuthProvider>().userType?.toLowerCase() == 'builder';

    return NetworkCommunicationBody(
      channels: section.value,
      loading: section.loading,
      failed: section.failed,
      isBuilder: isBuilder,
      onCreateChannel: () => openSectionPlaceholder(context, 'Create Channel'),
      onBulkMessage: () => openSectionPlaceholder(context, 'Bulk Message'),
    );
  }
}

class NetworkCommunicationBody extends StatefulWidget {
  final List<NetworkChannel> channels;
  final bool loading;
  final bool failed;
  final bool isBuilder;
  final VoidCallback onCreateChannel;
  final VoidCallback onBulkMessage;

  const NetworkCommunicationBody({
    super.key,
    required this.channels,
    required this.loading,
    required this.failed,
    required this.onCreateChannel,
    required this.onBulkMessage,
    this.isBuilder = false,
  });

  @override
  State<NetworkCommunicationBody> createState() =>
      _NetworkCommunicationBodyState();
}

class _NetworkCommunicationBodyState extends State<NetworkCommunicationBody> {
  int _tab = 0;

  static const List<String> _tabs = ['Channels', 'Messaging', 'Settings'];

  @override
  Widget build(BuildContext context) {
    return NetworkScreenShell(
      title: 'Network Communication',
      subtitle: 'Channels, announcements & messages',
      children: [
        const SizedBox(height: 18),
        NetworkIntroBanner(
          title: 'Network Communication Hub',
          description: 'Manage channels, send announcements, and stay '
              'connected with your network',
          action: Row(
            children: [
              Expanded(
                child: AppActionButton(
                  label: 'Create Channel',
                  height: 40,
                  fontSize: 12.5,
                  icon: Icons.add,
                  onTap: widget.onCreateChannel,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppActionButton(
                  label: 'Bulk Message',
                  height: 40,
                  fontSize: 12.5,
                  icon: Icons.send_outlined,
                  variant: AppActionButtonVariant.outline,
                  onTap: widget.onBulkMessage,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingL),
        SegmentedTabPill(
          labels: _tabs,
          selectedIndex: _tab,
          onChanged: (index) => setState(() => _tab = index),
          labelFontSize: 12,
          itemVerticalPadding: 9,
        ),
        const SizedBox(height: AppConstants.spacingL),
        _buildTab(),
      ],
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 1:
        return const DashboardCard(
          child: SizedBox(
            height: 128,
            child: Center(
              child: EmptyStateView(
                icon: Icons.chat_bubble_outline,
                message: 'No network messages yet',
                iconCircleSize: 52,
                padding: EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
        );
      case 2:
        return _SettingsTab(channels: widget.channels, failed: widget.failed);
      default:
        return NetworkTitledCard(
          icon: Icons.tag,
          title: 'Network Channels',
          child: _buildChannels(),
        );
    }
  }

  Widget _buildChannels() {
    if (widget.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (widget.failed) {
      return const Padding(
        padding: EdgeInsets.only(top: AppConstants.spacingXL),
        child: EmptyStateView(
          icon: Icons.error_outline,
          title: "Couldn't load channels",
          message: 'Try again in a moment.',
          iconCircleSize: 56,
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        ),
      );
    }

    if (widget.channels.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppConstants.spacingXL),
        child: EmptyStateView(
          icon: Icons.chat_bubble_outline,
          title: 'No Channels Created',
          message: 'Create channels to organize communication with your '
              'network members.',
          iconCircleSize: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          actionLabel: 'Create First Channel',
          onAction: widget.onCreateChannel,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.channels.length; i++) ...[
          SizedBox(height: i == 0 ? AppConstants.spacingL : 10),
          _ChannelRow(channel: widget.channels[i]),
        ],
      ],
    );
  }
}

/// The design's two switches, reported from the channels that exist.
class _SettingsTab extends StatelessWidget {
  final List<NetworkChannel> channels;
  final bool failed;

  const _SettingsTab({required this.channels, required this.failed});

  @override
  Widget build(BuildContext context) {
    // Derived, not invented: a network has channel notifications in play if any
    // channel exists, and member self-service joining if any channel is
    // auto-join. Neither is a stored preference, which is why both are inert.
    final hasChannels = channels.isNotEmpty;
    final anyAutoJoin = channels.any((c) => c.isAutoJoin);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'These reflect your channel setup. Changing them becomes '
                  'available once channel management ships.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11.5,
                        height: 1.45,
                        color: AppColors.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingM),
        DashboardCard(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ToggleRow(
                label: 'Channel notifications',
                value: !failed && hasChannels,
                showDivider: true,
              ),
              ToggleRow(
                label: 'Allow member invites',
                value: !failed && anyAutoJoin,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final NetworkChannel channel;

  const _ChannelRow({required this.channel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tag, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  channel.purposeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (channel.isAutoJoin) ...[
                const SizedBox(width: AppConstants.spacingS),
                const NetworkStatusPill('Auto-join', positive: true),
              ],
            ],
          ),
          if (channel.memberTypes.isNotEmpty) ...[
            const SizedBox(height: 8),
            NetworkDetailRow(
              label: 'Member types',
              value: channel.memberTypes.join(', '),
            ),
          ],
        ],
      ),
    );
  }
}
