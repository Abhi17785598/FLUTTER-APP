import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_navigator.dart';
import 'core/theme/app_theme.dart';
import 'core/animations/page_transitions.dart';
import 'providers/auth_provider.dart';
import 'voice_agent/widgets/voice_agent_button.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/search/search_results_screen.dart';
import 'screens/shortlist/shortlist_screen.dart';
import 'screens/filters/filters_screen.dart';
import 'screens/property_detail/property_detail_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/visits/visits_screen.dart';
import 'screens/reels/reels_onboarding_screen.dart';
import 'screens/reels/reels_screen.dart';
import 'screens/post_property/post_property_screen.dart';
// ── NEW ──────────────────────────────────────
import 'screens/notifications/notifications_screen.dart';
import 'screens/emi_calculator/emi_calculator_screen.dart';
import 'screens/compare/compare_properties_screen.dart';
import 'screens/payment/payment_method_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/gallery/gallery_viewer_screen.dart';
import 'screens/profile_completion/builder_profile_screen.dart';
import 'screens/profile_completion/broker_profile_screen.dart';
import 'screens/profile_completion/influencer_profile_screen.dart';
import 'screens/profile_completion/builder_registration/builder_registration_screen.dart';
import 'screens/profile_completion/broker_registration/broker_registration_screen.dart';
import 'screens/profile_completion/influencer_registration/influencer_registration_screen.dart';
import 'screens/role_home_router.dart';
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
      // Inject VoiceAgentButton overlay on every screen.
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const Positioned(
              bottom: 80,
              right: 16,
              child: VoiceAgentButton(),
            ),
          ],
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
          case '/shortlist':
            return PremiumPageRoute(
              builder: (context) => const ShortlistScreen(),
            );
          case '/profile':
            return PremiumPageRoute(
              builder: (context) => const ProfileScreen(),
            );
          case '/visits':
            return PremiumPageRoute(
              builder: (context) => const VisitsScreen(),
            );
          case '/reels':
  return PremiumPageRoute(
    builder: (context) => const ReelsScreen(),
  );
          case '/post-property':
            return PremiumPageRoute(
              builder: (context) => const PostPropertyScreen(),
            );
            
          case '/filters':
            return PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const FiltersScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                  )),
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

  final args =
      settings.arguments as Map<String, dynamic>;

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
            return PremiumPageRoute(
              builder: (context) => const AuthScreen(),
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
                propertyIds:
                    (args?['propertyIds'] as List<String>?) ?? [],
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