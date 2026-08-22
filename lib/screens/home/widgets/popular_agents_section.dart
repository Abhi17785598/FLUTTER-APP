// screens/home/widgets/popular_agents_section.dart
//
// Home's "Popular Brokers" and "Popular Influencers" rails — the Flutter
// counterpart to the portal's "Top Brokers" / "Top Influencers" sections
// (`PublicHomePage.tsx`/`AuthenticatedHomePage.tsx`, `fetchProjects`'
// `agentsQuery` against `profiles`, split client-side by `user_type`).
//
// Both rails share one query shape (`PeopleSearchService.listPopularAgents`)
// and one card widget below — they differ only in which `UserProfile.isX`
// getter selects their rows and in their section title, so this file holds
// a private base rail rather than two near-duplicate widgets.
//
// HIDES ITSELF WHEN THERE IS NOTHING TO SHOW
// ------------------------------------------
// Same convention as the other admin/backend-driven Home rails: nothing
// renders while loading, on failure, or when there are genuinely no matching
// approved profiles.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../models/user_profile.dart';
import '../../../services/people_search_service.dart';
import '../../../widgets/section_header.dart';
import '../../../widgets/verified_badge.dart';

/// Shared with [TopBuildersSection] — one card style for every profile rail
/// on Home, so a builder/broker/influencer card reads as the same kind of
/// thing wherever it appears.
const double kAgentRailHeight = 168;
const double kAgentCardWidth = 138;

class PopularBrokersSection extends StatelessWidget {
  const PopularBrokersSection({super.key, this.service});

  @visibleForTesting
  final PeopleSearchService? service;

  @override
  Widget build(BuildContext context) {
    return _PopularAgentsRail(
      title: 'Popular Brokers',
      roleSelector: (p) => p.isBroker,
      service: service,
    );
  }
}

class PopularInfluencersSection extends StatelessWidget {
  const PopularInfluencersSection({super.key, this.service});

  @visibleForTesting
  final PeopleSearchService? service;

  @override
  Widget build(BuildContext context) {
    return _PopularAgentsRail(
      title: 'Popular Influencers',
      roleSelector: (p) => p.isInfluencer,
      service: service,
    );
  }
}

class _PopularAgentsRail extends StatefulWidget {
  const _PopularAgentsRail({
    required this.title,
    required this.roleSelector,
    this.service,
  });

  final String title;
  final bool Function(UserProfile) roleSelector;
  final PeopleSearchService? service;

  @override
  State<_PopularAgentsRail> createState() => _PopularAgentsRailState();
}

class _PopularAgentsRailState extends State<_PopularAgentsRail> {
  late final Future<List<UserProfile>> _future =
      (widget.service ?? PeopleSearchService()).listPopularAgents();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserProfile>>(
      future: _future,
      builder: (context, snapshot) {
        final all = snapshot.data;
        if (all == null) return const SizedBox.shrink();
        final agents = all.where(widget.roleSelector).toList();
        if (agents.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: widget.title),
              SizedBox(
                height: kAgentRailHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                  ),
                  itemCount: agents.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: AppConstants.spacingM),
                    child: ScaleTap(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.publicProfileScreen,
                        arguments: {'userId': agents[i].userId},
                      ),
                      child: AgentCard(agent: agents[i]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The card used by every profile rail on Home (brokers, influencers,
/// builders) — avatar, name/company, city, then either a verified badge or
/// years of experience.
class AgentCard extends StatelessWidget {
  const AgentCard({super.key, required this.agent});

  final UserProfile agent;

  @override
  Widget build(BuildContext context) {
    final experience = agent.effectiveExperience;

    return Container(
      width: kAgentCardWidth,
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingS,
        vertical: AppConstants.spacingM,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppColors.surfaceCardShadow,
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: agent.avatarUrl != null
                ? CachedNetworkImage(
                    imageUrl: agent.avatarUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _avatarFallback(agent),
                    errorWidget: (_, _, _) => _avatarFallback(agent),
                  )
                : _avatarFallback(agent),
          ),
          const SizedBox(height: 10),
          Text(
            agent.displayTitle ?? 'PropCID Member',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTextStyles.body.copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (agent.effectiveCity != null) ...[
            const SizedBox(height: 2),
            Text(
              agent.effectiveCity!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 10.5),
            ),
          ],
          const Spacer(),
          if (agent.isVerified)
            const VerifiedBadge()
          else if (experience != null && experience > 0)
            Text(
              '$experience yrs exp.',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatarFallback(UserProfile agent) => Container(
        width: 64,
        height: 64,
        color: AppColors.primaryLight,
        alignment: Alignment.center,
        child: Text(
          agent.initials,
          style: AppTextStyles.heading3.copyWith(
            color: AppColors.primary,
            fontSize: 18,
          ),
        ),
      );
}
