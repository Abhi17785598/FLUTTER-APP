import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../models/network_relationship.dart';
import '../../providers/network_relationships_provider.dart';
import '../messaging/widgets/chat_avatar.dart';
import '../shared/section_loader.dart';
import 'widgets/network_screen_shell.dart';

/// Network ▸ My Networks — the design's `isMyNetworks` screen.
///
/// Lists the caller's `builder_networks` connections, from either side of the
/// relationship, classified via [NetworkRelationship] rather than the raw
/// row-direction check the previous version rendered directly: "Broker in
/// your network" / "Member of a builder network" told the viewer only which
/// column they happened to be in, never who the other person actually was —
/// and, because `builder_networks`' RLS is fully symmetric with the generic
/// profile "Connect" flow, direction alone can't even be trusted to mean
/// "genuine network membership" (see `network_relationship.dart`'s header).
///
/// Three sections, shown only when non-empty: Current Network Members (rows
/// this viewer owns, with a real broker/influencer counterpart), Networks
/// Joined (builder networks this viewer belongs to), and Peer Connections
/// (accepted, but not safely either of the above). Pending requests and
/// formal invitations keep living in `NetworkInvitationsSection` on the
/// Network hub — they are not a membership until accepted, and moving that
/// already-working Accept/Decline flow here was a UI relocation, not a
/// correctness fix, so it was left alone.
class MyNetworksScreen extends StatelessWidget {
  const MyNetworksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NetworkRelationshipsProvider(),
      child: const _MyNetworksView(),
    );
  }
}

class _MyNetworksView extends StatefulWidget {
  const _MyNetworksView();

  @override
  State<_MyNetworksView> createState() => _MyNetworksViewState();
}

class _MyNetworksViewState extends State<_MyNetworksView>
    with DeferredSectionLoader<_MyNetworksView> {
  // Classification depends only on each row's own direction and the
  // counterpart's real profile type — never on the viewer's own role — so,
  // unlike My Leads/My Referrals, this load has nothing to get wrong by
  // running before `AuthProvider.userType` resolves.
  @override
  void loadSection(String userId) =>
      context.read<NetworkRelationshipsProvider>().load(userId);

  Future<void> _confirmAndLeave(NetworkRelationship relationship) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave network?'),
        content: Text(
          "You'll stop seeing ${relationship.counterpartDisplayLabel} in "
          'your networks.',
        ),
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
    if (confirmed != true || !mounted) return;

    final provider = context.read<NetworkRelationshipsProvider>();
    final ok = await provider.leaveNetwork(relationship.id);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            provider.leaveError ??
                "Couldn't leave this network. Please try again.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NetworkRelationshipsProvider>();

    return MyNetworksBody(
      relationships: provider.relationships,
      loading: provider.loading,
      failed: provider.failed,
      leavingRelationshipId: provider.leavingId,
      onLeave: _confirmAndLeave,
    );
  }
}

class MyNetworksBody extends StatelessWidget {
  final List<NetworkRelationship> relationships;
  final bool loading;
  final bool failed;

  /// The `builder_networks.id` currently being left, so its row can show a
  /// busy state and every row's button can be disabled while it's in flight.
  final String? leavingRelationshipId;

  /// Optional so every pre-existing test that constructs this body directly
  /// keeps compiling and keeps passing with no Leave button rendered.
  final ValueChanged<NetworkRelationship>? onLeave;

  const MyNetworksBody({
    super.key,
    required this.relationships,
    required this.loading,
    required this.failed,
    this.leavingRelationshipId,
    this.onLeave,
  });

  List<NetworkRelationship> _where(NetworkRelationshipKind kind) =>
      relationships.where((r) => r.kind == kind).toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return NetworkScreenShell(
      title: 'My Networks',
      subtitle: 'View and manage your network connections',
      children: [const SizedBox(height: 20), _buildBody()],
    );
  }

  Widget _buildBody() {
    if (loading) {
      return const NetworkTitledCard(
        icon: Icons.people_outline,
        title: 'Current Networks',
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (failed) {
      return const NetworkTitledCard(
        icon: Icons.people_outline,
        title: 'Current Networks',
        child: Padding(
          padding: EdgeInsets.only(top: AppConstants.spacingXXL),
          child: EmptyStateView(
            icon: Icons.error_outline,
            title: "Couldn't load your networks",
            message: 'Try again in a moment.',
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    final owned = _where(NetworkRelationshipKind.ownedNetworkMember);
    final joined = _where(NetworkRelationshipKind.joinedBuilderNetwork);
    final peers = _where(NetworkRelationshipKind.peerConnection);

    if (owned.isEmpty && joined.isEmpty && peers.isEmpty) {
      return NetworkTitledCard(
        icon: Icons.people_outline,
        title: 'Current Networks',
        child: const Padding(
          padding: EdgeInsets.only(top: AppConstants.spacingXXL),
          child: EmptyStateView(
            icon: Icons.apartment_rounded,
            title: 'No Network Memberships',
            message:
                "You haven't joined any networks yet. Invitations you "
                'receive appear on the Network hub.',
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (owned.isNotEmpty) ...[
          NetworkTitledCard(
            icon: Icons.groups_2_outlined,
            title: 'Current Network Members',
            child: _RelationshipList(
              relationships: owned,
              leavingRelationshipId: leavingRelationshipId,
              onLeave: onLeave,
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),
        ],
        if (joined.isNotEmpty) ...[
          NetworkTitledCard(
            icon: Icons.apartment_outlined,
            title: 'Networks Joined',
            child: _RelationshipList(
              relationships: joined,
              leavingRelationshipId: leavingRelationshipId,
              onLeave: onLeave,
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),
        ],
        if (peers.isNotEmpty)
          NetworkTitledCard(
            icon: Icons.link_outlined,
            title: 'Peer Connections',
            child: _RelationshipList(
              relationships: peers,
              leavingRelationshipId: leavingRelationshipId,
              onLeave: onLeave,
            ),
          ),
      ],
    );
  }
}

class _RelationshipList extends StatelessWidget {
  final List<NetworkRelationship> relationships;
  final String? leavingRelationshipId;
  final ValueChanged<NetworkRelationship>? onLeave;

  const _RelationshipList({
    required this.relationships,
    this.leavingRelationshipId,
    this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < relationships.length; i++) ...[
          SizedBox(height: i == 0 ? AppConstants.spacingL : 10),
          _RelationshipRow(
            relationship: relationships[i],
            leaving: relationships[i].id == leavingRelationshipId,
            onLeave: onLeave == null ? null : () => onLeave!(relationships[i]),
          ),
        ],
      ],
    );
  }
}

class _RelationshipRow extends StatelessWidget {
  final NetworkRelationship relationship;
  final bool leaving;
  final VoidCallback? onLeave;

  const _RelationshipRow({
    required this.relationship,
    this.leaving = false,
    this.onLeave,
  });

  /// Commission rate/auto-convert are meaningful only for an owned network
  /// member — a peer connection or a network the viewer joined has no
  /// commission arrangement running the other way.
  bool get _showsCommissionDetails =>
      relationship.kind == NetworkRelationshipKind.ownedNetworkMember;

  @override
  Widget build(BuildContext context) {
    final rate = relationship.commissionRateLabel;

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
              ChatAvatar(
                avatarUrl: relationship.counterpartAvatarUrl,
                initials: relationship.counterpartInitial,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      relationship.counterpartDisplayLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (relationship.counterpartSubtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        relationship.counterpartSubtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              NetworkStatusPill(
                relationship.status,
                positive: relationship.isAccepted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          NetworkDetailRow(label: 'Role', value: relationship.roleLabel),
          if (relationship.createdAt != null)
            NetworkDetailRow(
              label: 'Connected',
              value: _formatConnectedDate(relationship.createdAt!),
            ),
          if (_showsCommissionDetails) ...[
            if (rate != null)
              NetworkDetailRow(label: 'Commission rate', value: rate),
            NetworkDetailRow(
              label: 'Verified',
              value: relationship.verified ? 'Yes' : 'No',
            ),
            NetworkDetailRow(
              label: 'Auto-convert leads',
              value: relationship.autoConvertLeads ? 'On' : 'Off',
            ),
          ],
          // Leaving is meaningful for any accepted relationship — owned,
          // joined or peer — so this isn't gated on `_showsCommissionDetails`.
          if (onLeave != null && relationship.isAccepted) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: leaving ? null : onLeave,
                child: Text(leaving ? 'Leaving…' : 'Leave Network'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Mirrors `NetworkInvitationsSection._formatDate` — no `intl` dependency,
  /// same "Jan 5, 2026" shape the portal's `toLocaleDateString()` produces.
  static String _formatConnectedDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}
