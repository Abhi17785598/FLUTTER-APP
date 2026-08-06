// Phase 4 — profile media upload.
//
// `ProfileMediaService` is deliberately self-contained: it does not import
// `PropertyService`, which is treated as stable. The cost of that is a second
// copy of the path/MIME conventions, so this file pins them.
//
// THE POINT OF THE MIME AND PATH ASSERTIONS
// -----------------------------------------
// A wrong bucket or a path that does not begin with the user id fails the storage
// policy with an opaque error — the policies require `(storage.foldername(name))[1]
// = auth.uid()`. A missing content type is worse than an error: Supabase stores
// `application/octet-stream`, the upload succeeds, and the image then downloads
// instead of rendering wherever the portal shows it. Neither is visible without a
// live bucket, so the shapes are asserted here instead.
import 'package:flutter_test/flutter_test.dart';

import 'package:propcid_app/services/profile_media_service.dart';

void main() {
  const userId = 'a1b2c3d4-0000-0000-0000-000000000000';
  const timestamp = 1770000000000;

  group('buckets follow the portal, including its inconsistency', () {
    test('avatars and documents go to the avatars bucket', () {
      // EditProfile.tsx:237 and AvatarUploadModal.tsx:164.
      expect(ProfileMediaService.avatarBucket, 'avatars');
    });

    test('covers go to property-media, as the portal genuinely does', () {
      // BackgroundUploadModal.tsx:161. Not a typo on our side: a cover uploaded
      // by the app must be readable at the URL the portal expects.
      expect(ProfileMediaService.coverBucket, 'property-media');
    });
  });

  group('every path starts with the user id', () {
    // The storage policies match on the first folder segment. A path that does
    // not begin with the caller's uid is rejected.
    test('avatar', () {
      final path = ProfileMediaService.avatarPath(userId, 'jpg', timestamp);
      expect(path.split('/').first, userId);
      expect(path, '$userId/$timestamp.jpg');
    });

    test('cover', () {
      final path = ProfileMediaService.coverPath(userId, 'png', timestamp);
      expect(path.split('/').first, userId);
      expect(path, '$userId/${timestamp}_background.png');
    });

    test('document', () {
      for (final kind in ProfileDocumentKind.values) {
        final path = ProfileMediaService.documentPath(
          userId,
          kind,
          'jpg',
          timestamp,
        );
        expect(path.split('/').first, userId, reason: kind.name);
        expect(path, '$userId/${kind.slug}_$timestamp.jpg', reason: kind.name);
      }
    });

    test('no path contains a double slash or a trailing dot', () {
      final paths = <String>[
        ProfileMediaService.avatarPath(userId, 'jpg', timestamp),
        ProfileMediaService.coverPath(userId, 'jpg', timestamp),
        for (final k in ProfileDocumentKind.values)
          ProfileMediaService.documentPath(userId, k, 'jpg', timestamp),
      ];
      for (final p in paths) {
        expect(p.contains('//'), isFalse, reason: p);
        expect(p.endsWith('.'), isFalse, reason: p);
      }
    });
  });

  group('document slugs match the portal upload types', () {
    test('each kind carries the portal\'s prefix', () {
      // EditProfile.tsx:245 — "rera" | "gst" | "pan" | "proof" | "logo" | "aadhaar".
      expect(ProfileDocumentKind.rera.slug, 'rera');
      expect(ProfileDocumentKind.gst.slug, 'gst');
      expect(ProfileDocumentKind.pan.slug, 'pan');
      expect(ProfileDocumentKind.registrationProof.slug, 'proof');
      expect(ProfileDocumentKind.aadhaar.slug, 'aadhaar');
      expect(ProfileDocumentKind.companyLogo.slug, 'logo');
    });

    test('slugs are unique, so two kinds cannot collide on one path', () {
      final slugs = ProfileDocumentKind.values.map((k) => k.slug).toList();
      expect(slugs.toSet().length, slugs.length);
    });

    test('only the company logo targets a column', () {
      final columnTargets = ProfileDocumentKind.values
          .where((k) => !k.target.startsWith('social_media.'))
          .toList();
      expect(columnTargets, [ProfileDocumentKind.companyLogo]);
      expect(ProfileDocumentKind.companyLogo.target, 'company_logo_url');
    });
  });

  group('extension parsing', () {
    test('lowercases and takes the last segment', () {
      expect(ProfileMediaService.extensionOf('photo.JPG'), 'jpg');
      expect(ProfileMediaService.extensionOf('a.b.png'), 'png');
    });

    test('defaults to jpg when there is no usable extension', () {
      // image_picker can hand back a cache filename with no extension; without a
      // default the path would end in "." and the MIME lookup would miss.
      expect(ProfileMediaService.extensionOf('noextension'), 'jpg');
      expect(ProfileMediaService.extensionOf('trailingdot.'), 'jpg');
      expect(ProfileMediaService.extensionOf(''), 'jpg');
    });
  });

  group('MIME mapping', () {
    test('covers every format image_picker can return', () {
      expect(ProfileMediaService.mimeFromExtension('jpg'), 'image/jpeg');
      expect(ProfileMediaService.mimeFromExtension('jpeg'), 'image/jpeg');
      expect(ProfileMediaService.mimeFromExtension('png'), 'image/png');
      expect(ProfileMediaService.mimeFromExtension('webp'), 'image/webp');
      expect(ProfileMediaService.mimeFromExtension('heic'), 'image/heic');
      expect(ProfileMediaService.mimeFromExtension('heif'), 'image/heif');
      expect(ProfileMediaService.mimeFromExtension('gif'), 'image/gif');
    });

    test('is case-insensitive', () {
      expect(ProfileMediaService.mimeFromExtension('PNG'), 'image/png');
    });

    test('agrees with the property feature on the shared formats', () {
      // PropertyService._mimeFromExt is private and unreachable, so the mapping is
      // duplicated by necessity. These four are the formats both accept, and this
      // is what catches a drift between the two copies.
      const shared = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'webp': 'image/webp',
        'heic': 'image/heic',
      };
      shared.forEach((ext, mime) {
        expect(ProfileMediaService.mimeFromExtension(ext), mime, reason: ext);
      });
    });

    test('an unknown extension falls back to octet-stream, as property does', () {
      expect(
        ProfileMediaService.mimeFromExtension('xyz'),
        'application/octet-stream',
      );
    });

    test('video types are NOT mapped — only images can be picked', () {
      // PropertyService maps mp4/mov because a listing accepts video. A profile
      // photo cannot be one, so mapping them here would imply support that the
      // picker does not offer.
      expect(
        ProfileMediaService.mimeFromExtension('mp4'),
        'application/octet-stream',
      );
      expect(
        ProfileMediaService.mimeFromExtension('mov'),
        'application/octet-stream',
      );
    });
  });

  group('compression ceilings match the portal', () {
    test('avatar 1024, cover 1920', () {
      // AvatarUploadModal.tsx:155 and BackgroundUploadModal.tsx:152.
      expect(ProfileMediaService.avatarMaxDimension, 1024);
      expect(ProfileMediaService.coverMaxDimension, 1920);
    });

    test('documents allow more detail than an avatar', () {
      // A photographed certificate must stay legible.
      expect(
        ProfileMediaService.documentMaxDimension,
        greaterThan(ProfileMediaService.avatarMaxDimension),
      );
    });

    test('quality is a sane JPEG value', () {
      expect(ProfileMediaService.jpegQuality, inInclusiveRange(70, 95));
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// NOT COVERED HERE
//
// The upload itself, and the `profiles` write that follows it, need a live bucket
// and a signed-in session — neither is available in this environment. What is
// asserted above is every value that would make such an upload fail or silently
// misbehave. End-to-end verification belongs with the Android device validation
// tracked as a release requirement (V1).
