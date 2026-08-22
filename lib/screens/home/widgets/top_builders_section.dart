// screens/home/widgets/top_builders_section.dart
//
// Home's "Top Builders" rail — the Flutter counterpart to the portal's
// sidebar "Top Builders" widget. Reuses [AgentCard] from
// popular_agents_section.dart so every profile rail on Home (brokers,
// influencers, builders) looks like one family of cards.
//
// HIDES ITSELF WHEN THERE IS NOTHING TO SHOW — same convention as every
// other admin/backend-driven Home rail.
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../models/user_profile.dart';
import '../../../services/top_builders_service.dart';
import '../../../widgets/section_header.dart';
import 'popular_agents_section.dart' show AgentCard, kAgentRailHeight;

class TopBuildersSection extends StatefulWidget {
  const TopBuildersSection({super.key, this.service});

  @visibleForTesting
  final TopBuildersService? service;

  @override
  State<TopBuildersSection> createState() => _TopBuildersSectionState();
}

class _TopBuildersSectionState extends State<TopBuildersSection> {
  late final Future<List<UserProfile>> _future =
      (widget.service ?? TopBuildersService()).listActive();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserProfile>>(
      future: _future,
      builder: (context, snapshot) {
        final builders = snapshot.data;
        if (builders == null || builders.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Top Builders'),
              SizedBox(
                height: kAgentRailHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                  ),
                  itemCount: builders.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: AppConstants.spacingM),
                    child: ScaleTap(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.publicProfileScreen,
                        arguments: {'userId': builders[i].userId},
                      ),
                      child: AgentCard(agent: builders[i]),
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
