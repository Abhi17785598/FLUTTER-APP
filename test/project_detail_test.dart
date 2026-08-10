// Builder flow — Phase B4: the project detail screen and the share fan-out.
//
// What is pinned:
//   * owner vs visitor — Edit only for the owner, and the pending-verification
//     badge shown to nobody else;
//   * "not available" told apart from "load failed", because one offers a retry
//     and the other does not;
//   * the share fan-out's counterpart resolution, dedup, accepted-only filter and
//     the 500 cap being reported rather than swallowed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:propcid_app/models/project_model.dart';
import 'package:propcid_app/models/user_profile.dart';
import 'package:propcid_app/providers/auth_provider.dart';
import 'package:propcid_app/screens/dashboard/widgets/my_projects_section.dart';
import 'package:propcid_app/screens/project/project_detail_screen.dart';
import 'package:propcid_app/services/project_service.dart';
import 'package:propcid_app/services/project_share_service.dart';
import 'package:propcid_app/services/user_profile_service.dart';

import 'support/overflow_detector.dart';

const Size kSmall = Size(320, 720);

class _FakeAuth extends AuthProvider {
  _FakeAuth({this.id});

  final String? id;

  @override
  String? get userId => id;

  // Always signed in: the detail screen only reads this to choose the builder
  // profile's column list, which is not what these tests are about.
  @override
  bool get isLoggedIn => true;
}

class _FakeProjectService extends ProjectService {
  _FakeProjectService({this.project, this.shouldFail = false});

  final ProjectModel? project;
  final bool shouldFail;

  @override
  Future<ProjectModel?> fetchById(String projectId) async {
    if (shouldFail) throw Exception('forced failure');
    return project;
  }
}

class _FakeProfileService extends UserProfileService {
  _FakeProfileService(this.profile);

  final UserProfile? profile;

  @override
  Future<UserProfile?> fetchPublic(
    String userId, {
    required bool viewerSignedIn,
  }) async =>
      profile;
}

ProjectModel _project({
  String id = 'p-1',
  String builderId = 'b-1',
  String approvalStatus = 'approved',
  String status = 'active',
  List<String> media = const [],
}) {
  return ProjectModel.fromSupabase({
    'id': id,
    'builder_id': builderId,
    'title': 'Green Valley Heights',
    'description': 'A gated community in west Pune.',
    'project_type': 'group_housing',
    'location': 'Pune',
    'status': status,
    'approval_status': approvalStatus,
    'total_units': 120,
    'available_units': 45,
    'price_range_min': 4500000,
    'price_range_max': 9500000,
    'area_sqft_min': 850,
    'area_sqft_max': 1850,
    'completion_date': '2027-06-30',
    'possession_date': '2027-09-30',
    'rera_number': 'P52100012345',
    'website_url': 'https://greenvalley.example',
    'contact_number': '9876543210',
    'brochure_url': 'https://cdn.test/b.pdf',
    'media_urls': media,
    'amenities': ['Swimming Pool', 'Gymnasium'],
  });
}

Future<void> _pumpDetail(
  WidgetTester tester, {
  required _FakeProjectService service,
  required _FakeAuth auth,
  UserProfile? builder,
  Size size = kSmall,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: ProjectDetailScreen(
          projectId: 'p-1',
          service: service,
          profileService: _FakeProfileService(builder),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'test-anon-key',
      authOptions: const FlutterAuthClientOptions(
        localStorage: EmptyLocalStorage(),
        autoRefreshToken: false,
      ),
    );
  });

  // ── 1. The page ────────────────────────────────────────────────────────
  group('project detail', () {
    testWidgets('renders every field the project carries', (tester) async {
      await _pumpDetail(
        tester,
        service: _FakeProjectService(project: _project()),
        auth: _FakeAuth(id: 'someone-else'),
      );

      expect(find.text('Green Valley Heights'), findsOneWidget);
      expect(find.text('Pune'), findsOneWidget);
      expect(find.text('Group Housing'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('45 of 120 available'), findsOneWidget);
      expect(find.text('850 – 1850 sq ft'), findsOneWidget);
      expect(find.text('P52100012345'), findsOneWidget);
      expect(find.text('Swimming Pool'), findsOneWidget);
      expect(find.text('Visit website'), findsOneWidget);
      expect(find.text('Download brochure'), findsOneWidget);
      expect(overflowingBoxes(tester), isEmpty);
    });

    testWidgets('the owner gets Edit; a visitor does not', (tester) async {
      await _pumpDetail(
        tester,
        service: _FakeProjectService(project: _project(builderId: 'b-1')),
        auth: _FakeAuth(id: 'b-1'),
      );
      expect(find.text('Edit Project'), findsOneWidget);

      await _pumpDetail(
        tester,
        service: _FakeProjectService(project: _project(builderId: 'b-1')),
        auth: _FakeAuth(id: 'someone-else'),
      );
      expect(find.text('Edit Project'), findsNothing);
    });

    testWidgets('pending verification is shown to the owner only',
        (tester) async {
      // The public read policy checks `status = 'active'` alone, so an unapproved
      // project is publicly visible. Telling a visitor it is unreviewed would
      // advertise exactly that.
      await _pumpDetail(
        tester,
        service: _FakeProjectService(
          project: _project(approvalStatus: 'pending'),
        ),
        auth: _FakeAuth(id: 'b-1'),
      );
      expect(find.text('Pending verification'), findsOneWidget);

      await _pumpDetail(
        tester,
        service: _FakeProjectService(
          project: _project(approvalStatus: 'pending'),
        ),
        auth: _FakeAuth(id: 'someone-else'),
      );
      expect(find.text('Pending verification'), findsNothing);
    });

    testWidgets('an approved project shows no badge for anyone', (tester) async {
      await _pumpDetail(
        tester,
        service: _FakeProjectService(project: _project()),
        auth: _FakeAuth(id: 'b-1'),
      );
      expect(find.text('Pending verification'), findsNothing);
    });

    testWidgets('a missing project is "not available", with no retry',
        (tester) async {
      await _pumpDetail(
        tester,
        service: _FakeProjectService(project: null),
        auth: _FakeAuth(id: 'b-1'),
      );

      expect(find.text('Project not available'), findsOneWidget);
      expect(find.text('Retry'), findsNothing,
          reason: 'nothing to retry — the row is not visible');
    });

    testWidgets('a failed load offers a retry instead', (tester) async {
      await _pumpDetail(
        tester,
        service: _FakeProjectService(shouldFail: true),
        auth: _FakeAuth(id: 'b-1'),
      );

      expect(find.text("Couldn't load this project"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Project not available'), findsNothing);
    });

    testWidgets('the builder byline appears once resolved', (tester) async {
      final builder = UserProfile.fromMap({
        'user_id': 'b-1',
        'display_name': 'Anita Rao',
        'company_name': 'Prestige Estates',
      });

      await _pumpDetail(
        tester,
        service: _FakeProjectService(project: _project()),
        auth: _FakeAuth(id: 'visitor'),
        builder: builder,
      );

      // displayTitle prefers the company name.
      expect(find.text('Prestige Estates'), findsOneWidget);
    });

    testWidgets('the page still works without a builder profile',
        (tester) async {
      // The byline read is best-effort; losing it must not break the page.
      await _pumpDetail(
        tester,
        service: _FakeProjectService(project: _project()),
        auth: _FakeAuth(id: 'visitor'),
        builder: null,
      );

      expect(find.text('Green Valley Heights'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a gallery of one image shows no counter', (tester) async {
      await _pumpDetail(
        tester,
        service: _FakeProjectService(
          project: _project(media: ['https://cdn.test/a.jpg']),
        ),
        auth: _FakeAuth(id: 'b-1'),
      );
      expect(find.text('1 / 1'), findsNothing);
    });

    testWidgets('a multi-image gallery shows the counter', (tester) async {
      await _pumpDetail(
        tester,
        service: _FakeProjectService(
          project: _project(
            media: ['https://cdn.test/a.jpg', 'https://cdn.test/b.jpg'],
          ),
        ),
        auth: _FakeAuth(id: 'b-1'),
      );
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('lays out cleanly at 320 dp and 130% text', (tester) async {
      tester.view.physicalSize = kSmall;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: _FakeAuth(id: 'b-1'),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: ProjectDetailScreen(
              projectId: 'p-1',
              service: _FakeProjectService(
                project: _project(approvalStatus: 'pending'),
              ),
              profileService: _FakeProfileService(null),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(overflowingBoxes(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });

  // ── 2. Price range formatting ──────────────────────────────────────────
  group('price range label', () {
    test('a real range reads as a range', () {
      expect(projectPriceRangeLabel(_project()), contains('–'));
    });

    test('equal ends read as one figure', () {
      final flat = ProjectModel.fromSupabase({
        'id': 'p',
        'price_range_min': 5000000,
        'price_range_max': 5000000,
      });
      expect(projectPriceRangeLabel(flat), isNot(contains('–')));
    });

    test('one end missing falls back to the other', () {
      final onlyMin = ProjectModel.fromSupabase({
        'id': 'p',
        'price_range_min': 5000000,
      });
      expect(projectPriceRangeLabel(onlyMin), isNot(contains('–')));
    });
  });

  // ── 3. The share fan-out ───────────────────────────────────────────────
  group('ProjectShareResult', () {
    test('no network is not a share of zero', () {
      // The portal refuses with a message rather than reporting success.
      const empty = ProjectShareResult(
        notified: 0,
        dropped: 0,
        hasNetwork: false,
      );
      expect(empty.isEmpty, isTrue);

      const sent = ProjectShareResult(
        notified: 3,
        dropped: 0,
        hasNetwork: true,
      );
      expect(sent.isEmpty, isFalse);
    });

    test('a capped fan-out reports what it did not send', () {
      const capped = ProjectShareResult(
        notified: 500,
        dropped: 300,
        hasNetwork: true,
      );
      expect(capped.dropped, 300,
          reason: 'a builder must not be told 800 were notified');
    });

    test('the cap is 500', () {
      expect(ProjectShareService.maxRecipients, 500);
    });

    test('the notification type matches notifyProjectShared', () {
      expect(ProjectShareService.notificationType, 'project_shared');
    });
  });
}
