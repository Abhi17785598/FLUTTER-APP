import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../models/network_models.dart';
import '../../providers/network_section_provider.dart';
import '../shared/section_loader.dart';
import 'widgets/network_screen_shell.dart';

/// Network ▸ My Networks — the design's `isMyNetworks` screen.
///
/// Lists the caller's `builder_networks` connections, from either side of the
/// relationship, exactly as `NetworkMemberships.tsx` fetches them.
///
/// React also lists pending `builder_network_invitations` with Accept/Decline
/// buttons. Those are writes and are not ported; the design's own empty copy
/// tells the user invitations arrive here, and responding to one stays on the
/// web portal for now.
class MyNetworksScreen extends StatelessWidget {
  const MyNetworksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NetworkMembershipsSection(),
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
  @override
  void loadSection(String userId) =>
      context.read<NetworkMembershipsSection>().loadFor(userId);

  @override
  Widget build(BuildContext context) {
    final section = context.watch<NetworkMembershipsSection>();

    return MyNetworksBody(
      memberships: section.value,
      loading: section.loading,
      failed: section.failed,
    );
  }
}

class MyNetworksBody extends StatelessWidget {
  final List<NetworkMembership> memberships;
  final bool loading;
  final bool failed;

  const MyNetworksBody({
    super.key,
    required this.memberships,
    required this.loading,
    required this.failed,
  });

  @override
  Widget build(BuildContext context) {
    return NetworkScreenShell(
      title: 'My Networks',
      subtitle: 'View and manage your network connections',
      children: [
        const SizedBox(height: 20),
        NetworkTitledCard(
          icon: Icons.people_outline,
          title: 'Current Networks',
          child: _buildBody(),
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (loading) {
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

    if (failed) {
      return const Padding(
        padding: EdgeInsets.only(top: AppConstants.spacingXXL),
        child: EmptyStateView(
          icon: Icons.error_outline,
          title: "Couldn't load your networks",
          message: 'Try again in a moment.',
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }

    if (memberships.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: AppConstants.spacingXXL),
        child: EmptyStateView(
          icon: Icons.apartment_rounded,
          title: 'No Network Memberships',
          message: "You haven't joined any networks yet. When others invite "
              'you to their network, the invitation will appear here.',
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < memberships.length; i++) ...[
          SizedBox(height: i == 0 ? AppConstants.spacingL : 10),
          _MembershipRow(membership: memberships[i]),
        ],
      ],
    );
  }
}

class _MembershipRow extends StatelessWidget {
  final NetworkMembership membership;

  const _MembershipRow({required this.membership});

  @override
  Widget build(BuildContext context) {
    final rate = membership.commissionRateLabel;

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
              Expanded(
                child: Text(
                  // The relationship is described by role, not by name: the
                  // counterparty's profile is a separate read this screen does
                  // not make, and inventing a name would be worse than not
                  // showing one.
                  membership.isBuilderSide
                      ? '${membership.memberTypeLabel} in your network'
                      : 'Member of a builder network',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              NetworkStatusPill(
                membership.status,
                positive: membership.isAccepted,
              ),
            ],
          ),
          const SizedBox(height: 8),
          NetworkDetailRow(
            label: 'Member type',
            value: membership.memberTypeLabel,
          ),
          if (rate != null)
            NetworkDetailRow(label: 'Commission rate', value: rate),
          NetworkDetailRow(
            label: 'Verified',
            value: membership.verified ? 'Yes' : 'No',
          ),
          NetworkDetailRow(
            label: 'Auto-convert leads',
            value: membership.autoConvertLeads ? 'On' : 'Off',
          ),
        ],
      ),
    );
  }
}
