// services/profile_media_service.dart
//
// Picks and uploads profile media: avatar, cover photo, and verification
// documents.
//
// COMPLETELY SELF-CONTAINED (approved decision: Option A)
// ------------------------------------------------------
// This file imports nothing from the property feature and nothing from
// `PropertyService`, which is treated as stable. The app's only other upload code
// is `PropertyService._uploadMedia` — private, coupled to `PostPropertyProvider`,
// with the `property-media` bucket and its path pattern hardcoded — so it could
// not be called from here without changing its visibility and signature. That was
// explicitly ruled out.
//
// What is deliberately MIRRORED rather than imported:
//   * `uploadBinary` + `getPublicUrl` against a named bucket
//   * `{userId}/…` path prefix, which is what the storage policies require
//   * an extension→MIME map, because `XFile.mimeType` is null on some platforms
//   * compression via `image_picker`'s own sizing, the approach
//     `post_property/steps/media_contact_step.dart:80` already documents
//
// `test/profile_media_service_test.dart` asserts the mirrored MIME map and path
// shapes, so the duplication cannot silently drift from the property feature's.
//
// STORAGE POLICIES — no backend change is needed. Both buckets already exist and
// their INSERT/UPDATE policies require the first path segment to equal
// `auth.uid()` (20260317110000_create_required_storage_buckets.sql). Every path
// built below starts with the user id.
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Which profile document is being uploaded.
///
/// The slug becomes the filename prefix and mirrors the portal's
/// `handleDocumentUpload` types (EditProfile.tsx:243-257).
enum ProfileDocumentKind {
  rera('rera', 'social_media.rera_certificate_url'),
  gst('gst', 'social_media.gst_certificate_url'),
  pan('pan', 'social_media.pan_card_url'),
  registrationProof('proof', 'social_media.registration_proof_url'),
  aadhaar('aadhaar', 'social_media.aadhaar_card_url'),
  companyLogo('logo', 'company_logo_url');

  const ProfileDocumentKind(this.slug, this.target);

  /// Filename prefix.
  final String slug;

  /// Where the resulting URL belongs. Documentation only — this service returns
  /// the URL and the caller stores it, because five of the six live inside the
  /// `social_media` JSON and must go through the merge-preserving writer.
  final String target;
}

class ProfileMediaService {
  ProfileMediaService({
    ImagePicker? picker,
    SupabaseClient? client,
    AuthService? authService,
  }) : _picker = picker ?? ImagePicker(),
       _supabase = client ?? Supabase.instance.client,
       _authService = authService ?? AuthService();

  final ImagePicker _picker;
  final SupabaseClient _supabase;
  final AuthService _authService;

  // ── Buckets ───────────────────────────────────────────────────────────────

  /// Avatars and verification documents.
  ///
  /// The portal is internally inconsistent here — `EditProfile.tsx` and
  /// `AvatarUploadModal.tsx` write avatars to `avatars`, while `UserProfile.tsx`'s
  /// inline handler writes them to `property-media`. `avatars` is followed because
  /// it is what the edit form and the dedicated modal use, and it is the bucket
  /// named for the purpose.
  static const String avatarBucket = 'avatars';

  /// Cover photos, matching `BackgroundUploadModal.tsx:161`.
  ///
  /// Not `avatars`: the portal genuinely puts covers in `property-media`, and a
  /// cover uploaded by the app must be readable by the portal at the URL it
  /// expects to find.
  static const String coverBucket = 'property-media';

  // ── Sizing ────────────────────────────────────────────────────────────────
  //
  // The portal compresses client-side before upload: 1024 px for avatars
  // (AvatarUploadModal.tsx:155) and 1920 px for covers
  // (BackgroundUploadModal.tsx:152). `image_picker` applies the same ceiling at
  // capture time, which is the approach the Post Property wizard documents —
  // it avoids pulling in an image-processing package (R14 forbids new deps).

  static const double avatarMaxDimension = 1024;
  static const double coverMaxDimension = 1920;
  static const double documentMaxDimension = 2048;
  static const int jpegQuality = 85;

  // ── Picking ───────────────────────────────────────────────────────────────

  /// Opens the gallery or camera and returns the chosen image, already downscaled.
  ///
  /// Returns null when the user cancels — not an error.
  Future<XFile?> pickImage({
    required ImageSource source,
    required double maxDimension,
  }) async {
    try {
      return await _picker.pickImage(
        source: source,
        maxWidth: maxDimension,
        maxHeight: maxDimension,
        imageQuality: jpegQuality,
      );
    } catch (e) {
      debugPrint('ProfileMediaService.pickImage failed: $e');
      return null;
    }
  }

  Future<XFile?> pickAvatar({ImageSource source = ImageSource.gallery}) =>
      pickImage(source: source, maxDimension: avatarMaxDimension);

  Future<XFile?> pickCover({ImageSource source = ImageSource.gallery}) =>
      pickImage(source: source, maxDimension: coverMaxDimension);

  /// Documents are images only.
  ///
  /// The portal accepts `.pdf,image/*`. `image_picker` cannot select a PDF and
  /// `file_picker` is not a declared dependency, so PDF upload is out of scope —
  /// see the Phase 4 report.
  Future<XFile?> pickDocument({ImageSource source = ImageSource.gallery}) =>
      pickImage(source: source, maxDimension: documentMaxDimension);

  // ── Paths ─────────────────────────────────────────────────────────────────

  /// `{userId}/{timestamp}.{ext}` — mirrors `AvatarUploadModal.tsx:160-161`.
  @visibleForTesting
  static String avatarPath(String userId, String ext, int timestamp) =>
      '$userId/$timestamp.$ext';

  /// `{userId}/{timestamp}_background.{ext}` — mirrors
  /// `BackgroundUploadModal.tsx:157-158`.
  @visibleForTesting
  static String coverPath(String userId, String ext, int timestamp) =>
      '$userId/${timestamp}_background.$ext';

  /// `{userId}/{slug}_{timestamp}.{ext}` — mirrors `EditProfile.tsx:236`.
  @visibleForTesting
  static String documentPath(
    String userId,
    ProfileDocumentKind kind,
    String ext,
    int timestamp,
  ) => '$userId/${kind.slug}_$timestamp.$ext';

  /// Lowercased extension, defaulting to `jpg`.
  ///
  /// A filename with no dot, or a trailing dot, yields `jpg` rather than an empty
  /// extension that would produce a path ending in `.`.
  @visibleForTesting
  static String extensionOf(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return 'jpg';
    final ext = fileName.substring(dot + 1).toLowerCase();
    return ext.isEmpty ? 'jpg' : ext;
  }

  /// Extension → MIME.
  ///
  /// A self-contained mirror of the mapping the property upload uses. `XFile`'s
  /// own `mimeType` is null on several platforms, and Supabase Storage stores
  /// `application/octet-stream` when no content type is supplied — which makes the
  /// object download instead of render in a browser.
  ///
  /// Only image types, since only images can be picked.
  @visibleForTesting
  static String mimeFromExtension(String ext) => switch (ext.toLowerCase()) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'gif' => 'image/gif',
    _ => 'application/octet-stream',
  };

  // ── Uploading ─────────────────────────────────────────────────────────────

  /// Uploads [file] to [bucket] at [path] and returns its public URL.
  ///
  /// `upsert: true` so re-uploading the same path replaces rather than 409s. Paths
  /// carry a timestamp so this is belt-and-braces rather than load-bearing.
  Future<String> _upload({
    required String bucket,
    required String path,
    required XFile file,
  }) async {
    final bytes = await file.readAsBytes();
    final ext = extensionOf(file.name);

    await _supabase.storage
        .from(bucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: file.mimeType ?? mimeFromExtension(ext),
            upsert: true,
          ),
        );

    return _supabase.storage.from(bucket).getPublicUrl(path);
  }

  /// Uploads a new avatar and writes `profiles.avatar_url`.
  ///
  /// Returns the public URL. Throws on failure so the caller can tell the user —
  /// a silently failed upload that leaves the old photo in place is worse than an
  /// error, because the user believes it worked.
  ///
  /// The `profiles` write goes through `AuthService.updateProfileFields`, the app's
  /// established writer, rather than a second `.update()` here.
  Future<String> uploadAvatar({
    required String userId,
    required XFile file,
  }) async {
    final url = await _upload(
      bucket: avatarBucket,
      path: avatarPath(
        userId,
        extensionOf(file.name),
        DateTime.now().millisecondsSinceEpoch,
      ),
      file: file,
    );

    await _authService.updateProfileFields(userId, {'avatar_url': url});
    return url;
  }

  /// Uploads a cover photo and writes `profiles.background_image_url`.
  Future<String> uploadCover({
    required String userId,
    required XFile file,
  }) async {
    final url = await _upload(
      bucket: coverBucket,
      path: coverPath(
        userId,
        extensionOf(file.name),
        DateTime.now().millisecondsSinceEpoch,
      ),
      file: file,
    );

    await _authService.updateProfileFields(userId, {
      'background_image_url': url,
    });
    return url;
  }

  /// Uploads a verification document and returns its public URL **without**
  /// writing it anywhere.
  ///
  /// Five of the six kinds live inside `profiles.social_media`, which must be
  /// written through the merge-preserving path in `ProfileWriteService` — writing
  /// the JSON column from here would replace it and destroy every other key. The
  /// caller stores the returned URL and saves it with the rest of the form.
  Future<String> uploadDocument({
    required String userId,
    required ProfileDocumentKind kind,
    required XFile file,
  }) async {
    return _upload(
      bucket: avatarBucket,
      path: documentPath(
        userId,
        kind,
        extensionOf(file.name),
        DateTime.now().millisecondsSinceEpoch,
      ),
      file: file,
    );
  }
}
