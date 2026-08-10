// screens/influencer/influencer_video_form_screen.dart
//
// Create or edit one influencer video — the mobile form for
// `InfluencerVideoModal.tsx`.
//
// WHAT THE PORTAL'S MODAL DOES, AND WHERE THIS DIFFERS
// ---------------------------------------------------
// Same four fields (title, description, video type, hashtags), same two files
// (video, optional thumbnail), same two gates before submit — "Please upload a
// video file" when creating without one, and "Please fill in all required fields"
// when title or type is missing (:112-118). Same write: `approval_status:
// 'pending'` on create *and* edit, `status` untouched.
//
// Three deliberate divergences, each with its reason at the point it happens:
//
//   1. The size gate is 50 MB, the bucket's real limit, not the modal's 200 MB
//      constant — see InfluencerMediaService.
//   2. Uploads go to `{uid}/videos/…`, because the live storage policy requires the
//      uid to be the first folder — also InfluencerMediaService.
//   3. There is no "publish to social" success step. `PublishToSocialButton` and
//      `RunAdButton` belong to the Meta integration, which this app does not have;
//      the form pops with a result instead, and the caller refreshes.
//
// Built from `portal_kit.dart` like the two existing wizards, so it reads as part
// of the same family rather than as a new dialect.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/constants/influencer_video_options.dart';
import '../../models/influencer_video_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/influencer_media_service.dart';
import '../../services/influencer_video_service.dart';
import '../post_property/portal_icon.dart';
import '../post_property/portal_kit.dart';
import '../post_property/portal_theme.dart';

/// Result handed back to whoever pushed the form, so a list can refresh without
/// re-querying on every pop.
enum InfluencerVideoFormResult { created, updated }

class InfluencerVideoFormScreen extends StatefulWidget {
  const InfluencerVideoFormScreen({
    super.key,
    this.editing,
    this.videoService,
    this.mediaService,
    this.picker,
  });

  /// The video being edited, or null when creating.
  ///
  /// The portal seeds its form from `editingVideo` the same way
  /// (InfluencerVideoModal.tsx:29-38), including keeping the existing media URLs as
  /// the previews so an edit that changes only the title re-uploads nothing.
  final InfluencerVideoModel? editing;

  @visibleForTesting
  final InfluencerVideoService? videoService;

  @visibleForTesting
  final InfluencerMediaService? mediaService;

  @visibleForTesting
  final ImagePicker? picker;

  @override
  State<InfluencerVideoFormScreen> createState() =>
      _InfluencerVideoFormScreenState();
}

class _InfluencerVideoFormScreenState extends State<InfluencerVideoFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _hashtags;

  late final InfluencerVideoService _service =
      widget.videoService ?? InfluencerVideoService();
  late final InfluencerMediaService _media =
      widget.mediaService ?? InfluencerMediaService();
  late final ImagePicker _picker = widget.picker ?? ImagePicker();

  String? _videoType;

  /// A newly picked file, or null when the stored URL still stands.
  File? _videoFile;
  File? _thumbnailFile;

  /// What the preview shows: a stored URL on an edit, a local path once picked.
  String _videoPreview = '';
  String _thumbnailPreview = '';

  bool _submitting = false;

  /// Shown under the submit button while an upload runs, so a 40 MB video does
  /// not look like a hang.
  String? _stage;

  /// Populated on a failed submit, rendered by [PortalValidationSummary] — the
  /// modal raises one toast per problem; a summary says all of them at once.
  List<String> _issues = const [];

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _title = TextEditingController(text: editing?.title ?? '');
    _description = TextEditingController(text: editing?.description ?? '');
    _hashtags = TextEditingController(
      text: joinInfluencerHashtags(editing?.hashtags ?? const []),
    );
    _videoType = editing?.videoType;
    _videoPreview = editing?.videoUrl ?? '';
    _thumbnailPreview = editing?.thumbnailUrl ?? '';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _hashtags.dispose();
    super.dispose();
  }

  // ── Picking ─────────────────────────────────────────────────────────────

  Future<void> _pickVideo() async {
    final XFile? picked =
        await _picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() {
      _videoFile = File(picked.path);
      _videoPreview = picked.path;
      // Picking a video answers the "upload a video" issue; leaving it listed
      // would be stale.
      _issues = const [];
    });
  }

  Future<void> _pickThumbnail() async {
    // The portal runs compressImage(file, {maxDimension: 1280, quality: 0.8})
    // after selection; image_picker does it during selection, which is how
    // ProfileMediaService handles the same step.
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _thumbnailFile = File(picked.path);
      _thumbnailPreview = picked.path;
    });
  }

  void _clearThumbnail() {
    setState(() {
      _thumbnailFile = null;
      _thumbnailPreview = '';
    });
  }

  // ── Submit ──────────────────────────────────────────────────────────────

  /// The modal's two pre-flight checks, in its order (:112-118).
  List<String> _validate() {
    final issues = <String>[];
    if (!_isEditing && _videoFile == null) {
      issues.add('Please upload a video file.');
    }
    if (_title.text.trim().isEmpty) {
      issues.add('A title is required.');
    }
    if (!isValidInfluencerVideoType(_videoType)) {
      issues.add('Choose a video type.');
    }
    return issues;
  }

  Future<void> _submit() async {
    final issues = _validate();
    if (issues.isNotEmpty) {
      setState(() => _issues = issues);
      return;
    }

    final userId = context.read<AuthProvider>().userId;
    if (userId == null) {
      setState(() => _issues = const ['Sign in again to publish this video.']);
      return;
    }

    setState(() {
      _submitting = true;
      _issues = const [];
      _stage = null;
    });

    try {
      // On an edit with no new file, the stored URL is reused untouched — the
      // portal's `let videoUrl = editingVideo?.video_url` (:128-130).
      String videoUrl = widget.editing?.videoUrl ?? '';
      if (_videoFile != null) {
        videoUrl = await _media.uploadVideo(
          file: _videoFile!,
          userId: userId,
          onProgress: (stage) {
            if (mounted) setState(() => _stage = stage);
          },
        );
      }

      String? thumbnailUrl = widget.editing?.thumbnailUrl;
      if (_thumbnailFile != null) {
        if (mounted) setState(() => _stage = 'Uploading thumbnail…');
        thumbnailUrl = await _media.uploadThumbnail(
          file: _thumbnailFile!,
          userId: userId,
        );
      } else if (_thumbnailPreview.isEmpty) {
        // Cleared deliberately. Null, not '', so the column reads as absent.
        thumbnailUrl = null;
      }

      if (mounted) setState(() => _stage = 'Saving…');

      final draft = InfluencerVideoDraft(
        title: _title.text.trim(),
        description: _description.text.trim(),
        videoType: _videoType!,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        hashtags: parseInfluencerHashtags(_hashtags.text),
      );

      if (_isEditing) {
        await _service.update(widget.editing!.id, draft);
      } else {
        await _service.create(draft, userId);
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        _isEditing
            ? InfluencerVideoFormResult.updated
            : InfluencerVideoFormResult.created,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _stage = null;
        // InfluencerMediaException and InfluencerVideoException both carry a
        // sentence meant for the user; anything else is shown as-is rather than
        // replaced with generic copy that hides the cause.
        _issues = [_message(e)];
      });
    }
  }

  static String _message(Object error) => switch (error) {
        InfluencerMediaException(:final message) => message,
        InfluencerVideoException(:final message) => message,
        _ => 'Could not save this video: $error',
      };

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalTheme.slate100,
      appBar: AppBar(
        backgroundColor: PortalTheme.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          _isEditing ? 'Edit Video' : 'Upload Video',
          style: PortalTheme.stepHeaderTitle,
        ),
        leading: IconButton(
          icon: const PortalIcon('x', size: 20, color: PortalTheme.slate700),
          onPressed: _submitting ? null : () => Navigator.pop(context),
          tooltip: 'Close',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            PortalStepHeader(
              icon: 'video',
              title: _isEditing ? 'Edit Video' : 'Upload Video',
              subtitle: _isEditing
                  // The portal's own wording for this outcome
                  // (InfluencerVideoModal.tsx:176).
                  ? 'Saving changes sends this video back for review'
                  : 'Share a video with your audience',
            ),
            const SizedBox(height: 20),

            if (_issues.isNotEmpty) ...[
              PortalValidationSummary(messages: _issues),
              const SizedBox(height: 16),
            ],

            // ── Media ──────────────────────────────────────────────────────
            PortalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PortalSectionDivider(icon: 'video', title: 'Media'),
                  const SizedBox(height: 14),
                  PortalLabelledField(
                    label: 'Video',
                    required: true,
                    helper: 'Compressed to 1080p before upload. '
                        'Maximum 50 MB after compression.',
                    child: _VideoPickerTile(
                      preview: _videoPreview,
                      isLocal: _videoFile != null,
                      enabled: !_submitting,
                      onPick: _pickVideo,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PortalLabelledField(
                    label: 'Thumbnail',
                    helper: 'Optional. A frame from the video is used if you '
                        'skip this.',
                    child: _ThumbnailPickerTile(
                      preview: _thumbnailPreview,
                      isLocal: _thumbnailFile != null,
                      enabled: !_submitting,
                      onPick: _pickThumbnail,
                      onClear: _clearThumbnail,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Type ───────────────────────────────────────────────────────
            PortalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PortalSectionDivider(
                    icon: 'type',
                    title: 'Video Type',
                  ),
                  const SizedBox(height: 4),
                  // A radio list, not a Select. The portal's SelectItem rows carry
                  // a title and a description each (:47-50), and a dropdown that
                  // collapses to one line would drop the descriptions.
                  for (final type in kInfluencerVideoTypes)
                    _TypeOption(
                      type: type,
                      selected: _videoType == type.id,
                      enabled: !_submitting,
                      onTap: () => setState(() {
                        _videoType = type.id;
                        _issues = const [];
                      }),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Details ────────────────────────────────────────────────────
            PortalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PortalSectionDivider(
                    icon: 'file-text',
                    title: 'Details',
                  ),
                  const SizedBox(height: 14),
                  PortalLabelledField(
                    label: 'Title',
                    required: true,
                    child: PortalTextField(
                      controller: _title,
                      hint: 'Give your video a title',
                      hasError: _issues.any((i) => i.contains('title')),
                      onChanged: (_) {
                        if (_issues.isNotEmpty) setState(() => _issues = const []);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  PortalLabelledField(
                    label: 'Description',
                    child: PortalTextField(
                      controller: _description,
                      hint: 'What is this video about?',
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PortalLabelledField(
                    label: 'Hashtags',
                    helper: 'Comma separated. The leading # is optional.',
                    child: PortalTextField(
                      controller: _hashtags,
                      hint: 'pune, 3bhk, newlaunch',
                      prefix: PortalIcon(
                        'hash',
                        size: 14,
                        color: PortalTheme.radioIdle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SubmitBar(
              label: _isEditing ? 'Save Changes' : 'Upload Video',
              submitting: _submitting,
              stage: _stage,
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Media tiles ─────────────────────────────────────────────────────────────

/// The video slot: empty prompt, or the chosen file's name with a swap action.
///
/// No inline playback. `video_player` would need a controller per state change and
/// a native surface the form does not otherwise require, and the portal's own
/// preview is a muted `<video>` the user cannot scrub either.
class _VideoPickerTile extends StatelessWidget {
  const _VideoPickerTile({
    required this.preview,
    required this.isLocal,
    required this.enabled,
    required this.onPick,
  });

  final String preview;
  final bool isLocal;
  final bool enabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final chosen = preview.isNotEmpty;

    return InkWell(
      onTap: enabled ? onPick : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: PortalTheme.cardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: chosen ? PortalTheme.accent : PortalTheme.cardBorder,
            style: chosen ? BorderStyle.solid : BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            PortalIcon(
              chosen ? 'play' : 'upload',
              size: 20,
              color: chosen ? PortalTheme.accent : PortalTheme.radioIdle,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chosen ? _fileLabel(preview) : 'Choose a video',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PortalTheme.inputText,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    chosen
                        ? (isLocal ? 'Ready to upload' : 'Current video')
                        : 'MP4, MOV or WEBM',
                    style: PortalTheme.helperText,
                  ),
                ],
              ),
            ),
            if (chosen)
              Text(
                'Change',
                style: PortalTheme.helperText
                    .copyWith(color: PortalTheme.accent),
              ),
          ],
        ),
      ),
    );
  }

  /// Last path segment, or a short label when the preview is a remote URL whose
  /// generated name would say nothing useful.
  static String _fileLabel(String preview) {
    if (preview.startsWith('http')) return 'Uploaded video';
    final separator = preview.lastIndexOf(RegExp(r'[/\\]'));
    return separator < 0 ? preview : preview.substring(separator + 1);
  }
}

/// The thumbnail slot: a 16:9 preview with a clear button, or an empty prompt.
class _ThumbnailPickerTile extends StatelessWidget {
  const _ThumbnailPickerTile({
    required this.preview,
    required this.isLocal,
    required this.enabled,
    required this.onPick,
    required this.onClear,
  });

  final String preview;
  final bool isLocal;
  final bool enabled;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (preview.isEmpty) {
      return InkWell(
        onTap: enabled ? onPick : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: PortalTheme.cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: PortalTheme.cardBorder),
          ),
          child: Row(
            children: [
              PortalIcon('image-plus',
                  size: 20, color: PortalTheme.radioIdle),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Choose a thumbnail',
                    style: PortalTheme.inputText),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: isLocal
                ? Image.file(File(preview), fit: BoxFit.cover)
                : Image.network(
                    preview,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => ColoredBox(
                      color: const Color(0xFFEEECF8),
                      child: Center(
                        child: PortalIcon('image',
                            size: 32, color: PortalTheme.radioIdle),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        // A Wrap: two TextButtons at 130% text exceed the 262 dp card column, and
        // stacking them reads better than shrinking the tap targets.
        Wrap(
          children: [
            TextButton(
              onPressed: enabled ? onPick : null,
              child: const Text('Replace'),
            ),
            TextButton(
              onPressed: enabled ? onClear : null,
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Remove'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Type option ─────────────────────────────────────────────────────────────

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final InfluencerVideoType type;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? PortalTheme.accent : PortalTheme.radioIdle,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(type.title, style: PortalTheme.inputText),
                  const SizedBox(height: 2),
                  Text(type.description, style: PortalTheme.helperText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Submit ──────────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.label,
    required this.submitting,
    required this.stage,
    required this.onSubmit,
  });

  final String label;
  final bool submitting;
  final String? stage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: submitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: PortalTheme.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  PortalTheme.accent.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(label, style: PortalTheme.navButton),
          ),
        ),
        if (stage != null) ...[
          const SizedBox(height: 8),
          Text(stage!, style: PortalTheme.helperText),
        ],
      ],
    );
  }
}
