import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../models/chat_message.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_thread_provider.dart';
import '../../services/chat_media_service.dart';
import '../../services/messaging_service.dart';
import 'channel_settings_screen.dart';
import 'widgets/chat_avatar.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/forward_message_sheet.dart';
import 'widgets/message_composer.dart';
import 'widgets/relative_time.dart';
import 'widgets/share_property_sheet.dart';

/// A single conversation, 1:1 or channel (blueprint §16.7 and §16.8).
///
/// One screen serves both. §16.8 suggests a shared base widget rather than
/// duplicating the thread; parameterising the single screen by
/// [ChatThreadKind] achieves that with no second class to keep in sync — the
/// only differences are which table is read (owned by [ChatThreadProvider])
/// and whether bubbles are attributed to a sender.
class ChatThreadScreen extends StatelessWidget {
  final ChatThreadKind kind;
  final String threadId;
  final String title;

  /// Secondary header line — a member count for channels. Nothing is shown for
  /// 1:1 threads: the prototype's "Online" label has no reliable presence
  /// source (see the note on ConversationTile).
  final String? subtitle;

  final String? avatarUrl;
  final String initials;

  /// The other person in a 1:1 thread, when known — makes the header's avatar and
  /// title open their public profile.
  final String? participantUserId;

  /// The signed-in user's own `request_status` for this conversation —
  /// `'pending'` swaps the composer for an Accept/Decline banner until it's
  /// accepted. Always `'accepted'` for a thread the user just started
  /// themselves and for channels.
  final String requestStatus;

  final bool isMuted;

  /// Whether the current user is `admin` on this channel — irrelevant for
  /// 1:1 threads. Gates the role-management controls in
  /// [ChannelSettingsScreen], not visibility of the settings screen itself.
  final bool isChannelAdmin;

  const ChatThreadScreen({
    super.key,
    required this.kind,
    required this.threadId,
    required this.title,
    required this.initials,
    this.subtitle,
    this.avatarUrl,
    this.participantUserId,
    this.requestStatus = 'accepted',
    this.isMuted = false,
    this.isChannelAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().userId;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Never treat "yourself" as a blockable/tappable participant; a channel
    // passes null already.
    final resolvedParticipantId =
        participantUserId == userId ? null : participantUserId;

    return ChangeNotifierProvider(
      create: (_) => ChatThreadProvider(
        kind: kind,
        threadId: threadId,
        userId: userId,
        participantUserId: resolvedParticipantId,
      )..load(),
      child: _ChatThreadView(
        title: title,
        subtitle: subtitle,
        avatarUrl: avatarUrl,
        initials: initials,
        currentUserId: userId,
        participantUserId: resolvedParticipantId,
        initialRequestStatus: requestStatus,
        initialIsMuted: isMuted,
        isChannelAdmin: isChannelAdmin,
      ),
    );
  }
}

class _ChatThreadView extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? avatarUrl;
  final String initials;
  final String currentUserId;
  final String? participantUserId;
  final String initialRequestStatus;
  final bool initialIsMuted;
  final bool isChannelAdmin;

  const _ChatThreadView({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    required this.currentUserId,
    required this.initialRequestStatus,
    required this.initialIsMuted,
    required this.isChannelAdmin,
    this.participantUserId,
  });

  @override
  State<_ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends State<_ChatThreadView> {
  final ScrollController _scrollController = ScrollController();
  final _service = MessagingService();
  final _imagePicker = ImagePicker();
  final _recorder = FlutterSoundRecorder();

  late String _requestStatus = widget.initialRequestStatus;
  late bool _isMuted = widget.initialIsMuted;
  bool _requestActionInFlight = false;
  bool _recorderOpen = false;
  bool _isRecording = false;
  DateTime? _recordingStartedAt;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  bool _searching = false;
  bool _searchLoading = false;
  List<ChatMessage> _searchResults = const [];

  bool get _isPendingRequest => _requestStatus == 'pending';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    if (_recorderOpen) _recorder.closeRecorder();
    super.dispose();
  }

  void _toggleSearch(ChatThreadProvider thread) {
    setState(() {
      _searching = !_searching;
      if (!_searching) {
        _searchController.clear();
        _searchResults = const [];
      }
    });
  }

  void _onSearchChanged(String value, ChatThreadProvider thread) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _runSearch(value, thread),
    );
  }

  Future<void> _runSearch(String term, ChatThreadProvider thread) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }
    setState(() => _searchLoading = true);
    try {
      final results = await _service.searchMessagesInThread(
        threadId: thread.threadId,
        isChannel: thread.isChannel,
        term: trimmed,
      );
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  /// The list is `reverse: true` (anchored to the newest message), so
  /// "scrolled near the top of the conversation" is the *maximum* scroll
  /// extent, not zero.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<ChatThreadProvider>().loadMore();
    }
  }

  Future<void> _acceptRequest() async {
    setState(() => _requestActionInFlight = true);
    try {
      await _service.acceptConversationRequest(
        context.read<ChatThreadProvider>().threadId,
      );
      if (mounted) setState(() => _requestStatus = 'accepted');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't accept the request.")),
        );
      }
    } finally {
      if (mounted) setState(() => _requestActionInFlight = false);
    }
  }

  Future<void> _declineRequest() async {
    setState(() => _requestActionInFlight = true);
    try {
      await _service.hideConversation(
        context.read<ChatThreadProvider>().threadId,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't decline the request.")),
        );
      }
      if (mounted) setState(() => _requestActionInFlight = false);
    }
  }

  Future<void> _toggleMute() async {
    final thread = context.read<ChatThreadProvider>();
    final next = !_isMuted;
    try {
      if (thread.isChannel) {
        await _service.setChannelMuted(thread.threadId, next);
      } else {
        await _service.setConversationMuted(thread.threadId, next);
      }
      if (mounted) setState(() => _isMuted = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't update mute setting.")),
        );
      }
    }
  }

  void _openChannelSettings(ChatThreadProvider thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChannelSettingsScreen(
          channelId: thread.threadId,
          channelName: widget.title,
          currentUserId: widget.currentUserId,
          isAdmin: widget.isChannelAdmin,
        ),
      ),
    );
  }

  /// Blocking/unblocking now lives on the provider (`isBlockedByMe`,
  /// `blockParticipant`/`unblockParticipant`) so the composer-disable and
  /// banner below can react to the same state a thread reload also
  /// refreshes — the screen stays open afterward (it used to pop on block,
  /// which meant you could never see the resulting disabled/banner state).
  Future<void> _blockParticipant(ChatThreadProvider thread) async {
    final confirmed = await _confirm(
      title: 'Block this person?',
      message: "You won't be able to message each other anymore.",
      confirmLabel: 'Block',
    );
    if (confirmed != true || !mounted) return;
    final error = await thread.blockParticipant();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _unblockParticipant(ChatThreadProvider thread) async {
    final error = await thread.unblockParticipant();
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditDialog(ChatThreadProvider thread, ChatMessage message) async {
    final controller = TextEditingController(text: message.content);
    final newText = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, autofocus: true, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newText == null || newText.trim().isEmpty || !mounted) return;
    final error = await thread.editMessage(message.id, newText);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _confirmDeleteForMe(ChatThreadProvider thread, String id) async {
    final ok = await _confirm(
      title: 'Delete for me?',
      message: 'This only removes it from your view.',
      confirmLabel: 'Delete',
    );
    if (ok != true) return;
    final error = await thread.deleteForMe(id);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _confirmDeleteForEveryone(
    ChatThreadProvider thread,
    String id,
  ) async {
    final ok = await _confirm(
      title: 'Delete for everyone?',
      message: 'Everyone in this conversation will see it was deleted.',
      confirmLabel: 'Delete',
    );
    if (ok != true) return;
    final error = await thread.deleteForEveryone(id);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  /// The single attach button's menu — camera/gallery for images, plus
  /// "Share property" (the composer has no separate room for a dedicated
  /// property button, so it lives here rather than crowding the input row).
  Future<void> _openAttachMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.of(sheetContext).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetContext).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.home_work_outlined),
              title: const Text('Share property'),
              onTap: () => Navigator.of(sheetContext).pop('property'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'camera' || choice == 'gallery') {
      await _pickAndSendImage(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
    } else if (choice == 'property') {
      await _shareProperty();
    }
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await readFileBytes(picked.path);
    final ext = picked.path.split('.').last;
    final thread = context.read<ChatThreadProvider>();
    final error = await thread.sendImage(bytes, ext);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _shareProperty() async {
    final property = await showSharePropertySheet(context);
    if (property == null || !mounted) return;

    final thread = context.read<ChatThreadProvider>();
    final error = await thread.sharePropertyFromPicker(property);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    final targetId = await showForwardMessageSheet(context, widget.currentUserId);
    if (targetId == null || !mounted) return;

    try {
      await _service.forwardMessage(
        targetConversationId: targetId,
        senderId: widget.currentUserId,
        message: message,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message forwarded.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't forward the message.")),
        );
      }
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _stopAndSendRecording();
    } else {
      await _startRecording();
    }
  }

  /// Runtime mic-permission request, distinguishing granted/denied/
  /// permanently-denied — the static `AndroidManifest.xml` `RECORD_AUDIO`
  /// declaration (left untouched) only makes the permission requestable; it
  /// doesn't drive the actual in-app prompt or tell us which of these three
  /// states we're in.
  Future<bool> _ensureMicPermission() async {
    var status = await Permission.microphone.status;
    debugPrint('[Voice] permission status (initial): $status');

    if (status.isGranted) return true;

    if (status.isDenied) {
      status = await Permission.microphone.request();
      debugPrint('[Voice] permission status (after request): $status');
    }

    if (status.isGranted) return true;

    if (!mounted) return false;

    if (status.isPermanentlyDenied || status.isRestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Microphone access is turned off for this app.',
          ),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required to record a voice message.'),
        ),
      );
    }
    return false;
  }

  Future<void> _startRecording() async {
    final granted = await _ensureMicPermission();
    if (!granted || !mounted) return;

    try {
      if (!_recorderOpen) {
        await _recorder.openRecorder();
        _recorderOpen = true;
        debugPrint('[Voice] recorder opened');
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/voice_${DateTime.now().microsecondsSinceEpoch}.wav';
      // pcm16WAV is the only codec proven to actually write bytes to disk on
      // this flutter_sound build (see voice_agent/services/speech_service.dart)
      // — aacMP4 silently produces an empty file here. 16kHz mono keeps a
      // full 5-minute recording under the portal's 10MB voice-note limit.
      await _recorder.startRecorder(
        toFile: path,
        codec: Codec.pcm16WAV,
        sampleRate: 16000,
        numChannels: 1,
      );
      _recordingStartedAt = DateTime.now();
      debugPrint('[Voice] recording started');
      setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('[Voice] start failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't start recording.")),
        );
      }
    }
  }

  Future<void> _stopAndSendRecording() async {
    final thread = context.read<ChatThreadProvider>();
    final startedAt = _recordingStartedAt;

    String? path;
    try {
      path = await _recorder.stopRecorder();
      debugPrint('[Voice] recording stopped');
    } catch (e) {
      debugPrint('[Voice] stop failed: $e');
    } finally {
      if (mounted) setState(() => _isRecording = false);
    }

    if (path == null || startedAt == null) {
      debugPrint('[Voice] no file produced, nothing to send');
      return;
    }

    final duration = DateTime.now().difference(startedAt);

    try {
      final bytes = await readFileBytes(path);
      debugPrint('[Voice] file size: ${bytes.lengthInBytes} bytes');

      if (bytes.isEmpty) {
        debugPrint('[Voice] zero-byte recording, rejecting');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("That recording didn't capture any audio. Please try again."),
            ),
          );
        }
        return;
      }

      debugPrint('[Voice] upload starting');
      final error = await thread.sendVoiceNote(bytes, 'wav', duration);
      if (error != null) {
        debugPrint('[Voice] upload/send failed: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
      } else {
        debugPrint('[Voice] upload/send succeeded');
      }
    } catch (e) {
      debugPrint('[Voice] reading/sending recording failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't send the voice message.")),
        );
      }
    } finally {
      try {
        await File(path).delete();
      } catch (_) {
        // Best-effort cleanup of the temp recording file.
      }
    }
  }

  Future<void> _reportMessage(ChatMessage message, String surface) async {
    const reasons = ['spam', 'harassment', 'nudity', 'scam', 'hate', 'violence', 'other'];
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons
              .map(
                (r) => ListTile(
                  title: Text(r[0].toUpperCase() + r.substring(1)),
                  onTap: () => Navigator.of(sheetContext).pop(r),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (reason == null || widget.participantUserId == null) return;
    try {
      await _service.reportMessage(
        messageId: message.id,
        surface: surface,
        reportedUserId: message.senderId,
        reason: reason,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report submitted.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't submit the report.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final thread = context.watch<ChatThreadProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _Header(
            title: widget.title,
            subtitle: thread.otherTyping ? 'typing…' : widget.subtitle,
            isTyping: thread.otherTyping,
            avatarUrl: widget.avatarUrl,
            initials: widget.initials,
            participantUserId: widget.participantUserId,
            isMuted: _isMuted,
            onToggleMute: _toggleMute,
            isBlockedByMe: thread.isBlockedByMe,
            onBlock: widget.participantUserId == null
                ? null
                : () => _blockParticipant(thread),
            onUnblock: widget.participantUserId == null
                ? null
                : () => _unblockParticipant(thread),
            onOpenChannelSettings:
                thread.isChannel ? () => _openChannelSettings(thread) : null,
            onToggleSearch: () => _toggleSearch(thread),
            searching: _searching,
          ),
          if (_searching) _buildSearchBar(thread),
          Expanded(
            child: DecoratedBox(
              // Soft, modern chat-canvas tint (WhatsApp/Telegram-style) in
              // place of a flat background — purely decorative, sits behind
              // the message list only; header and composer keep their own
              // opaque surface color above/below it.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryLight.withValues(alpha: 0.35),
                    AppColors.background,
                  ],
                ),
              ),
              child: _searching ? _buildSearchResults() : _buildBody(context, thread),
            ),
          ),
          if (_isPendingRequest)
            _RequestBanner(
              name: widget.title,
              busy: _requestActionInFlight,
              onAccept: _acceptRequest,
              onDecline: _declineRequest,
            )
          else if (thread.isBlockedByMe)
            _BlockedBanner(
              name: widget.title,
              busy: thread.blockActionInFlight,
              onUnblock: () => _unblockParticipant(thread),
            )
          else
            MessageComposer(
              sending: thread.sending || thread.uploadingMedia,
              onSend: thread.send,
              replyingTo: thread.replyingTo,
              replyingToSenderName: thread.replyingTo == null
                  ? null
                  : (thread.replyingTo!.senderId == widget.currentUserId
                      ? 'yourself'
                      : (thread.isChannel
                          ? thread.senderFor(thread.replyingTo!.senderId)?.displayName
                          : widget.title)),
              onCancelReply: () => thread.setReplyTo(null),
              onTyping: thread.notifyTyping,
              onAttach: thread.uploadingMedia ? null : _openAttachMenu,
              onRecordVoice: thread.uploadingMedia ? null : _toggleVoiceRecording,
              isRecordingVoice: _isRecording,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ChatThreadProvider thread) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: AppColors.cardBackground,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppConstants.pillRadius),
              ),
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => _onSearchChanged(value, thread),
                style: AppTextStyles.body.copyWith(fontSize: 13),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search in this conversation…',
                  hintStyle: AppTextStyles.body.copyWith(fontSize: 13, color: AppColors.textHint),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: EmptyStateView(
          icon: Icons.search,
          title: 'Search this conversation',
          message: 'Matches from the entire thread, not just what\'s loaded.',
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: EmptyStateView(
          icon: Icons.search_off_rounded,
          title: 'No matches',
          message: 'No messages match your search.',
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      itemCount: _searchResults.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final message = _searchResults[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.displayContent,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.body.copyWith(fontSize: 13.5),
              ),
              const SizedBox(height: 3),
              Text(
                formatClockTime(message.createdAt),
                style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textHint),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ChatThreadProvider thread) {
    if (thread.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (thread.failed && thread.messages.isEmpty) {
      return Center(
        child: EmptyStateView(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load messages",
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: thread.refresh,
        ),
      );
    }

    if (thread.messages.isEmpty) {
      return const Center(
        child: EmptyStateView(
          icon: Icons.chat_bubble_outline,
          title: 'No messages yet',
          message: 'Say hello to start the conversation.',
        ),
      );
    }

    // `reverse: true` anchors the list to the newest message and keeps it
    // pinned when the keyboard opens, so no scroll controller is needed for
    // that; the same controller doubles as the pagination trigger above.
    final ordered = thread.messages.reversed.toList();
    final surface = thread.isChannel ? 'channel' : 'dm';

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: ordered.length + (thread.hasMoreOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == ordered.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final message = ordered[index];
        final isMine = message.senderId == widget.currentUserId;
        final replied = thread.repliedMessage(message.replyToId);

        return ChatBubble(
          message: message,
          isMine: isMine,
          currentUserId: widget.currentUserId,
          surface: surface,
          senderName: thread.isChannel && !isMine
              ? thread.senderFor(message.senderId)?.displayName
              : null,
          repliedMessage: replied,
          repliedSenderName: replied == null
              ? null
              : (replied.senderId == widget.currentUserId
                  ? 'You'
                  : (thread.isChannel
                      ? thread.senderFor(replied.senderId)?.displayName
                      : widget.title)),
          reactions: thread.reactionsFor(message.id),
          sharedProperty: thread.sharedPropertyFor(message.propertyId),
          onForward: !message.isDeleted &&
                  (message.messageType == 'text' || message.isPropertyShare)
              ? () => _forwardMessage(message)
              : null,
          onReact: (emoji) async {
            final error = await thread.toggleReaction(message.id, emoji);
            if (error != null && mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(error)));
            }
          },
          onReply: () => thread.setReplyTo(message),
          onEdit: isMine ? () => _showEditDialog(thread, message) : null,
          onDeleteForMe: () => _confirmDeleteForMe(thread, message.id),
          onDeleteForEveryone:
              isMine ? () => _confirmDeleteForEveryone(thread, message.id) : null,
          onReport: isMine ? null : () => _reportMessage(message, surface),
        );
      },
    );
  }
}

/// Accept/Decline banner shown in place of the composer while the caller's
/// own `request_status` is `'pending'` — matches the portal's exact flow:
/// accept flips the status, decline hides the conversation for this user only
/// (the sender is never notified).
class _RequestBanner extends StatelessWidget {
  final String name;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestBanner({
    required this.name,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: Color(0xFFEDEDF2))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$name wants to send you a message',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onDecline,
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: busy ? null : onAccept,
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the composer while [ChatThreadProvider.isBlockedByMe] —
/// covers the send/attach/mic/property-share disabling in one place, since
/// none of those controls render at all when this banner does.
class _BlockedBanner extends StatelessWidget {
  final String name;
  final bool busy;
  final VoidCallback onUnblock;

  const _BlockedBanner({
    required this.name,
    required this.busy,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: Color(0xFFEDEDF2))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 16, color: AppColors.textHint),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    "You've blocked $name",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onUnblock,
                child: Text(busy ? 'Unblocking…' : 'Unblock'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isTyping;
  final String? avatarUrl;
  final String initials;
  final String? participantUserId;
  final bool isMuted;
  final VoidCallback onToggleMute;
  final bool isBlockedByMe;
  final VoidCallback? onBlock;
  final VoidCallback? onUnblock;
  final VoidCallback? onOpenChannelSettings;
  final VoidCallback? onToggleSearch;
  final bool searching;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.avatarUrl,
    required this.initials,
    required this.isMuted,
    required this.onToggleMute,
    this.isTyping = false,
    this.isBlockedByMe = false,
    this.participantUserId,
    this.onBlock,
    this.onUnblock,
    this.onOpenChannelSettings,
    this.onToggleSearch,
    this.searching = false,
  });

  void _openProfile(BuildContext context) {
    final userId = participantUserId;
    if (userId == null || userId.isEmpty) return;

    Navigator.pushNamed(
      context,
      AppConstants.publicProfileScreen,
      arguments: {'userId': userId},
    );
  }

  Widget _maybeTappable(
    BuildContext context, {
    required String semanticLabel,
    required Widget child,
  }) {
    if (participantUserId == null || participantUserId!.isEmpty) return child;

    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openProfile(context),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Row(
            children: [
              Semantics(
                label: 'Back',
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      Icons.arrow_back,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _maybeTappable(
                context,
                semanticLabel: "Open $title's profile",
                child: ChatAvatar(
                  avatarUrl: avatarUrl,
                  initials: initials,
                  size: 40,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _maybeTappable(
                  context,
                  semanticLabel: "Open $title's profile",
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11.5,
                            fontStyle: isTyping ? FontStyle.italic : FontStyle.normal,
                            fontWeight:
                                isTyping ? FontWeight.w600 : FontWeight.normal,
                            color: isTyping
                                ? AppColors.primary
                                : AppColors.textHint,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (onToggleSearch != null)
                Semantics(
                  label: searching ? 'Close search' : 'Search this conversation',
                  button: true,
                  child: IconButton(
                    onPressed: onToggleSearch,
                    icon: Icon(
                      searching ? Icons.close : Icons.search,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textPrimary),
                onSelected: (value) {
                  if (value == 'mute') onToggleMute();
                  if (value == 'block') onBlock?.call();
                  if (value == 'unblock') onUnblock?.call();
                  if (value == 'channel_settings') onOpenChannelSettings?.call();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'mute',
                    child: Row(
                      children: [
                        Icon(isMuted ? Icons.notifications_off : Icons.notifications_none, size: 18),
                        const SizedBox(width: 8),
                        Text(isMuted ? 'Unmute' : 'Mute'),
                      ],
                    ),
                  ),
                  if (onOpenChannelSettings != null)
                    const PopupMenuItem(
                      value: 'channel_settings',
                      child: Row(
                        children: [
                          Icon(Icons.group_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Channel settings'),
                        ],
                      ),
                    ),
                  if (isBlockedByMe && onUnblock != null)
                    const PopupMenuItem(
                      value: 'unblock',
                      child: Row(
                        children: [
                          Icon(Icons.block_flipped, size: 18),
                          SizedBox(width: 8),
                          Text('Unblock user'),
                        ],
                      ),
                    )
                  else if (!isBlockedByMe && onBlock != null)
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Block user', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
