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

/// Social ▸ Leads — the design's `isSocialLeads` screen.
///
/// Lists `social_ad_leads`, the submissions from the caller's Meta lead-ad
/// forms, with the design's client-side search over name, email and phone.
///
/// Read-only: React can change a lead's status (`updateLeadStatus`) and export
/// a CSV. Neither is ported — the first is a write, and the second needs file
/// system access this phase does not take on.
class SocialLeadsScreen extends StatelessWidget {
  const SocialLeadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SocialLeadsSection(),
      child: const _LeadsView(),
    );
  }
}

class _LeadsView extends StatefulWidget {
  const _LeadsView();

  @override
  State<_LeadsView> createState() => _LeadsViewState();
}

class _LeadsViewState extends State<_LeadsView>
    with DeferredSectionLoader<_LeadsView> {
  @override
  void loadSection(String userId) =>
      context.read<SocialLeadsSection>().loadFor(userId);

  @override
  Widget build(BuildContext context) {
    final section = context.watch<SocialLeadsSection>();

    return SocialLeadsBody(
      leads: section.value,
      loading: section.loading,
      failed: section.failed,
      onRefresh: reloadSection,
      onExport: () => openSectionPlaceholder(context, 'Export CSV'),
    );
  }
}

class SocialLeadsBody extends StatefulWidget {
  final List<AdLead> leads;
  final bool loading;
  final bool failed;
  final VoidCallback onRefresh;
  final VoidCallback onExport;

  const SocialLeadsBody({
    super.key,
    required this.leads,
    required this.loading,
    required this.failed,
    required this.onRefresh,
    required this.onExport,
  });

  @override
  State<SocialLeadsBody> createState() => _SocialLeadsBodyState();
}

class _SocialLeadsBodyState extends State<SocialLeadsBody> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Client-side, over the already-loaded list — no extra query, and it
    // matches how the design describes the field.
    final visible =
        widget.leads.where((lead) => lead.matches(_query)).toList();

    return SocialScreenShell(
      title: 'Leads',
      subtitle: 'People who submitted your lead-ad forms',
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
                onTap: widget.onRefresh,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: AppActionButton(
                label: 'Export CSV',
                height: 40,
                fontSize: 12.5,
                icon: Icons.download_outlined,
                variant: AppActionButtonVariant.surface,
                onTap: widget.onExport,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spacingM),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, size: 18, color: AppColors.textPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  textInputAction: TextInputAction.search,
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    hintText: 'Search name, email or phone...',
                    hintStyle: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: AppColors.textHint,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spacingL),
        if (widget.loading)
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
        else if (widget.failed)
          DashboardCard(
            child: EmptyStateView(
              icon: Icons.error_outline,
              message: "Couldn't load your leads. Try refreshing.",
              iconCircleSize: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          )
        else if (widget.leads.isEmpty)
          DashboardCard(
            child: EmptyStateView(
              icon: Icons.people_outline,
              message: 'No leads yet. Run a Leads campaign and submissions '
                  'will appear here automatically.',
              iconCircleSize: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          )
        else if (visible.isEmpty)
          DashboardCard(
            child: EmptyStateView(
              icon: Icons.search_off_rounded,
              message: 'No leads match "$_query".',
              iconCircleSize: 56,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _LeadCard(lead: visible[i]),
          ],
      ],
    );
  }
}

class _LeadCard extends StatelessWidget {
  final AdLead lead;

  const _LeadCard({required this.lead});

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lead.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (lead.email != null || lead.phone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [lead.email, lead.phone]
                        .where((v) => v != null && v.isNotEmpty)
                        .join(' • '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingS),
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppConstants.pillRadius),
            ),
            child: Text(
              lead.status,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
