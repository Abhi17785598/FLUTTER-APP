// screens/network/role_directory_screen.dart
//
// Public "browse all" directory for one profile role — Verified Brokers,
// Builders, or Influencers. Destination for the matching Home "Popular
// Categories" tile (`category_icon_grid.dart`), mirroring the portal's
// BrokersList.tsx / BuildersList.tsx / InfluencersList.tsx: one query
// against `profiles` (approved, not blocked, matching `user_type`), a
// client-side name/company/city filter, and a card grid — no pagination,
// matching the portal's own simplicity (all three of its pages fetch the
// full result set in one shot too).
//
// Reuses [AgentCard], the same card every profile rail on Home already uses
// (`popular_agents_section.dart`), rather than drawing a new one.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../models/user_profile.dart';
import '../../services/people_search_service.dart';
import '../home/widgets/popular_agents_section.dart' show AgentCard, kAgentCardWidth, kAgentRailHeight;

class RoleDirectoryScreen extends StatefulWidget {
  const RoleDirectoryScreen({
    super.key,
    required this.userType,
    required this.title,
    this.loader,
  });

  /// `profiles.user_type` this directory lists — `'broker'`, `'builder'`,
  /// or `'influencer'`.
  final String userType;

  final String title;

  /// Overrides the live Supabase query in tests. Production always uses
  /// [_load]'s real one.
  @visibleForTesting
  final Future<List<UserProfile>> Function()? loader;

  @override
  State<RoleDirectoryScreen> createState() => _RoleDirectoryScreenState();
}

class _RoleDirectoryScreenState extends State<RoleDirectoryScreen> {
  final TextEditingController _search = TextEditingController();
  late Future<List<UserProfile>> _future = _load();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _search.addListener(
      () => setState(() => _query = _search.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<UserProfile>> _load() {
    return widget.loader?.call() ?? _loadFromSupabase();
  }

  Future<List<UserProfile>> _loadFromSupabase() async {
    final rows = await Supabase.instance.client
        .from('profiles')
        .select(PeopleSearchService.columns)
        .eq('user_type', widget.userType)
        .eq('approval_status', 'approved')
        .not('is_blocked', 'is', true)
        .order('display_name', ascending: true)
        .limit(200);

    return List<Map<String, dynamic>>.from(
      rows,
    ).map((row) => UserProfile.fromMap(Map<String, dynamic>.from(row))).where(
      (profile) => profile.userId.isNotEmpty,
    ).toList(growable: false);
  }

  List<UserProfile> _filtered(List<UserProfile> all) {
    if (_query.isEmpty) return all;
    return all.where((profile) {
      final name = (profile.displayName ?? '').toLowerCase();
      final company = (profile.companyName ?? '').toLowerCase();
      final city = (profile.effectiveCity ?? '').toLowerCase();
      return name.contains(_query) ||
          company.contains(_query) ||
          city.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          widget.title,
          style: AppTextStyles.heading2.copyWith(fontSize: 17),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search by name, company or city',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppConstants.searchBarRadius,
                  ),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<UserProfile>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyStateView(
                    icon: Icons.cloud_off_rounded,
                    title: "Couldn't load this list",
                    message: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => setState(() => _future = _load()),
                  );
                }

                final results = _filtered(snapshot.data ?? const []);
                if (results.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.person_search_rounded,
                    title: 'No matches',
                    message: _query.isEmpty
                        ? '${widget.title} will appear here once approved.'
                        : 'Try a different name, company or city.',
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: kAgentCardWidth + 16,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: kAgentCardWidth / kAgentRailHeight,
                  ),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final agent = results[index];
                    return GestureDetector(
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppConstants.publicProfileScreen,
                        arguments: {'userId': agent.userId},
                      ),
                      child: AgentCard(agent: agent),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
