import 'package:flutter/material.dart';
import 'app_navigator.dart';
import 'core/constants/app_constants.dart';
import 'core/navigation/manage_dashboard_dispatcher.dart';
import 'core/navigation/pending_invitation_gate.dart';
import 'core/theme/app_theme.dart';
import 'core/animations/page_transitions.dart';
import 'voice_agent/widgets/floating_ai_orb.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/search/search_results_screen.dart';
import 'screens/search/people_search_screen.dart';
import 'models/project_model.dart';
import 'core/navigation/post_property_route_gate.dart';
import 'screens/project/project_detail_screen.dart';
import 'services/property_service.dart' show PropertyEditBundle;
import 'screens/shortlist/shortlist_screen.dart';
import 'screens/filters/filters_screen.dart';
import 'screens/property_detail/property_detail_screen.dart';
import 'screens/profile/account_deletion_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/profile/profile_views_screen.dart';
import 'screens/profile/public_profile_screen.dart';
import 'screens/visits/visits_screen.dart';
import 'screens/reels/reels_screen.dart';
import 'screens/feed/feed_screen.dart';
// ── NEW ──────────────────────────────────────
import 'screens/notifications/notifications_screen.dart';
import 'screens/emi_calculator/emi_calculator_screen.dart';
import 'screens/compare/compare_properties_screen.dart';
import 'screens/payment/payment_method_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/articles/article_editor_screen.dart';
import 'screens/gallery/gallery_viewer_screen.dart';
import 'screens/messaging/messages_list_screen.dart';
import 'screens/network/my_leads_screen.dart';
import 'screens/network/my_networks_screen.dart';
import 'screens/network/my_referrals_screen.dart';
import 'screens/network/network_communication_screen.dart';
import 'screens/network/network_hub_screen.dart';
import 'screens/social/social_accounts_screen.dart';
import 'screens/social/social_activity_screen.dart';
import 'screens/social/social_analytics_screen.dart';
import 'screens/social/social_campaigns_screen.dart';
import 'screens/social/social_hub_screen.dart';
import 'screens/social/social_leads_screen.dart';
import 'screens/social/social_preferences_screen.dart';
import 'screens/subscription/subscription_billing_screen.dart';
import 'screens/subscription/upgrade_screen.dart';
import 'screens/profile_completion/builder_registration/builder_registration_screen.dart';
import 'screens/profile_completion/broker_registration/broker_registration_screen.dart';
import 'screens/profile_completion/influencer_registration/influencer_registration_screen.dart';
import 'screens/role_home_router.dart';
import 'screens/team/pending_invitation_screen.dart';
import 'screens/team/team_workspace_screen.dart';
// ─────────────────────────────────────────────

class PropertyApp extends StatelessWidget {
  const PropertyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Property App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      navigatorKey: appNavigatorKey,
      home: const SplashScreen(),
      // Inject the draggable AI orb overlay on every screen, and — wrapped
      // around that, so it sees every screen the same way `TeamInviteGate`
      // sees every route outside `<Routes>` — the silent pending-invitation
      // redirect.
      builder: (context, child) {
        return PendingInvitationGate(
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const FloatingAiOrb(),
            ],
          ),
        );
      },
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return PremiumPageRoute(
              builder: (context) => const RoleHomeRouter(),
            );

          case '/search':
            final searchArgs = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              builder: (context) => SearchScreen(
                autoStartVoice: searchArgs?['autoStartVoice'] as bool? ?? false,
              ),
            );
          case '/search-results':
            return PremiumPageRoute(
              builder: (context) => const SearchResultsScreen(),
            );
          case AppConstants.addProjectScreen:
            // The builder project wizard. `project` pre-fills it for an edit;
            // absent, it opens blank for a new project.
            //
            // Gated as the mirror of /post-property: the voice agent's route
            // index resolves "create a project" here for any authenticated user,
            // AddProjectScreen has no role check of its own, and RLS would not
            // refuse a broker inserting their own builder_id. See
            // AddProjectRouteGate.
            final projectArgs = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => AddProjectRouteGate(
                editingProject: projectArgs?['project'] as ProjectModel?,
              ),
            );
          case AppConstants.projectDetailScreen:
            // One project. Ungated: the public read policy is
            // `status = 'active'`, and fetchById returns null for anything the
            // caller may not see, which renders "Project not available".
            final detailArgs = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => ProjectDetailScreen(
                projectId: detailArgs?['projectId'] as String? ?? '',
              ),
            );
          case AppConstants.feedScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const FeedScreen(),
            );
          case AppConstants.influencerVideoFormScreen:
            // The influencer video form, in create mode, behind the same kind of
            // role gate the other two wizards have. See
            // InfluencerVideoRouteGate: RLS would refuse a wrong-role insert, but
            // only after the video had already been uploaded.
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const InfluencerVideoRouteGate(),
            );
          case AppConstants.peopleSearchScreen:
            // People Search. The query is seeded from the Search entry screen so
            // the first page is already loading when this opens; a missing
            // argument simply lands on the "Find people" prompt.
            final peopleArgs = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => PeopleSearchScreen(
                initialQuery: peopleArgs?['query'] as String? ?? '',
              ),
            );
          case '/shortlist':
            return PremiumPageRoute(
              builder: (context) => const ShortlistScreen(),
            );
          case '/profile':
            // `settings` is forwarded here (and only here, for now) so the
            // bottom bar can identify the Profile route by name and reset to
            // it on a re-tap. Other routes keep their existing behaviour —
            // see blueprint §2.1 / §16.1.
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const ProfileScreen(),
            );
          case AppConstants.profileViewsScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const ProfileViewsScreen(),
            );
          case AppConstants.accountDeletionScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const AccountDeletionScreen(),
            );
          case AppConstants.editProfileScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const EditProfileScreen(),
            );
          case AppConstants.publicProfileScreen:
            // Another user's profile. A missing/blank userId still resolves, and
            // the screen shows its "Profile not available" state rather than
            // falling through to Home, which would look like a navigation bug.
            final profileArgs = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => PublicProfileScreen(
                userId: profileArgs?['userId'] as String? ?? '',
                avatarHeroTag: profileArgs?['avatarHeroTag'] as String?,
              ),
            );
          case AppConstants.articleEditorScreen:
            final articleArgs = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => ArticleEditorScreen(
                articleId: articleArgs?['articleId'] as String?,
              ),
            );

          case AppConstants.messagesScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const MessagesListScreen(),
            );

          // Thin role dispatcher — the Workspace Drawer, the More sheet and
          // the Profile screen all push this one route instead of each
          // repeating the role switch. See blueprint §2.4.
          case AppConstants.manageDashboardScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const ManageDashboardDispatcher(),
            );

          // Mobile mirror of the portal's `/accept-invite`. Pushed only by
          // PendingInvitationGate for now — no deep link reaches this yet.
          case AppConstants.pendingInvitationScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const PendingInvitationScreen(),
            );

          // Mobile mirror of the portal's `/team-workspace`. Reached via
          // ManageDashboardDispatcher's `team_member` case, the Workspace
          // Drawer / More sheet's additive destination, or the
          // pending-invitation screen after a successful acceptance.
          case AppConstants.teamWorkspaceScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const TeamWorkspaceScreen(),
            );

          // Phase 6 hubs. Named routes rather than direct pushes, so the drawer
          // and the More sheet reach them exactly the way they already reach
          // Messages and the dashboard.
          case AppConstants.networkScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const NetworkHubScreen(),
            );

          case AppConstants.socialScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const SocialHubScreen(),
            );

          case AppConstants.upgradeScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const UpgradeScreen(),
            );

          case AppConstants.subscriptionBillingScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const SubscriptionBillingScreen(),
            );

          // Phase 8 — Social leaf screens.
          case AppConstants.socialAccountsScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const SocialAccountsScreen(),
            );

          case AppConstants.socialCampaignsScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const SocialCampaignsScreen(),
            );

          case AppConstants.socialLeadsScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const SocialLeadsScreen(),
            );

          case AppConstants.socialPreferencesScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const SocialPreferencesScreen(),
            );

          case AppConstants.socialActivityScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const SocialActivityScreen(),
            );

          case AppConstants.socialAnalyticsScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const SocialAnalyticsScreen(),
            );

          // Phase 9 — Network leaf screens.
          case AppConstants.myNetworksScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const MyNetworksScreen(),
            );

          case AppConstants.myLeadsScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const MyLeadsScreen(),
            );

          case AppConstants.myReferralsScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const MyReferralsScreen(),
            );

          case AppConstants.networkCommunicationScreen:
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => const NetworkCommunicationScreen(),
            );

          case '/visits':
            return PremiumPageRoute(builder: (context) => const VisitsScreen());
          case '/reels':
            return PremiumPageRoute(builder: (context) => const ReelsScreen());
          case '/post-property':
            // Role-gated: a builder publishes projects, not listings, and this
            // route is where every one of the eleven callers converges — the
            // shared "+" FAB, the Home quick action, both Profile tiles and the
            // voice agent included. Edit mode passes straight through.
            // See PostPropertyRouteGate.
            final listingArgs = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              settings: settings,
              builder: (context) => PostPropertyRouteGate(
                editPropertyId: listingArgs?['editPropertyId'] as String?,
                editBundle:
                    listingArgs?['editBundle'] as PropertyEditBundle?,
              ),
            );

          case '/filters':
            return PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const FiltersScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, 1),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            ),
                          ),
                      child: child,
                    );
                  },
              transitionDuration: const Duration(milliseconds: 300),
            );
          case '/property-detail':
            final args = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              builder: (context) =>
                  PropertyDetailScreen(propertyId: args?['propertyId'] ?? ''),
            );
          case '/gallery-viewer':
            final args = settings.arguments as Map<String, dynamic>;

            return PremiumPageRoute(
              builder: (context) => GalleryViewerScreen(
                images: List<String>.from(args['images']),
                initialIndex: args['index'] ?? 0,
              ),
            );
          case '/onboarding':
            return PremiumPageRoute(
              builder: (context) => const OnboardingScreen(),
            );
          case '/auth':
            return PremiumPageRoute(builder: (context) => const AuthScreen());
          case '/auth-otp':
            final otpArgs = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              builder: (context) => OtpScreen(
                phone: otpArgs?['phone'] as String? ?? '',
                name: otpArgs?['name'] as String?,
              ),
            );
          case '/reset-password':
            final resetArgs = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              builder: (context) => ResetPasswordScreen(
                tokenHash: resetArgs?['tokenHash'] as String?,
              ),
            );

          // ── PROFILE COMPLETION ROUTES ─────────────
          case '/builder-profile':
            return PremiumPageRoute(
              builder: (context) => const BuilderRegistrationScreen(),
            );
          case '/broker-profile':
            return PremiumPageRoute(
              builder: (context) => const BrokerRegistrationScreen(),
            );
          case '/influencer-profile':
            return PremiumPageRoute(
              builder: (context) => const InfluencerRegistrationScreen(),
            );
          // ─────────────────────────────────────────

          // ── NEW ROUTES ───────────────────────────
          case '/notifications':
            return PremiumPageRoute(
              builder: (context) => const NotificationsScreen(),
            );
          case '/emi-calculator':
            final args = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              builder: (context) => EmiCalculatorScreen(
                initialLoanAmount: args?['loanAmount'] as double?,
              ),
            );
          case '/compare-properties':
            final args = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              builder: (context) => ComparePropertiesScreen(
                propertyIds: (args?['propertyIds'] as List<String>?) ?? [],
              ),
            );
          // ─────────────────────────────────────────

          case '/payment-method':
            final args = settings.arguments as Map<String, dynamic>?;
            return PremiumPageRoute(
              builder: (context) => PaymentMethodScreen(
                amountLabel: args?['amountLabel'] as String?,
                title: (args?['title'] as String?) ?? 'Payment Method',
              ),
            );

          default:
            return MaterialPageRoute(builder: (_) => const HomeScreen());
        }
      },
    );
  }
}
