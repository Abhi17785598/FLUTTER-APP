import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/profile_completion.dart';
import '../../models/property_model.dart';
import '../../models/user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/profile_provider.dart';
import '../../services/property_service.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/more_bottom_sheet.dart';
import '../../widgets/workspace_drawer.dart';
import '../dashboard/builder_dashboard_screen.dart';
import '../post_property/post_property_screen.dart';
import 'actions/visiting_card_sheet.dart';
import 'widgets/create_content_grid.dart';
import 'widgets/manage_list_section.dart';
import 'widgets/my_activity_section.dart';
import '../dashboard/widgets/my_projects_section.dart';
import 'widgets/my_content_section.dart';
import 'widgets/profile_action_row.dart';
import 'widgets/profile_completion_card.dart';
import 'widgets/profile_cover_header.dart';
import 'widgets/profile_identity_block.dart';
import 'widgets/profile_stats_row.dart';

/// The user's personal landing screen — identity, stats, quick content
/// creation, a content overview and entry points into the management
/// surfaces.
///
/// Rebuilt against the approved prototype (blueprint §16.4). It is no longer
/// itself "a dashboard": the deep management surface lives behind the Manage
/// Dashboard dispatcher.
///
/// Every destination the previous screen offered is preserved — Dashboard,
/// Manage Properties, Projects (builder-only), Saved, Subscription, Settings,
/// Logout, Feed, Reels, Messages and Network — relocated across the Manage
/// list, the Workspace Drawer and the More sheet rather than dropped.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ProfileProvider(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Guards against re-loading on every rebuild while still picking up the
  /// user id when it arrives asynchronously from AuthProvider.
  String? _loadedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Profile is index 3 in BottomNavBar (Home 0, Search 1, Reels 2,
      // Profile 3) — the centre "+" is an unindexed slot. See blueprint §2.1.
      Provider.of<NavigationProvider>(context, listen: false).setIndex(3);
      _loadIfNeeded();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadIfNeeded();
  }

  void _loadIfNeeded() {
    final userId = context.read<AuthProvider>().userId;
    if (userId == null || userId == _loadedUserId) return;
    _loadedUserId = userId;

    // `load()` is an async method, but its body runs synchronously up to the
    // first `await` — and both of its branches call notifyListeners() before
    // that point to raise their loading flags. This method is reached from
    // didChangeDependencies, which runs inside the build phase, so calling it
    // directly marks this element dirty while it is still building and trips
    // `assert(!_dirty)` in framework.dart.
    //
    // Deferring to the end of the frame lets the first build complete with the
    // provider's initial (loading) state, then delivers the notification when
    // the tree is settled. The provider reference is captured now rather than
    // looked up in the callback, so nothing touches this context after the
    // widget may have been deactivated.
    final provider = context.read<ProfileProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.load(userId);
    });
  }

  // ── Navigation helpers ────────────────────────────────────────────────────

  /// Opens the single Edit Profile screen, for every role.
  ///
  /// Phase 3, approved Option A. This previously switched on `user_type` and sent
  /// builders, brokers and influencers to `/builder-profile`, `/broker-profile` or
  /// `/influencer-profile` — the 7-step **registration wizards** — so "Edit
  /// Profile" restarted registration rather than editing, and individuals got a
  /// name/email dialog that never persisted anything.
  ///
  /// Those wizard routes are unchanged and still reached for first-time profile
  /// completion via `splash_screen`, `auth_post_login`,
  /// `profile_completion_coordinator` and `rbac_service`. Only this editing entry
  /// point moved.
  void _editProfile(AuthProvider auth) {
    Navigator.pushNamed(context, AppConstants.editProfileScreen);
  }

  void _openDashboard() {
    Navigator.pushNamed(context, AppConstants.manageDashboardScreen);
  }

  /// Opens the editor for a new article, or an existing one when [articleId]
  /// is supplied. Refreshes My Content when the editor reports a submission.
  Future<void> _openArticleEditor([String? articleId]) async {
    final saved = await Navigator.pushNamed(
      context,
      AppConstants.articleEditorScreen,
      arguments: {'articleId': articleId},
    );

    if (saved == true && mounted) {
      await context.read<ProfileProvider>().refresh();
    }
  }

  void _openPropertyDetail(PropertyModel property) {
    Navigator.pushNamed(
      context,
      AppConstants.propertyDetailScreen,
      arguments: {'propertyId': property.id},
    );
  }

  /// Opens the existing property-edit wizard from "My Content" — the same
  /// fetch-then-push flow `MyListingsSection._openEditScreen` already uses on
  /// the broker/influencer/individual dashboards, so editing behaves
  /// identically regardless of which screen the owner reaches it from.
  Future<void> _openEditProperty(PropertyModel property) async {
    PropertyEditBundle bundle;
    try {
      bundle = await PropertyService().fetchForEdit(property.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load property for editing: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (!mounted) return;
    final refreshNeeded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostPropertyScreen(
          editPropertyId: property.id,
          editBundle: bundle,
        ),
      ),
    );

    if (refreshNeeded == true && mounted) {
      await context.read<ProfileProvider>().refresh();
    }
  }

  /// Deletes a property from "My Content" — same confirmation dialog and
  /// `PropertyService.deleteProperty` call as
  /// `MyListingsSection._showDeleteDialog`, refreshing via the provider
  /// instead of pruning a local list.
  Future<void> _deleteProperty(PropertyModel property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property'),
        content: const Text(
          'Are you sure you want to delete this property? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await PropertyService().deleteProperty(property.id);
      if (!mounted) return;
      await context.read<ProfileProvider>().refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Property deleted.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();

    final isBuilder = auth.userType?.toLowerCase() == 'builder';
    final isInfluencer = auth.userType?.toLowerCase() == 'influencer';
    final completion = calculateProfileCompletion(auth.profileRow);
    final initial =
        auth.userName.isNotEmpty ? auth.userName[0].toUpperCase() : 'U';

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: const WorkspaceDrawer(),
      drawerScrimColor: WorkspaceDrawer.scrimColor,
      // The cover bleeds under the status bar, so SafeArea is applied per
      // section below rather than wrapping the whole body.
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: profile.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileCoverHeader(
                avatarUrl: auth.avatarUrl,
                coverImageUrl: auth.backgroundImageUrl,
                initial: initial,
                // "Verified" is the existing condition, not a new definition.
                isVerified: auth.userRole != null,
                onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
                onNotificationsTap: () => Navigator.pushNamed(
                  context,
                  AppConstants.notificationsScreen,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingXL,
                  6,
                  AppConstants.spacingXL,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileIdentityBlock(
                      displayName: auth.userName,
                      username: auth.profileRow?['username'] as String?,
                      userType: auth.userType,
                    ),
                    const SizedBox(height: 18),

                    ProfileStatsRow(
                      stats: profile.stats,
                      isLoading: profile.statsLoading,
                      hasFailed: profile.statsFailed,
                    ).animate().fadeIn(duration: 400.ms, delay: 100.ms),
                    const SizedBox(height: AppConstants.spacingM),

                    ProfileCompletionCard(
                      completion: completion,
                      onTap: () => _editProfile(auth),
                    ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                    const SizedBox(height: AppConstants.spacingM),

                    ProfileActionRow(
                      onEdit: () => _editProfile(auth),
                      onShare: () {
                        final row = auth.profileRow;
                        final userProfile =
                            row != null ? UserProfile.fromMap(row) : null;
                        showDigitalVisitingCard(
                          context,
                          userId: auth.userId,
                          name: auth.userName,
                          companyName: userProfile?.displayTitle,
                          userType: auth.userType,
                          avatarUrl: auth.avatarUrl,
                          city: auth.profileCity,
                          experience: userProfile?.effectiveExperience,
                          rating: profile.stats.averageRating,
                          reviewsCount: profile.stats.reviews,
                          phone: userProfile?.effectivePhone,
                          reraNumber: userProfile?.effectiveRera,
                        );
                      },
                    ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                    const SizedBox(height: 26),

                    const _SectionLabel('Create Content'),
                    const SizedBox(height: 10),
                    CreateContentGrid(
                      onAddProperty: () => Navigator.pushNamed(
                        context,
                        AppConstants.postPropertyScreen,
                      ),
                      onAddArticle: _openArticleEditor,
                      onAddVideo: isInfluencer
                          ? () => Navigator.pushNamed(
                                context,
                                AppConstants.influencerVideoFormScreen,
                              )
                          : null,
                    ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
                    const SizedBox(height: 26),

                    // A builder's content IS their projects.
                    //
                    // The portal makes the same substitution rather than adding
                    // a fourth tab: `PROFILE_TYPE_CONFIG` marks builder as
                    // `content: "projects"` and
                    // `ProfileDashboardShell.tsx:3894-3900` swaps the whole My
                    // Content block for `BuilderProjectsManager`. Properties,
                    // articles and videos are still fetched for a builder there
                    // and then never rendered — which is exactly what this
                    // screen was doing, hence the permanent "No content yet":
                    // a builder's work lives in `builder_projects`, and
                    // `ProfileProvider.properties` only ever reads `properties`.
                    _SectionLabel(isBuilder ? 'My Projects' : 'My Content'),
                    const SizedBox(height: 10),
                    if (isBuilder && auth.userId != null)
                      // Same widget the Builder dashboard's Content tab uses,
                      // with the Edit / Delete / Share actions the portal's
                      // `BuilderProjectsManager` offers. It fetches and handles
                      // its own loading and empty states.
                      MyProjectsSection(userId: auth.userId!)
                    else
                      MyContentSection(
                        properties: profile.properties,
                        articles: profile.articles,
                        videos: profile.videos,
                        showVideosTab: isInfluencer,
                        isLoading: profile.contentLoading,
                        hasFailed: profile.contentFailed,
                        onRetry: profile.refresh,
                        onPropertyTap: _openPropertyDetail,
                        onArticleTap: (article) =>
                            _openArticleEditor(article.id),
                        onVideoTap: (video) => Navigator.pushNamed(
                          context,
                          AppConstants.reelsScreen,
                          arguments: {'reelId': video.id},
                        ),
                        onAddProperty: () => Navigator.pushNamed(
                          context,
                          AppConstants.postPropertyScreen,
                        ),
                        onEditProperty: _openEditProperty,
                        onDeleteProperty: _deleteProperty,
                      ),
                    const SizedBox(height: 26),

                    // Mirrors the portal's IndividualUserActivity — Liked/
                    // Saved tabs reading the same existing user_likes/
                    // saved_properties-backed state PropertyProvider already
                    // persists, so Like/Save actions now surface here too.
                    const _SectionLabel('My Activity'),
                    const SizedBox(height: 10),
                    const MyActivitySection(),
                    const SizedBox(height: 26),

                    const _SectionLabel('Manage'),
                    const SizedBox(height: 10),
                    ManageListSection(
                      onDashboard: _openDashboard,
                      // No standalone "my properties" screen exists; the
                      // role dashboard is where listings are managed, and the
                      // old "Manage Properties → Post Property" destination is
                      // preserved by the Add Property tile above.
                      onMyProperties: _openDashboard,
                      onSaved: () => Navigator.pushNamed(
                        context,
                        AppConstants.shortlistScreen,
                      ),
                      onMore: () => showMoreBottomSheet(context),
                      // Builder-only, preserved from the old Business section.
                      onProjects: isBuilder
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const BuilderDashboardScreen(),
                                ),
                              )
                          : null,
                    ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentIndex: 3),
    );
  }
}

/// Uppercase muted section label, per the prototype.
class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTextStyles.caption.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textHint,
        letterSpacing: 0.6,
      ),
    );
  }
}
