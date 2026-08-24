import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/chat_message.dart';
import '../../../services/chat_media_service.dart';

/// Renders an image or voice-note message via a short-lived signed URL — the
/// `chat-media` bucket is private with no SELECT policy at all, so every read
/// goes through the `get-chat-media-url` Edge Function
/// ([ChatMediaService.getSignedUrl]), never a public/cached path.
///
/// Mirrors the portal's `ChatMediaImage.tsx` state machine: `pending` shows a
/// placeholder with a manual retry after ~2 minutes (there's also a 10-minute
/// server-side sweep cron, so retry is a convenience, not the only path to
/// resolution); `rejected` shows a removed-content notice; `approved` renders
/// the real media.
class ChatMediaView extends StatefulWidget {
  final ChatMessage message;
  final String surface; // 'dm' | 'channel'
  final bool isMine;

  const ChatMediaView({
    super.key,
    required this.message,
    required this.surface,
    required this.isMine,
  });

  @override
  State<ChatMediaView> createState() => _ChatMediaViewState();
}

class _ChatMediaViewState extends State<ChatMediaView> {
  final _service = ChatMediaService();
  String? _signedUrl;
  bool _loadingUrl = false;
  bool _retrying = false;
  Timer? _retryEligibleTimer;
  bool _retryEligible = false;

  String? get _path =>
      widget.message.mediaUrls.isEmpty ? null : widget.message.mediaUrls.first;

  @override
  void initState() {
    super.initState();
    if (widget.message.mediaStatus == MediaStatus.approved) {
      _loadUrl();
    }
    if (widget.message.mediaStatus == MediaStatus.pending) {
      _retryEligibleTimer = Timer(const Duration(minutes: 2), () {
        if (mounted) setState(() => _retryEligible = true);
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatMediaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.mediaStatus != MediaStatus.approved &&
        widget.message.mediaStatus == MediaStatus.approved) {
      _loadUrl();
    }
  }

  @override
  void dispose() {
    _retryEligibleTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    final path = _path;
    if (path == null || _loadingUrl) return;
    setState(() => _loadingUrl = true);
    try {
      final url = await _service.getSignedUrl(
        path: path,
        surface: widget.surface,
      );
      if (mounted) setState(() => _signedUrl = url);
    } catch (_) {
      // Left null — the placeholder below covers this case too.
    } finally {
      if (mounted) setState(() => _loadingUrl = false);
    }
  }

  Future<void> _retryModeration() async {
    final path = _path;
    if (path == null) return;
    setState(() => _retrying = true);
    await _service.requestModeration(
      storagePath: path,
      messageId: widget.message.id,
      surface: widget.surface,
    );
    if (mounted) setState(() => _retrying = false);
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.message.mediaStatus) {
      case MediaStatus.rejected:
        return _placeholder(
          icon: Icons.block,
          label: 'This content was removed',
        );
      case MediaStatus.pending:
        return _pendingView();
      case MediaStatus.approved:
      case MediaStatus.text:
        if (widget.message.isAudio) return _audioPlayer();
        if (widget.message.isVideo) {
          // Video playback isn't wired up yet — surfaced honestly as
          // unsupported rather than attempting to decode a video file as a
          // still image (which would silently show a broken-image icon).
          return _placeholder(
            icon: Icons.videocam_outlined,
            label: 'Video playback not supported yet',
          );
        }
        return _imageView();
    }
  }

  Widget _pendingView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _placeholder(icon: Icons.hourglass_top, label: 'Checking image…'),
        if (_retryEligible) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _retrying ? null : _retryModeration,
            child: Text(
              _retrying ? 'Retrying…' : 'Retry',
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.isMine ? Colors.white : AppColors.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _imageView() {
    if (_signedUrl == null) {
      return _placeholder(
        icon: _loadingUrl ? Icons.hourglass_top : Icons.image_outlined,
        label: _loadingUrl ? 'Loading…' : 'Image unavailable',
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: _signedUrl!,
        // Signed URLs expire; cache the pixels, not the (soon-invalid) URL.
        cacheKey: _path,
        width: 200,
        fit: BoxFit.cover,
        placeholder: (_, _) => const SizedBox(
          width: 200,
          height: 150,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, _, _) => _placeholder(
          icon: Icons.broken_image_outlined,
          label: "Couldn't load image",
        ),
      ),
    );
  }

  Widget _audioPlayer() {
    return _VoiceMessagePlayer(
      resolveUrl: () =>
          _service.getSignedUrl(path: _path ?? '', surface: widget.surface),
      isMine: widget.isMine,
    );
  }

  Widget _placeholder({required IconData icon, required String label}) {
    return Container(
      width: 200,
      height: 120,
      decoration: BoxDecoration(
        color: (widget.isMine ? Colors.white : AppColors.textHint).withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: widget.isMine ? Colors.white : AppColors.textHint,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11,
              color: widget.isMine ? Colors.white70 : AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceMessagePlayer extends StatefulWidget {
  final Future<String> Function() resolveUrl;
  final bool isMine;

  const _VoiceMessagePlayer({required this.resolveUrl, required this.isMine});

  @override
  State<_VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<_VoiceMessagePlayer> {
  final _player = AudioPlayer();
  bool _playing = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final url = await widget.resolveUrl();
      await _player.play(UrlSource(url));
      if (mounted) setState(() => _playing = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't play this voice message.")),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMine ? Colors.white : AppColors.primary;
    return SizedBox(
      width: 160,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _loading ? null : _toggle,
            child: _loading
                ? SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(
                    _playing
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_filled,
                    size: 28,
                    color: color,
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            'Voice message',
            style: AppTextStyles.body.copyWith(
              fontSize: 12.5,
              color: widget.isMine ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
