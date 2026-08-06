import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import '../../widgets/shared/app_action_button.dart';
import '../../widgets/shared/app_surface_card.dart';
import '../shared/section_loader.dart';
import 'widgets/social_screen_shell.dart';

/// Social ▸ Ad Campaigns — the design's `isSocialCampaigns` screen.
///
/// Lists `social_ad_campaigns` with their synced Meta metrics. Creating a
/// campaign is not implemented: React's `CreateCampaignDialog` posts through
/// `meta-campaign-create`, which needs a connected ad account, and spending
/// money is not something to wire up behind a read-only phase.
class SocialCampaignsScreen extends StatelessWidget {
  const SocialCampaignsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SocialCampaignsSection(),
      child: const _CampaignsView(),
    );
  }
}

class _CampaignsView extends StatefulWidget {
  const _CampaignsView();

  @override
  State<_CampaignsView> createState() => _CampaignsViewState();
}

class _CampaignsViewState extends State<_CampaignsView>
    with DeferredSectionLoader<_CampaignsView> {
  @override
  void loadSection(String userId) =>
      context.read<SocialCampaignsSection>().loadFor(userId);

  @override
  Widget build(BuildContext context) {
    final section = context.watch<SocialCampaignsSection>();

    return SocialCampaignsBody(
      campaigns: section.value,
      loading: section.loading,
      failed: section.failed,
      onRefresh: reloadSection,
      onNewCampaign: () => openSectionPlaceholder(context, 'New Campaign'),
    );
  }
}

class SocialCampaignsBody extends StatelessWidget {
  final List<AdCampaign> campaigns;
  final bool loading;
  final bool failed;
  final VoidCallback onRefresh;
  final VoidCallback onNewCampaign;

  const SocialCampaignsBody({
    super.key,
    required this.campaigns,
    required this.loading,
    required this.failed,
    required this.onRefresh,
    required this.onNewCampaign,
  });

  @override
  Widget build(BuildContext context) {
    return SocialScreenShell(
      title: 'Ad Campaigns',
      subtitle: 'Boost your listings on Facebook & Instagram',
      children: [
        const SizedBox(height: AppConstants.spacingL),
        Row(
          children: [
            Expanded(
              child: AppActionButton(
                label: 'Refresh',
                height: 40,
                fontSize: 12.5,
                icon: Icons.refresh,
                variant: AppActionButtonVariant.surface,
                onTap: onRefresh,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppActionButton(
                label: 'New Campaign',
                height: 40,
                fontSize: 12.5,
                icon: Icons.add,
                onTap: onNewCampaign,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingL),
        if (loading)
          const DashboardCard(
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          )
        else if (failed)
          DashboardCard(
            child: EmptyStateView(
              icon: Icons.error_outline,
              message: "Couldn't load your campaigns. Try refreshing.",
              iconCircleSize: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          )
        else if (campaigns.isEmpty)
          DashboardCard(
            child: EmptyStateView(
              icon: Icons.campaign_outlined,
              message: 'No campaigns yet. Boost a property, project, article '
                  'or reel — campaigns you create will show up here.',
              iconCircleSize: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
              actionLabel: 'Create Your First Campaign',
              onAction: onNewCampaign,
            ),
          )
        else
          for (var i = 0; i < campaigns.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _CampaignCard(campaign: campaigns[i]),
          ],
      ],
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final AdCampaign campaign;

  const _CampaignCard({required this.campaign});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  campaign.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              _StatusPill(campaign.displayStatus),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            campaign.objective,
            style: AppTextStyles.caption.copyWith(fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Metric(label: 'Spend', value: campaign.spendDisplay),
              _Metric(label: 'Impressions', value: '${campaign.impressions}'),
              _Metric(label: 'Clicks', value: '${campaign.clicks}'),
              _Metric(label: 'Leads', value: '${campaign.leadsCount}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: AppTextStyles.heading3.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.caption.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final active = status.toUpperCase() == 'ACTIVE';

    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.success : AppColors.background,
        borderRadius: BorderRadius.circular(AppConstants.pillRadius),
      ),
      child: Text(
        status,
        style: AppTextStyles.caption.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.textSecondary,
        ),
      ),
    );
  }
}
