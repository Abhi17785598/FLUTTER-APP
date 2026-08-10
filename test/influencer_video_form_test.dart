// Spec E — the influencer video form.
//
// `InfluencerVideoModal.tsx` is the reference. What is pinned:
//
//   * the two pre-flight gates, and that they behave differently on create and
//     edit — a new video needs a file, an existing one does not (:112-118);
//   * that an edit which touches no file re-uploads nothing, which is the whole
//     point of `let videoUrl = editingVideo?.video_url` (:128-130);
//   * the form seeding from the row being edited, hashtags included (:29-38);
//   * that a failed upload does not write a row.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:propcid_app/models/influencer_video_model.dart';
import 'package:propcid_app/providers/auth_provider.dart';
import 'package:propcid_app/screens/influencer/influencer_video_form_screen.dart';
import 'package:propcid_app/services/influencer_media_service.dart';
import 'package:propcid_app/services/influencer_video_service.dart';

import 'support/overflow_detector.dart';

const Size kSmall = Size(320, 720);

class _FakeAuth extends AuthProvider {
  _FakeAuth({this.id = 'u-1'});

  final String? id;

  @override
  String? get userId => id;

  @override
  bool get isLoggedIn => id != null;
}

class _FakeVideoService extends InfluencerVideoService {
  final List<({InfluencerVideoDraft draft, String userId})> creates = [];
  final List<({String id, InfluencerVideoDraft draft})> updates = [];

  @override
  Future<String> create(InfluencerVideoDraft draft, String userId) async {
    creates.add((draft: draft, userId: userId));
    return 'new-id';
  }

  @override
  Future<void> update(String videoId, InfluencerVideoDraft draft) async {
    updates.add((id: videoId, draft: draft));
  }
}

class _FakeMediaService extends InfluencerMediaService {
  final List<String> videoUploads = [];
  final List<String> thumbnailUploads = [];

  /// When set, the next `uploadVideo` throws this instead of returning.
  InfluencerMediaException? videoFailure;

  @override
  Future<String> uploadVideo({
    required File file,
    required String userId,
    void Function(String stage)? onProgress,
  }) async {
    videoUploads.add(file.path);
    onProgress?.call('Compressing video…');
    final failure = videoFailure;
    if (failure != null) {
      videoFailure = null;
      throw failure;
    }
    return 'https://cdn.test/$userId/videos/uploaded.mp4';
  }

  @override
  Future<String> uploadThumbnail({
    required File file,
    required String userId,
  }) async {
    thumbnailUploads.add(file.path);
    return 'https://cdn.test/$userId/thumbnails/uploaded.jpg';
  }
}

/// Returns a scripted path instead of opening a gallery.
class _FakePicker extends ImagePicker {
  _FakePicker({this.videoPath, this.imagePath});

  final String? videoPath;
  final String? imagePath;

  @override
  Future<XFile?> pickVideo({
    required ImageSource source,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    Duration? maxDuration,
  }) async =>
      videoPath == null ? null : XFile(videoPath!);

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async =>
      imagePath == null ? null : XFile(imagePath!);
}

InfluencerVideoModel _existing() => InfluencerVideoModel.fromSupabase({
      'id': 'v-1',
      'user_id': 'u-1',
      'title': 'Bandra 3BHK walkthrough',
      'description': 'A quick tour.',
      'video_url': 'https://cdn.test/existing.mp4',
      'thumbnail_url': 'https://cdn.test/existing.jpg',
      'video_type': 'property_news',
      'hashtags': ['pune', '3bhk'],
      'status': 'active',
      'approval_status': 'approved',
    });

/// Tall enough that the whole form is laid out at once.
///
/// The form is a `ListView`, so on a 720 dp viewport the Details card sits below
/// the fold and is never built — `enterText` cannot reach a field that does not
/// exist. Interaction tests use this; the layout group uses [kSmall], which is the
/// size that actually matters for overflow.
const Size kTall = Size(320, 2400);

Future<void> _pumpForm(
  WidgetTester tester, {
  InfluencerVideoModel? editing,
  required _FakeVideoService service,
  required _FakeMediaService media,
  _FakePicker? picker,
  String? userId = 'u-1',
  double textScale = 1.0,
  Size size = kTall,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: _FakeAuth(id: userId),
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: InfluencerVideoFormScreen(
          editing: editing,
          videoService: service,
          mediaService: media,
          picker: picker ?? _FakePicker(),
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

  // ── 1. Create ───────────────────────────────────────────────────────────
  group('create mode', () {
    testWidgets('opens empty, with every video type offered', (tester) async {
      await _pumpForm(
        tester,
        service: _FakeVideoService(),
        media: _FakeMediaService(),
      );

      expect(find.text('Upload Video'), findsWidgets);
      expect(find.text('Property Listing Video'), findsOneWidget);
      expect(find.text('Property News'), findsOneWidget);
      expect(find.text('Property Education'), findsOneWidget);
      expect(find.text('Choose a video'), findsOneWidget);
    });

    testWidgets('submitting empty names every problem at once', (tester) async {
      // The modal raises one toast and stops; a summary is more useful on a form
      // the user can see all of.
      final service = _FakeVideoService();
      await _pumpForm(tester, service: service, media: _FakeMediaService());

      await tester.tap(find.widgetWithText(ElevatedButton, 'Upload Video'));
      await tester.pumpAndSettle();

      expect(find.text('Please upload a video file.'), findsOneWidget);
      expect(find.text('A title is required.'), findsOneWidget);
      expect(find.text('Choose a video type.'), findsOneWidget);
      expect(service.creates, isEmpty);
    });

    testWidgets('a full submit uploads then inserts', (tester) async {
      final service = _FakeVideoService();
      final media = _FakeMediaService();
      await _pumpForm(
        tester,
        service: service,
        media: media,
        picker: _FakePicker(videoPath: '/tmp/clip.mp4'),
      );

      await tester.tap(find.text('Choose a video'));
      await tester.pumpAndSettle();
      expect(find.text('clip.mp4'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).first,
        'Bandra 3BHK walkthrough',
      );
      await tester.tap(find.text('Property News'));
      await tester.pumpAndSettle();

      // The hashtags field is the third and last on the form.
      await tester.enterText(find.byType(TextField).last, '#Pune, 3BHK');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Upload Video'));
      await tester.pumpAndSettle();

      expect(media.videoUploads, ['/tmp/clip.mp4']);
      expect(media.thumbnailUploads, isEmpty);

      final created = service.creates.single;
      expect(created.userId, 'u-1');
      expect(created.draft.title, 'Bandra 3BHK walkthrough');
      expect(created.draft.videoType, 'property_news');
      expect(created.draft.hashtags, ['pune', '3bhk']);
      expect(
        created.draft.videoUrl,
        'https://cdn.test/u-1/videos/uploaded.mp4',
      );
      expect(created.draft.thumbnailUrl, isNull);
    });

    testWidgets('a failed upload writes no row and shows the reason',
        (tester) async {
      final service = _FakeVideoService();
      final media = _FakeMediaService()
        ..videoFailure = const InfluencerMediaException(
          'Video is too large (91.4 MB). Maximum is 50.0 MB.',
        );
      await _pumpForm(
        tester,
        service: service,
        media: media,
        picker: _FakePicker(videoPath: '/tmp/huge.mp4'),
      );

      await tester.tap(find.text('Choose a video'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Too big');
      await tester.tap(find.text('Property News'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Upload Video'));
      await tester.pumpAndSettle();

      expect(service.creates, isEmpty,
          reason: 'a row pointing at nothing is worse than no row');
      // The service's message, verbatim — not replaced with generic copy.
      expect(find.textContaining('Video is too large'), findsOneWidget);
    });

    testWidgets('a signed-out submit is refused before any upload',
        (tester) async {
      final media = _FakeMediaService();
      await _pumpForm(
        tester,
        service: _FakeVideoService(),
        media: media,
        picker: _FakePicker(videoPath: '/tmp/clip.mp4'),
        userId: null,
      );

      await tester.tap(find.text('Choose a video'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Orphan');
      await tester.tap(find.text('Property News'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Upload Video'));
      await tester.pumpAndSettle();

      expect(media.videoUploads, isEmpty);
      expect(find.textContaining('Sign in again'), findsOneWidget);
    });

    testWidgets('a thumbnail is uploaded when one is picked', (tester) async {
      final service = _FakeVideoService();
      final media = _FakeMediaService();
      await _pumpForm(
        tester,
        service: service,
        media: media,
        picker: _FakePicker(
          videoPath: '/tmp/clip.mp4',
          imagePath: '/tmp/thumb.jpg',
        ),
      );

      await tester.tap(find.text('Choose a video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose a thumbnail'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'With a thumb');
      await tester.tap(find.text('Property News'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Upload Video'));
      await tester.pumpAndSettle();

      expect(media.thumbnailUploads, ['/tmp/thumb.jpg']);
      expect(
        service.creates.single.draft.thumbnailUrl,
        'https://cdn.test/u-1/thumbnails/uploaded.jpg',
      );
    });
  });

  // ── 2. Edit ─────────────────────────────────────────────────────────────
  group('edit mode', () {
    testWidgets('seeds every field from the row', (tester) async {
      await _pumpForm(
        tester,
        editing: _existing(),
        service: _FakeVideoService(),
        media: _FakeMediaService(),
      );

      expect(find.text('Edit Video'), findsWidgets);
      expect(find.text('Bandra 3BHK walkthrough'), findsOneWidget);
      expect(find.text('A quick tour.'), findsOneWidget);
      // The portal's own seed: hashtags.join(', ').
      expect(find.text('pune, 3bhk'), findsOneWidget);
      // The stored video reads as present without being re-picked.
      expect(find.text('Uploaded video'), findsOneWidget);
      expect(find.text('Choose a video'), findsNothing);
    });

    testWidgets('saving without touching a file re-uploads nothing',
        (tester) async {
      final service = _FakeVideoService();
      final media = _FakeMediaService();
      await _pumpForm(
        tester,
        editing: _existing(),
        service: service,
        media: media,
      );

      await tester.enterText(find.byType(TextField).first, 'A better title');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(media.videoUploads, isEmpty);
      expect(media.thumbnailUploads, isEmpty);

      final updated = service.updates.single;
      expect(updated.id, 'v-1');
      expect(updated.draft.title, 'A better title');
      // The stored URLs carried through untouched.
      expect(updated.draft.videoUrl, 'https://cdn.test/existing.mp4');
      expect(updated.draft.thumbnailUrl, 'https://cdn.test/existing.jpg');
      // And the edit re-queues for review.
      expect(updated.draft.toPayload()['approval_status'], 'pending');
    });

    testWidgets('an edit does not demand a new video file', (tester) async {
      // The create-mode gate must not fire here (:113).
      final service = _FakeVideoService();
      await _pumpForm(
        tester,
        editing: _existing(),
        service: service,
        media: _FakeMediaService(),
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please upload a video file.'), findsNothing);
      expect(service.updates, hasLength(1));
    });

    testWidgets('clearing the thumbnail sends null', (tester) async {
      final service = _FakeVideoService();
      await _pumpForm(
        tester,
        editing: _existing(),
        service: service,
        media: _FakeMediaService(),
      );

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a thumbnail'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(service.updates.single.draft.thumbnailUrl, isNull);
    });

    testWidgets('an emptied title blocks the save', (tester) async {
      final service = _FakeVideoService();
      await _pumpForm(
        tester,
        editing: _existing(),
        service: service,
        media: _FakeMediaService(),
      );

      await tester.enterText(find.byType(TextField).first, '   ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('A title is required.'), findsOneWidget);
      expect(service.updates, isEmpty);
    });
  });

  // ── 3. Layout ───────────────────────────────────────────────────────────
  group('layout', () {
    testWidgets('lays out cleanly at 320 dp and 130% text', (tester) async {
      await _pumpForm(
        tester,
        editing: _existing(),
        service: _FakeVideoService(),
        media: _FakeMediaService(),
        textScale: 1.3,
        size: kSmall,
      );

      expect(overflowingBoxes(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the validation summary does not overflow either',
        (tester) async {
      await _pumpForm(
        tester,
        service: _FakeVideoService(),
        media: _FakeMediaService(),
        textScale: 1.3,
        size: kSmall,
      );

      // The submit button sits below the fold on a real phone, so it has to be
      // scrolled to before it can be tapped — which is also what makes this the
      // realistic path for the summary to appear on.
      await tester.scrollUntilVisible(
        find.widgetWithText(ElevatedButton, 'Upload Video'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Upload Video'));
      await tester.pumpAndSettle();

      expect(overflowingBoxes(tester), isEmpty);
    });
  });
}
