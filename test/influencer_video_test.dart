// Spec E — influencer video CRUD.
//
// The portal references are `InfluencerVideoModal.tsx` (the form and both writes)
// and `InfluencerContentManager.tsx` (the library and its delete). What is pinned:
//
//   * the `video_type` vocabulary, which is the table's only CHECK constraint —
//     getting it wrong is a 23514, not a UI nit;
//   * `approval_status: 'pending'` on create AND edit, and `status` on neither;
//   * hashtag parsing, including the two things the portal does not do (no dedupe,
//     no length cap) so a future "improvement" cannot silently diverge;
//   * the storage object key, which the live bucket policy constrains and the
//     portal's own path violates;
//   * the 50 MB gate, which is the bucket's real limit and not the portal's
//     200 MB constant;
//   * soft delete returning false meaning "nothing was removed", which must not
//     look like success.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:propcid_app/core/constants/influencer_video_options.dart';
import 'package:propcid_app/models/influencer_video_model.dart';
import 'package:propcid_app/providers/auth_provider.dart';
import 'package:propcid_app/screens/dashboard/widgets/my_videos_section.dart';
import 'package:propcid_app/services/influencer_media_service.dart';
import 'package:propcid_app/services/influencer_video_service.dart';

import 'support/overflow_detector.dart';

const Size kSmall = Size(320, 720);

InfluencerVideoModel _video({
  String id = 'v-1',
  String title = 'Bandra 3BHK walkthrough',
  String videoType = 'property_listing',
  String status = 'active',
  String approvalStatus = 'approved',
  String? thumbnailUrl = 'https://cdn.test/t.jpg',
  List<String> hashtags = const ['pune', '3bhk'],
  int views = 1200,
  int likes = 84,
}) =>
    InfluencerVideoModel.fromSupabase({
      'id': id,
      'user_id': 'u-1',
      'title': title,
      'description': 'A quick tour.',
      'video_url': 'https://cdn.test/v.mp4',
      'thumbnail_url': thumbnailUrl,
      'video_type': videoType,
      'views': views,
      'likes': likes,
      'hashtags': hashtags,
      'status': status,
      'approval_status': approvalStatus,
      'created_at': '2026-05-01T10:00:00Z',
    });

class _FakeAuth extends AuthProvider {
  static const String id = 'u-1';

  @override
  String? get userId => id;

  @override
  bool get isLoggedIn => true;
}

/// Records every call and replays scripted results.
class _FakeVideoService extends InfluencerVideoService {
  _FakeVideoService({this.rows = const [], this.softDeleteResult = true});

  final List<InfluencerVideoModel> rows;

  /// What `soft_delete_content` returns — false is "RLS matched nothing".
  bool softDeleteResult;

  bool listShouldFail = false;
  bool deleteShouldThrow = false;

  final List<String> softDeletes = [];
  final List<InfluencerVideoDraft> creates = [];
  final List<({String id, InfluencerVideoDraft draft})> updates = [];

  /// When set, `softDelete` blocks on this instead of returning.
  Completer<bool>? gate;

  @override
  Future<List<InfluencerVideoModel>> listMine(String userId) async {
    if (listShouldFail) throw Exception('forced failure');
    return rows;
  }

  @override
  Future<bool> softDelete(String videoId) async {
    softDeletes.add(videoId);
    if (deleteShouldThrow) throw Exception('forced failure');
    final pending = gate;
    if (pending != null) {
      gate = null;
      return pending.future;
    }
    return softDeleteResult;
  }

  @override
  Future<String> create(InfluencerVideoDraft draft, String userId) async {
    creates.add(draft);
    return 'new-id';
  }

  @override
  Future<void> update(String videoId, InfluencerVideoDraft draft) async {
    updates.add((id: videoId, draft: draft));
  }
}

Future<void> _pumpSection(
  WidgetTester tester,
  _FakeVideoService service, {
  Size size = kSmall,
  double textScale = 1.0,
  void Function(int)? onCountChanged,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: _FakeAuth(),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MyVideosSection(
              userId: 'u-1',
              service: service,
              onCountChanged: onCountChanged,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Both services resolve Supabase.instance.client in their constructors, and
    // the fakes subclass them. Loopback URL, no refresh — nothing hits a network.
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

  // ── 1. The vocabulary ───────────────────────────────────────────────────
  group('video type vocabulary', () {
    test('the three CHECK values, in the modal order', () {
      // 20250828001551:14 constrains the column to exactly these; the modal's
      // SelectItems (InfluencerVideoModal.tsx:47-50) are in this order.
      expect(
        kInfluencerVideoTypes.map((t) => t.id).toList(),
        ['property_listing', 'property_news', 'property_education'],
      );
    });

    test('each carries the portal\'s own title and description', () {
      expect(kInfluencerVideoTypes[0].title, 'Property Listing Video');
      expect(kInfluencerVideoTypes[0].description, 'Showcase a specific property');
      expect(kInfluencerVideoTypes[2].title, 'Property Education');
    });

    test('anything outside the CHECK is refused', () {
      expect(isValidInfluencerVideoType('property_listing'), isTrue);
      expect(isValidInfluencerVideoType('property_vlog'), isFalse);
      expect(isValidInfluencerVideoType(''), isFalse);
      expect(isValidInfluencerVideoType(null), isFalse);
    });

    test('a stored type reads as a sentence', () {
      expect(influencerVideoTypeLabel('property_news'), 'Property News');
      // An unknown value still reads, rather than showing a raw enum.
      expect(influencerVideoTypeLabel('market_update'), 'Market Update');
      expect(influencerVideoTypeLabel(null), 'Video');
    });

    test('approval labels match getApprovalBadge', () {
      expect(influencerApprovalLabel('approved'), 'Approved');
      expect(influencerApprovalLabel('rejected'), 'Rejected');
      // NULL on every row written before 20251213104811 added the column.
      expect(influencerApprovalLabel(null), 'Pending Review');
      expect(influencerApprovalLabel('pending'), 'Pending Review');
    });

    test('status labels cover the column CHECK', () {
      expect(influencerVideoStatusLabel('active'), 'Active');
      expect(influencerVideoStatusLabel('inactive'), 'Inactive');
      expect(influencerVideoStatusLabel('pending'), 'Pending');
    });
  });

  // ── 2. Hashtags ─────────────────────────────────────────────────────────
  group('hashtag parsing', () {
    test('splits, trims, lowercases and strips one leading hash', () {
      // InfluencerVideoModal.tsx:154-158, step for step.
      expect(
        parseInfluencerHashtags('  #Pune ,  3BHK,#NewLaunch  '),
        ['pune', '3bhk', 'newlaunch'],
      );
    });

    test('empties are dropped, not preserved as blanks', () {
      expect(parseInfluencerHashtags('a,,  ,b'), ['a', 'b']);
      expect(parseInfluencerHashtags(''), isEmpty);
      expect(parseInfluencerHashtags('   '), isEmpty);
    });

    test('duplicates survive, because the portal keeps them', () {
      // Not a bug to fix here: fixing it would make the same input produce
      // different rows on the two platforms.
      expect(parseInfluencerHashtags('#Pune, pune'), ['pune', 'pune']);
    });

    test('only one leading hash is removed', () {
      expect(parseInfluencerHashtags('##pune'), ['#pune']);
    });

    test('the form round-trips a stored list', () {
      // The portal seeds its field with `hashtags.join(', ')` (:32).
      const stored = ['pune', '3bhk'];
      expect(joinInfluencerHashtags(stored), 'pune, 3bhk');
      expect(parseInfluencerHashtags(joinInfluencerHashtags(stored)), stored);
    });
  });

  // ── 3. The model ────────────────────────────────────────────────────────
  group('InfluencerVideoModel', () {
    test('reads every column the service selects', () {
      final v = _video();
      expect(v.id, 'v-1');
      expect(v.userId, 'u-1');
      expect(v.videoType, 'property_listing');
      expect(v.hashtags, ['pune', '3bhk']);
      expect(v.views, 1200);
      expect(v.likes, 84);
      expect(v.createdAt, isNotNull);
    });

    test('an empty thumbnail is null, not an empty string', () {
      // Image.network('') throws where a null renders the placeholder.
      expect(_video(thumbnailUrl: '').thumbnailUrl, isNull);
      expect(_video(thumbnailUrl: null).thumbnailUrl, isNull);
    });

    test('a null user_id is tolerated', () {
      // 20270318030000:144 dropped this column's NOT NULL so a user delete can
      // null it instead of cascading.
      final v = InfluencerVideoModel.fromSupabase({
        'id': 'v-1',
        'title': 'Orphaned',
        'video_url': 'https://cdn.test/v.mp4',
        'video_type': 'property_news',
        'user_id': null,
      });
      expect(v.userId, isNull);
      expect(v.title, 'Orphaned');
    });

    test('missing counters and hashtags default rather than throw', () {
      final v = InfluencerVideoModel.fromSupabase({'id': 'v-1'});
      expect(v.views, 0);
      expect(v.likes, 0);
      expect(v.hashtags, isEmpty);
      expect(v.status, 'active');
      expect(v.approvalStatus, 'pending');
    });

    test('anything but approved is awaiting review', () {
      // The public read policy requires approval_status = 'approved'.
      expect(_video(approvalStatus: 'approved').isAwaitingReview, isFalse);
      expect(_video(approvalStatus: 'pending').isAwaitingReview, isTrue);
      expect(_video(approvalStatus: 'rejected').isAwaitingReview, isTrue);
    });

    test('the column list omits translations', () {
      // A large JSONB with no reader in this app.
      expect(InfluencerVideoModel.columns, contains('approval_status'));
      expect(InfluencerVideoModel.columns, contains('deleted_at'));
      expect(InfluencerVideoModel.columns, isNot(contains('translations')));
    });
  });

  // ── 4. The payload ──────────────────────────────────────────────────────
  group('InfluencerVideoDraft', () {
    const draft = InfluencerVideoDraft(
      title: 'Bandra 3BHK',
      description: 'A tour.',
      videoType: 'property_listing',
      videoUrl: 'https://cdn.test/v.mp4',
      thumbnailUrl: 'https://cdn.test/t.jpg',
      hashtags: ['pune'],
    );

    test('writes exactly the columns the portal writes', () {
      // InfluencerVideoModal.tsx:164-171 (update) and :182-190 (insert), minus
      // the user_id the insert adds separately.
      expect(
        draft.toPayload().keys.toSet(),
        {
          'title',
          'description',
          'video_url',
          'thumbnail_url',
          'video_type',
          'hashtags',
          'approval_status',
        },
      );
    });

    test('an edit re-queues for review', () {
      // `approval_status: 'pending'` is on the update path too (:170), which is
      // why the portal's toast says "updated successfully and is pending
      // approval".
      expect(draft.toPayload()['approval_status'], 'pending');
    });

    test('status is never written', () {
      // Not on create — the column default is 'active' — and not on edit, where
      // writing it would clobber whatever an admin set.
      expect(draft.toPayload().containsKey('status'), isFalse);
    });

    test('property_id is never written', () {
      // The modal does not set it, and writing null would erase a link some
      // other flow established.
      expect(draft.toPayload().containsKey('property_id'), isFalse);
    });

    test('a cleared thumbnail is sent as null', () {
      const cleared = InfluencerVideoDraft(
        title: 'T',
        videoType: 'property_news',
        videoUrl: 'https://cdn.test/v.mp4',
      );
      expect(cleared.toPayload()['thumbnail_url'], isNull);
    });
  });

  // ── 5. Media contracts ──────────────────────────────────────────────────
  group('InfluencerMediaService', () {
    test('the gate is the bucket\'s real 50 MB, not the portal\'s 200', () {
      // property-media's file_size_limit is 52428800
      // (20260522105737_fix_audit_issues.sql:18). InfluencerVideoModal.tsx:18
      // declares 200 MB and claims it matches — it does not.
      expect(InfluencerMediaService.maxVideoBytes, 52428800);
    });

    test('the bucket is shared with property media', () {
      expect(InfluencerMediaService.bucket, 'property-media');
    });

    test('sanitizeFileName strips the path and keeps one extension', () {
      // InfluencerVideoModal.tsx:84-90.
      expect(
        InfluencerMediaService.sanitizeFileName('/tmp/My Video (2).MP4'),
        'My_Video__2_.mp4',
      );
      expect(
        InfluencerMediaService.sanitizeFileName(r'C:\Users\a\clip.mov'),
        'clip.mov',
      );
    });

    test('a name with no usable extension keeps just the base', () {
      // `cleanExt ? \`${base}.${ext}\` : base` — a trailing dot leaves ext empty,
      // so the portal drops it rather than emitting `clip.`.
      expect(InfluencerMediaService.sanitizeFileName('clip'), 'clip');
      expect(InfluencerMediaService.sanitizeFileName('clip.'), 'clip');
    });

    test('video and image MIME types are set explicitly', () {
      // Left to storage, an .mov becomes application/octet-stream and will not
      // play from its public URL.
      expect(InfluencerMediaService.mimeFromName('a.mp4'), 'video/mp4');
      expect(InfluencerMediaService.mimeFromName('a.mov'), 'video/quicktime');
      expect(InfluencerMediaService.mimeFromName('a.webm'), 'video/webm');
      expect(InfluencerMediaService.mimeFromName('a.JPG'), 'image/jpeg');
      expect(InfluencerMediaService.mimeFromName('a.png'), 'image/png');
      expect(
        InfluencerMediaService.mimeFromName('a.xyz'),
        'application/octet-stream',
      );
    });
  });

  // ── 6. Service validation ───────────────────────────────────────────────
  group('InfluencerVideoService validation', () {
    // Constructed per test, not at group scope: the constructor resolves
    // Supabase.instance, which setUpAll has not run yet when a group body does.
    late InfluencerVideoService service;
    setUp(() => service = InfluencerVideoService());

    test('a blank title is refused before the round trip', () {
      expect(
        () => service.update(
          'v-1',
          const InfluencerVideoDraft(
            title: '   ',
            videoType: 'property_news',
            videoUrl: 'https://cdn.test/v.mp4',
          ),
        ),
        throwsA(isA<InfluencerVideoException>()),
      );
    });

    test('a missing video URL is refused', () {
      expect(
        () => service.update(
          'v-1',
          const InfluencerVideoDraft(
            title: 'T',
            videoType: 'property_news',
            videoUrl: '',
          ),
        ),
        throwsA(isA<InfluencerVideoException>()),
      );
    });

    test('a type outside the CHECK is refused, not sent as a 23514', () {
      expect(
        () => service.update(
          'v-1',
          const InfluencerVideoDraft(
            title: 'T',
            videoType: 'property_vlog',
            videoUrl: 'https://cdn.test/v.mp4',
          ),
        ),
        throwsA(isA<InfluencerVideoException>()),
      );
    });
  });

  // ── 7. The library section ──────────────────────────────────────────────
  group('MyVideosSection', () {
    testWidgets('renders a video with its type, counts and approval',
        (tester) async {
      await _pumpSection(
        tester,
        _FakeVideoService(rows: [_video()]),
      );

      expect(find.text('Bandra 3BHK walkthrough'), findsOneWidget);
      expect(find.text('Property Listing Video'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('1200'), findsOneWidget);
      expect(find.text('84'), findsOneWidget);
      expect(find.text('May 1, 2026'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('a pending video says it is awaiting review', (tester) async {
      await _pumpSection(
        tester,
        _FakeVideoService(rows: [_video(approvalStatus: 'pending')]),
      );
      expect(find.text('Pending Review'), findsOneWidget);
    });

    testWidgets('an active status shows no redundant pill', (tester) async {
      // Every row is 'active' by default; a pill saying so would carry no
      // information.
      await _pumpSection(tester, _FakeVideoService(rows: [_video()]));
      expect(find.text('Active'), findsNothing);
    });

    testWidgets('a non-default status is shown', (tester) async {
      await _pumpSection(
        tester,
        _FakeVideoService(rows: [_video(status: 'inactive')]),
      );
      expect(find.text('Inactive'), findsOneWidget);
    });

    testWidgets('an empty library collapses instead of prompting twice',
        (tester) async {
      // The Content tab already renders "Upload Your First Video".
      await _pumpSection(tester, _FakeVideoService(rows: const []));
      expect(find.byType(Card), findsNothing);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('a failed load offers a retry, and is not an empty list',
        (tester) async {
      final counts = <int>[];
      await _pumpSection(
        tester,
        _FakeVideoService()..listShouldFail = true,
        onCountChanged: counts.add,
      );

      expect(find.text("Couldn't load your videos"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(counts, isEmpty,
          reason: 'a parent that collapsed on error would hide the retry');
    });

    testWidgets('the count is reported after a load', (tester) async {
      final counts = <int>[];
      await _pumpSection(
        tester,
        _FakeVideoService(rows: [_video(id: 'a'), _video(id: 'b')]),
        onCountChanged: counts.add,
      );
      expect(counts, [2]);
    });

    testWidgets('Remove confirms, soft-deletes, and prunes the card',
        (tester) async {
      final counts = <int>[];
      final service = _FakeVideoService(rows: [_video()]);
      await _pumpSection(tester, service, onCountChanged: counts.add);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Video'), findsOneWidget);
      // The dialog must not promise permanence: soft delete keeps the row 30 days.
      expect(find.textContaining('Its views and likes are kept'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(service.softDeletes, ['v-1']);
      expect(find.text('Bandra 3BHK walkthrough'), findsNothing);
      expect(find.text('Video removed.'), findsOneWidget);
      expect(counts, [1, 0]);
    });

    testWidgets('cancelling the dialog deletes nothing', (tester) async {
      final service = _FakeVideoService(rows: [_video()]);
      await _pumpSection(tester, service);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(service.softDeletes, isEmpty);
      expect(find.text('Bandra 3BHK walkthrough'), findsOneWidget);
    });

    testWidgets('a false result keeps the card and says so', (tester) async {
      // soft_delete_content returns false when RLS matched nothing or the row was
      // already retired. Pruning the card would hide a video that is still live.
      final service = _FakeVideoService(
        rows: [_video()],
        softDeleteResult: false,
      );
      await _pumpSection(tester, service);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(service.softDeletes, ['v-1']);
      expect(find.text('Bandra 3BHK walkthrough'), findsOneWidget);
      expect(find.textContaining("couldn't be removed"), findsOneWidget);
      expect(find.text('Video removed.'), findsNothing);
    });

    testWidgets('a thrown delete keeps the card', (tester) async {
      final service = _FakeVideoService(rows: [_video()])
        ..deleteShouldThrow = true;
      await _pumpSection(tester, service);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(find.text('Bandra 3BHK walkthrough'), findsOneWidget);
      expect(find.textContaining('Could not remove'), findsOneWidget);
    });

    testWidgets('the card is inert while its delete is in flight',
        (tester) async {
      final service = _FakeVideoService(rows: [_video()]);
      final gate = Completer<bool>();
      service.gate = gate;
      await _pumpSection(tester, service);

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pump();

      // The action row is replaced by a spinner, so neither button can be tapped.
      expect(find.text('Edit'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete(true);
      await tester.pumpAndSettle();
      expect(service.softDeletes, hasLength(1));
    });

    testWidgets('only the tapped card is removed', (tester) async {
      final service = _FakeVideoService(rows: [
        _video(id: 'a', title: 'First'),
        _video(id: 'b', title: 'Second'),
      ]);
      await _pumpSection(tester, service);

      await tester.tap(find.text('Remove').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Remove'));
      await tester.pumpAndSettle();

      expect(service.softDeletes, ['a']);
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('lays out cleanly at 320 dp and 130% text', (tester) async {
      await _pumpSection(
        tester,
        _FakeVideoService(rows: [
          _video(
            title: 'A very long title about a sea-facing three bedroom flat',
            status: 'inactive',
            hashtags: const ['pune', '3bhk', 'newlaunch'],
          ),
        ]),
        textScale: 1.3,
      );

      expect(overflowingBoxes(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });
  });
}
