import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:propcid_app/core/constants/app_constants.dart';
import 'package:propcid_app/core/widgets/scale_tap.dart';
import 'package:propcid_app/core/navigation/workspace_destinations.dart';
import 'package:propcid_app/models/network_stats.dart';
import 'package:propcid_app/providers/network_hub_provider.dart';
import 'package:propcid_app/screens/network/network_hub_screen.dart';
import 'package:propcid_app/screens/social/social_hub_screen.dart';
import 'package:propcid_app/screens/stubs/coming_soon_screen.dart';
import 'package:propcid_app/screens/subscription/plan_catalogue.dart';
import 'package:propcid_app/screens/subscription/upgrade_screen.dart';
import 'package:propcid_app/widgets/manage_list_tile.dart';
import 'package:propcid_app/widgets/shared/stat_kpi_card.dart';
import 'package:propcid_app/widgets/shared/toggle_row.dart';

// The promoted surface primitives, reached through both paths, to prove the
// Phase 6 re-export shim resolves to the same classes.
import 'package:propcid_app/screens/dashboard/widgets/dashboard_primitives.dart'
    as legacy;
import 'package:propcid_app/widgets/shared/app_surface_card.dart' as shared;

import 'support/overflow_detector.dart';

Widget _host(Widget child) => MaterialApp(home: child);

void main() {
  group('NetworkStats', () {
    test('starts zeroed', () {
      const stats = NetworkStats.empty;
      expect(stats.totalNetworks, 0);
      expect(stats.activeLeads, 0);
      expect(stats.totalReferrals, 0);
      expect(stats.monthlyCommissions, 0);
    });

    test('formats commissions with Indian digit grouping', () {
      String display(double v) =>
          NetworkStats(monthlyCommissions: v).monthlyCommissionsDisplay;

      expect(display(0), '₹0');
      expect(display(500), '₹500');
      // The design's own example value.
      expect(display(24500), '₹24,500');
      // Above a lakh the grouping switches to pairs, not thousands.
      expect(display(124500), '₹1,24,500');
      expect(display(10000000), '₹1,00,00,000');
    });

    test('rounds fractional amounts and keeps the sign', () {
      expect(
        const NetworkStats(monthlyCommissions: 1499.6)
            .monthlyCommissionsDisplay,
        '₹1,500',
      );
      expect(
        const NetworkStats(monthlyCommissions: -2500)
            .monthlyCommissionsDisplay,
        '-₹2,500',
      );
    });

    test('mirrors React by reporting no referral count', () {
      // React: `const referralsCount = 0; // Temporarily disable this query`.
      expect(const NetworkStats().totalReferrals, 0);
    });
  });

  group('NetworkHubProvider', () {
    test('begins loading with zeroed stats', () {
      final provider = NetworkHubProvider();
      addTearDown(provider.dispose);

      expect(provider.loading, isTrue);
      expect(provider.failed, isFalse);
      expect(provider.stats.totalNetworks, 0);
    });

    test('reports failure instead of zeros when the query cannot run', () async {
      // Supabase is not initialised in a unit test, so the service throws on
      // construction — exactly the path a real query failure takes.
      final provider = NetworkHubProvider();
      addTearDown(provider.dispose);

      await provider.load('user-1', isBuilder: true);

      expect(provider.loading, isFalse);
      expect(provider.failed, isTrue);
      expect(provider.stats.totalNetworks, 0);
    });

    test('notifying after dispose does not throw', () async {
      final provider = NetworkHubProvider();
      provider.dispose();

      // refresh() with no prior load is a no-op and must stay silent.
      await provider.refresh();
    });
  });

  group('Network hub', () {
    testWidgets('renders the design\'s four KPIs and four destinations',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const NetworkHubBody(
            stats: NetworkStats(
              totalNetworks: 3,
              activeLeads: 5,
              monthlyCommissions: 24500,
            ),
            loading: false,
            failed: false,
          ),
        ),
      );

      expect(find.text('Network'), findsOneWidget);
      expect(find.text('Memberships, leads & referrals'), findsOneWidget);

      for (final label in const [
        'Networks Joined',
        'Active Leads',
        'Total Referrals',
        'Monthly Commissions',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      expect(find.text('3'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('₹24,500'), findsOneWidget);

      for (final label in const [
        'My Networks',
        'My Leads',
        'My Referrals',
        'Communication',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      expect(find.text('OVERVIEW'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('Performance Summary'), findsOneWidget);
    });

    testWidgets('drives nav-card subtitles from the live counts',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const NetworkHubBody(
            stats: NetworkStats(totalNetworks: 3, activeLeads: 5),
            loading: false,
            failed: false,
          ),
        ),
      );

      expect(find.text('3 active networks'), findsOneWidget);
      expect(find.text('5 active leads'), findsOneWidget);
    });

    testWidgets('shows a shimmer, not zeros, while loading', (tester) async {
      await tester.pumpWidget(
        _host(
          const NetworkHubBody(
            stats: NetworkStats.empty,
            loading: true,
            failed: false,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(MetricCardGridShimmer), findsOneWidget);
      expect(find.text('Networks Joined'), findsNothing);
      // Subtitles fall back to descriptors rather than "0 active networks".
      expect(find.text('0 active networks'), findsNothing);
      expect(find.text('Builder networks you belong to'), findsOneWidget);
    });

    testWidgets('shows em dashes, not zeros, when the query failed',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const NetworkHubBody(
            stats: NetworkStats.empty,
            loading: false,
            failed: true,
          ),
        ),
      );

      // Four KPI values plus the three Performance Summary pills.
      expect(find.text('—'), findsNWidgets(7));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('never presents the invented performance figures',
        (tester) async {
      await tester.pumpWidget(
        _host(
          const NetworkHubBody(
            stats: NetworkStats.empty,
            loading: false,
            failed: false,
          ),
        ),
      );

      // React hardcodes these three with no query behind them.
      expect(find.text('85%'), findsNothing);
      expect(find.text('2.3 hrs'), findsNothing);
      expect(find.text('4.8/5'), findsNothing);
      // The rows themselves are still present, awaiting a real source.
      expect(find.text('Success Rate'), findsOneWidget);
      expect(find.text('Response Time'), findsOneWidget);
      expect(find.text('Network Rating'), findsOneWidget);
    });

    testWidgets('lays out without overflow on a small screen', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _host(
          // The widest realistic values, to stress the 2×2 grid's cells.
          const NetworkHubBody(
            stats: NetworkStats(
              totalNetworks: 128,
              activeLeads: 4096,
              monthlyCommissions: 12345678,
            ),
            loading: false,
            failed: false,
          ),
        ),
      );

      expect(overflowingBoxes(tester), isEmpty);
    });

    testWidgets('a nav card navigates rather than dead-ending', (tester) async {
      // Phase 6 shipped this hub with every card on the honest placeholder.
      // Phase 9 delivered the four real leaf screens, so the card now pushes a
      // named route. The invariant this test protects is unchanged — a card
      // must always go somewhere — only the destination moved on. Same update
      // as the Social hub's equivalent test after Phase 8.
      final pushed = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: const NetworkHubBody(
            stats: NetworkStats.empty,
            loading: false,
            failed: false,
          ),
          onGenerateRoute: (settings) {
            if (settings.name != null) pushed.add(settings.name!);
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
        ),
      );

      await tester.tap(find.text('My Networks'));
      await tester.pumpAndSettle();

      expect(pushed, contains(AppConstants.myNetworksScreen));
    });
  });

  group('Social hub', () {
    testWidgets('renders the header and all six design destinations',
        (tester) async {
      await tester.pumpWidget(_host(const SocialHubScreen()));

      expect(find.text('Social'), findsOneWidget);
      expect(
        find.text('Connect Facebook & Instagram, publish everywhere'),
        findsOneWidget,
      );

      for (final label in const [
        'Social Accounts',
        'Social Campaigns',
        'Social Leads',
        'Social Preferences',
        'Social Activity',
        'Social Analytics',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }

      // The design's subtitles, verbatim.
      expect(find.text('Facebook & Instagram connection'), findsOneWidget);
      expect(find.text('Reach & post performance'), findsOneWidget);

      expect(find.byType(ManageListTile), findsNWidgets(6));
    });

    testWidgets('a card navigates rather than dead-ending', (tester) async {
      // Phase 6 shipped this hub with every card on the honest placeholder.
      // Phase 8 delivered the six real leaf screens, so the card now pushes a
      // named route. The invariant this test protects is unchanged — a card
      // must always go somewhere — only the destination moved on.
      final pushed = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          home: const SocialHubScreen(),
          onGenerateRoute: (settings) {
            if (settings.name != null) pushed.add(settings.name!);
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
        ),
      );

      await tester.tap(find.text('Social Campaigns'));
      await tester.pumpAndSettle();

      expect(pushed, contains(AppConstants.socialCampaignsScreen));
    });

    testWidgets('lays out without overflow on a small screen', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const SocialHubScreen()));
      expect(overflowingBoxes(tester), isEmpty);
    });
  });

  group('Upgrade screen', () {
    testWidgets('renders the four plans at monthly pricing', (tester) async {
      await tester.pumpWidget(_host(const UpgradeScreen()));

      expect(find.text('Upgrade Your Plan'), findsOneWidget);
      expect(
        find.text('Unlock more features and grow faster on PropCid'),
        findsOneWidget,
      );

      for (final name in const [
        'Free',
        'Owner Plus',
        'Owner Pro',
        'Concierge',
      ]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }

      expect(find.text('₹0'), findsOneWidget);
      expect(find.text('₹9'), findsOneWidget);
      expect(find.text('₹19'), findsOneWidget);
      expect(find.text('₹49'), findsOneWidget);
      expect(find.text('/month'), findsNWidgets(4));

      // Monthly shows no annual note and no saving pill.
      expect(find.textContaining('Billed annually'), findsNothing);
      expect(find.text(PlanCatalogue.yearlySavingLabel), findsNothing);
    });

    testWidgets('switching to yearly repricing every card', (tester) async {
      await tester.pumpWidget(_host(const UpgradeScreen()));

      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();

      expect(find.text('₹7'), findsOneWidget);
      expect(find.text('₹15'), findsOneWidget);
      expect(find.text('₹39'), findsOneWidget);
      expect(find.text('/year'), findsNWidgets(4));

      expect(find.text(PlanCatalogue.yearlySavingLabel), findsOneWidget);
      // Free has no annual charge, so only the three paid plans get the note.
      expect(find.textContaining('Billed annually'), findsNWidgets(3));
      expect(find.text('Billed annually (₹84/year)'), findsOneWidget);
    });

    testWidgets('tapping the Monthly/Yearly labels also switches',
        (tester) async {
      await tester.pumpWidget(_host(const UpgradeScreen()));

      await tester.tap(find.text('Yearly'));
      await tester.pumpAndSettle();
      expect(find.text('/year'), findsNWidgets(4));

      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      expect(find.text('/month'), findsNWidgets(4));
    });

    testWidgets('a paid CTA routes to the placeholder; Free stays a label',
        (tester) async {
      await tester.pumpWidget(_host(const UpgradeScreen()));

      // The second plan card sits below the test viewport, so scroll its CTA
      // into view before tapping — otherwise the tap lands outside the view.
      await tester.ensureVisible(find.text('Choose Owner Plus'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose Owner Plus'));
      await tester.pumpAndSettle();
      expect(find.byType(ComingSoonScreen), findsOneWidget);

      // Back, then confirm the Free card's CTA is inert. Asserted structurally
      // rather than by tapping: the design gives the current plan no onClick,
      // so it has no ScaleTap wrapper at all and a tap would simply hit
      // nothing.
      Navigator.of(tester.element(find.byType(ComingSoonScreen))).pop();
      await tester.pumpAndSettle();

      expect(
        find.ancestor(
          of: find.text('Free plan'),
          matching: find.byType(ScaleTap),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('Choose Owner Plus'),
          matching: find.byType(ScaleTap),
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not claim a current plan without reading billing state',
        (tester) async {
      await tester.pumpWidget(_host(const UpgradeScreen()));

      // Nothing in this phase queries the account's subscription, so the
      // design's "Current Plan" badge must not be asserted.
      expect(find.text('Current Plan'), findsNothing);
      // The one badge that is safe to show is the static recommendation.
      expect(find.text('Most Popular'), findsOneWidget);
    });

    testWidgets('lays out without overflow on a small screen', (tester) async {
      tester.view.physicalSize = const Size(320 * 3, 568 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_host(const UpgradeScreen()));
      expect(overflowingBoxes(tester), isEmpty);
    });
  });

  group('AppToggle geometry', () {
    testWidgets('default settings-row size is unchanged by Phase 6',
        (tester) async {
      await tester.pumpWidget(
        _host(Center(child: AppToggle(value: false, onChanged: (_) {}))),
      );

      final track = tester.getSize(
        find.descendant(
          of: find.byType(AppToggle),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(track.width, 40);
      expect(track.height, 24);
    });

    testWidgets('accepts the design\'s larger billing-period size',
        (tester) async {
      await tester.pumpWidget(
        _host(
          Center(
            child: AppToggle(
              value: false,
              onChanged: (_) {},
              trackWidth: 44,
              trackHeight: 26,
              knobSize: 22,
            ),
          ),
        ),
      );

      final track = tester.getSize(
        find.descendant(
          of: find.byType(AppToggle),
          matching: find.byType(AnimatedContainer),
        ),
      );
      expect(track.width, 44);
      expect(track.height, 26);
    });
  });

  group('Phase 6 promotion and routing', () {
    test('the surface primitives are the same classes through both paths', () {
      expect(shared.DashboardCard, legacy.DashboardCard);
      expect(shared.DashboardCardTitle, legacy.DashboardCardTitle);
      expect(shared.DashboardSectionLabel, legacy.DashboardSectionLabel);
    });

    test('the promoted shimmer reuses the real grid geometry', () {
      // Guards the invariant the dashboards relied on: placeholder and real
      // grid must share one delegate so nothing shifts when values land.
      expect(MetricCardGrid.delegate.mainAxisExtent, MetricCardGrid.cardHeight);
      expect(MetricCardGrid.delegate.crossAxisCount, 2);
    });

    test('the three hub routes are distinct named routes', () {
      final routes = {
        AppConstants.networkScreen,
        AppConstants.socialScreen,
        AppConstants.upgradeScreen,
      };
      expect(routes.length, 3);
      expect(AppConstants.networkScreen, '/network');
      expect(AppConstants.socialScreen, '/social');
      expect(AppConstants.upgradeScreen, '/upgrade');
    });

    testWidgets('destinations push the hub routes, not the placeholder',
        (tester) async {
      final pushed = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          onGenerateRoute: (settings) {
            if (settings.name != null) pushed.add(settings.name!);
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const SizedBox.shrink(),
            );
          },
        ),
      );

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      WorkspaceDestinations.network(navigator);
      WorkspaceDestinations.social(navigator);
      WorkspaceDestinations.upgrade(navigator);
      await tester.pumpAndSettle();

      expect(
        pushed,
        containsAll(<String>[
          AppConstants.networkScreen,
          AppConstants.socialScreen,
          AppConstants.upgradeScreen,
        ]),
      );
    });
  });
}
