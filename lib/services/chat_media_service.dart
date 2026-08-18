import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'messaging_exceptions.dart';

/// Image/voice upload into the shared, private `chat-media` Supabase Storage
/// bucket, plus signed-URL reads. Every limit/path convention below matches
/// the portal's features/messaging/lib/uploadChatMedia.ts and
/// chatMediaUrlCache.ts exactly — this reuses the same bucket, the same
/// `moderate-media`/`get-chat-media-url` Edge Functions, and the same
/// `${authUid}/${uuid}.${ext}` path the bucket's RLS policy requires.
class ChatMediaService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const _uuid = Uuid();

  static const int maxImageBytes = 10 * 1024 * 1024;
  static const int maxVideoBytes = 50 * 1024 * 1024;
  static const int maxVoiceBytes = 10 * 1024 * 1024;
  static const Duration maxVoiceDuration = Duration(minutes: 5);

  static const Set<String> allowedImageExtensions = {
    'jpg', 'jpeg', 'png', 'webp', 'heic',
  };

  final Map<String, _CachedUrl> _urlCache = {};

  /// Validates, strips EXIF/GPS, uploads, and inserts a `media_status:
  /// 'pending'` message row, then fires (fire-and-forget) the `moderate-media`
  /// Edge Function. Returns the inserted message id so the caller can offer a
  /// manual "Retry" if it's still pending after ~2 minutes.
  Future<String> sendImage({
    required Uint8List bytes,
    required String extension,
    required String surface, // 'dm' | 'channel'
    required String threadId, // conversation_id or channel_id
    required String senderId,
  }) async {
    final ext = extension.toLowerCase().replaceFirst('.', '');
    if (!allowedImageExtensions.contains(ext)) {
      throw ChatMediaValidationError(
        '"$ext" isn\'t supported. Use JPEG, PNG, WebP, HEIC, or MP4.',
      );
    }
    if (bytes.lengthInBytes > maxImageBytes) {
      throw const ChatMediaValidationError('Image must be 10MB or smaller.');
    }

    final stripped = await _stripExif(bytes, ext: ext);
    final path = '$senderId/${_uuid.v4()}.$ext';

    try {
      await _supabase.storage.from('chat-media').uploadBinary(
            path,
            stripped,
            fileOptions: FileOptions(contentType: _contentTypeFor(ext)),
          );
    } catch (e) {
      debugPrint('ChatMediaService.sendImage upload failed: $e');
      rethrow;
    }

    final table = surface == 'channel' ? 'channel_messages' : 'messages';
    final idColumn = surface == 'channel' ? 'channel_id' : 'conversation_id';

    final inserted = await _supabase
        .from(table)
        .insert({
          idColumn: threadId,
          'sender_id': senderId,
          'content': '',
          'message_type': 'image',
          'media_urls': [path],
          'media_status': 'pending',
        })
        .select('id')
        .single();

    final messageId = inserted['id']?.toString();
    if (messageId == null) {
      throw StateError('Image message insert returned no id');
    }

    unawaited(requestModeration(
      storagePath: path,
      messageId: messageId,
      surface: surface,
    ));

    return messageId;
  }

  /// Re-runs moderation for a message stuck `pending` — the manual "Retry"
  /// action, or the initial fire-and-forget call right after upload. Errors
  /// are swallowed here (matching the portal's fire-and-forget pattern): a
  /// failure just leaves the row `pending` for the server-side sweep cron.
  Future<void> requestModeration({
    required String storagePath,
    required String messageId,
    required String surface,
  }) async {
    try {
      await _supabase.functions.invoke(
        'moderate-media',
        body: {
          'storagePath': storagePath,
          'bucket': 'chat-media',
          'messageId': messageId,
          'surface': surface,
        },
      );
    } catch (e) {
      debugPrint('ChatMediaService.requestModeration failed (will retry later): $e');
    }
  }

  /// Uploads a recorded voice note. No moderation step for audio — approved
  /// immediately, matching the portal exactly.
  Future<void> sendVoiceNote({
    required Uint8List bytes,
    required String extension,
    required Duration duration,
    required String surface,
    required String threadId,
    required String senderId,
  }) async {
    const allowedExt = {'webm', 'm4a', 'mp4', 'ogg', 'wav', 'aac'};
    final ext = extension.toLowerCase().replaceFirst('.', '');
    if (!allowedExt.contains(ext)) {
      throw ChatMediaValidationError('"$ext" isn\'t a supported recording format.');
    }
    if (bytes.lengthInBytes > maxVoiceBytes) {
      throw const ChatMediaValidationError('Voice note must be 10MB or smaller.');
    }
    if (duration > maxVoiceDuration) {
      throw const ChatMediaValidationError('Voice notes are limited to 5 minutes.');
    }

    final path = '$senderId/${_uuid.v4()}.$ext';
    await _supabase.storage.from('chat-media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentTypeFor(ext)),
        );

    final table = surface == 'channel' ? 'channel_messages' : 'messages';
    final idColumn = surface == 'channel' ? 'channel_id' : 'conversation_id';

    await _supabase.from(table).insert({
      idColumn: threadId,
      'sender_id': senderId,
      'content': 'Voice message',
      'message_type': 'audio',
      'media_urls': [path],
      'media_status': 'approved',
    });
  }

  /// A short-lived signed URL for a private `chat-media` object — the only
  /// way to read it; the bucket has no SELECT policy at all. Cached ~4
  /// minutes client-side (the function's own TTL is 5 minutes server-side).
  Future<String> getSignedUrl({
    required String path,
    required String surface,
  }) async {
    final cached = _urlCache[path];
    if (cached != null && cached.expiresAt.isAfter(DateTime.now())) {
      return cached.url;
    }

    final response = await _supabase.functions.invoke(
      'get-chat-media-url',
      body: {'path': path, 'surface': surface},
    );
    final data = response.data;
    final url = data is Map ? data['url'] as String? : null;
    if (url == null) {
      throw StateError('get-chat-media-url returned no url');
    }
    _urlCache[path] = _CachedUrl(url, DateTime.now().add(const Duration(minutes: 4)));
    return url;
  }

  /// Re-encodes jpg/png in place (dropping EXIF/GPS in the process, since
  /// `image`'s decoders don't carry it forward unless explicitly copied).
  /// webp/heic are uploaded unchanged — the `image` package's WebP encoder
  /// isn't reliable enough across platforms to risk silently corrupting the
  /// upload, and it has no HEIC encoder at all. This is a smaller privacy
  /// guarantee than the portal's (which re-encodes every image via canvas),
  /// flagged rather than papered over with an encoder that might mis-fire.
  Future<Uint8List> _stripExif(Uint8List bytes, {required String ext}) async {
    if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') return bytes;
    try {
      return await compute(_StripExifJob(ext).run, bytes);
    } catch (e) {
      // Re-encoding failed (unsupported/corrupt image) — upload the original
      // rather than blocking the send entirely.
      debugPrint('ChatMediaService: EXIF strip failed, uploading as-is: $e');
      return bytes;
    }
  }

  String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'm4a':
      case 'aac':
        return 'audio/mp4';
      case 'ogg':
        return 'audio/ogg';
      case 'wav':
        return 'audio/wav';
      case 'webm':
        return 'audio/webm';
      default:
        return 'image/jpeg';
    }
  }
}

class _CachedUrl {
  final String url;
  final DateTime expiresAt;
  _CachedUrl(this.url, this.expiresAt);
}

/// Runs on a background isolate via `compute` — decoding/re-encoding a full
/// photo on the UI isolate would jank the send button's tap animation. A
/// small sendable job object (just the target extension) rather than a
/// closure, since `compute`/`Isolate.run` require the callback to not
/// capture non-sendable state.
class _StripExifJob {
  final String ext;
  const _StripExifJob(this.ext);

  Uint8List run(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;
    // `image`'s decoders drop EXIF/ICC metadata by default unless explicitly
    // copied forward, so a plain re-encode is sufficient to strip GPS/EXIF.
    return ext == 'png'
        ? Uint8List.fromList(img.encodePng(decoded))
        : Uint8List.fromList(img.encodeJpg(decoded, quality: 88));
  }
}

/// Not part of [ChatMediaService] itself since `File` (dart:io) isn't
/// available on web — kept as a free function so callers on a platform that
/// supports it can read bytes/extension from an [image_picker] `XFile`
/// without this service depending on `dart:io` at all.
Future<Uint8List> readFileBytes(String path) => File(path).readAsBytes();
