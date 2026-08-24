import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../core/widgets/scale_tap.dart';
import '../../providers/article_editor_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/article_service.dart';
import '../social/create_campaign_dialog.dart';
import '../social/publish_everywhere_dialog.dart';
import 'widgets/article_form_field.dart';

/// Compose or edit an article (blueprint §16.9).
///
/// The content field is a plain multiline editor by decision — no rich-text
/// dependency this phase. It still honours the backend's HTML contract: the
/// text is converted to paragraph markup on save, and articles containing
/// richer web-authored markup open read-only rather than being flattened.
class ArticleEditorScreen extends StatelessWidget {
  /// Null to compose a new article.
  final String? articleId;

  const ArticleEditorScreen({super.key, this.articleId});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final userId = auth.userId;

    if (userId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ArticleEditorProvider(
        articleId: articleId,
        userId: userId,
        userType: auth.userType,
        authorName: auth.userName,
        authorImageUrl: auth.avatarUrl,
      )..load(),
      child: const _ArticleEditorView(),
    );
  }
}

class _ArticleEditorView extends StatefulWidget {
  const _ArticleEditorView();

  @override
  State<_ArticleEditorView> createState() => _ArticleEditorViewState();
}

class _ArticleEditorViewState extends State<_ArticleEditorView> {
  final _titleController = TextEditingController();
  final _briefController = TextEditingController();
  final _bodyController = TextEditingController();
  final _tagsController = TextEditingController();
  final _imageController = TextEditingController();

  bool _controllersSeeded = false;
  bool _previewing = false;

  @override
  void dispose() {
    _titleController.dispose();
    _briefController.dispose();
    _bodyController.dispose();
    _tagsController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  /// Copies loaded values into the controllers once, after the fetch lands.
  void _seedControllers(ArticleEditorProvider editor) {
    if (_controllersSeeded || editor.loading) return;
    _controllersSeeded = true;
    _titleController.text = editor.title;
    _briefController.text = editor.brief;
    _bodyController.text = editor.body;
    _tagsController.text = editor.tags;
    _imageController.text = editor.imageUrl;
  }

  Future<void> _saveDraft(ArticleEditorProvider editor) async {
    final error = await editor.saveDraft();
    if (!mounted) return;
    _showResult(error, successMessage: 'Draft saved.');
  }

  Future<void> _submit(ArticleEditorProvider editor) async {
    final wasNew = !editor.isEditing;
    final error = await editor.submit();
    if (!mounted) return;

    if (error == null) {
      _showResult(
        null,
        successMessage: editor.isAdmin
            ? 'Article published.'
            : 'Submitted for review. It will appear once approved.',
      );
      // Same trigger points as the portal's `ArticleWriteForm` success card
      // (`PublishToSocialButton` then `RunAdButton`) — offered only for a
      // brand-new article, not every subsequent edit save.
      if (wasNew) {
        await _offerPublish(editor);
        if (!mounted) return;
        await _offerBoost(editor);
      }
      if (!mounted) return;
      // Signal the caller (Profile → My Content) to refresh.
      Navigator.of(context).pop(true);
      return;
    }
    _showResult(error);
  }

  /// `contentType` is always `'article'`, matching the portal exactly: even
  /// `ArticleWriteForm`'s admin/Blog-manager mode hardcodes the literal string
  /// `"article"` in its own `PublishToSocialButton`/`RunAdButton` calls (the
  /// `'article' | 'blog'` distinction only selects which content *record*
  /// type is created, not the `SocialContentType` used for publish/boost).
  String get _socialContentType => 'article';

  Future<void> _offerPublish(ArticleEditorProvider editor) async {
    final userId = context.read<AuthProvider>().userId;
    final articleId = editor.persistedId;
    if (userId == null || articleId == null) return;
    await showPublishEverywhereDialog(
      context,
      userId: userId,
      contentType: _socialContentType,
      contentId: articleId,
      title: _titleController.text,
      mediaUrls: _imageController.text.trim().isEmpty
          ? const []
          : [_imageController.text.trim()],
    );
  }

  Future<void> _offerBoost(ArticleEditorProvider editor) async {
    final userId = context.read<AuthProvider>().userId;
    final articleId = editor.persistedId;
    if (userId == null || articleId == null) return;
    await offerBoostDialog(
      context,
      userId: userId,
      contentType: _socialContentType,
      contentId: articleId,
      title: _titleController.text,
      mediaUrls: _imageController.text.trim().isEmpty
          ? const []
          : [_imageController.text.trim()],
    );
  }

  void _showResult(String? error, {String? successMessage}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? successMessage ?? 'Done')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.watch<ArticleEditorProvider>();
    _seedControllers(editor);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(editor),
            Expanded(child: _buildBody(editor)),
          ],
        ),
      ),
      bottomNavigationBar: editor.loading || editor.loadFailed
          ? null
          : _buildActionBar(editor),
    );
  }

  Widget _buildHeader(ArticleEditorProvider editor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Semantics(
            label: 'Back',
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.cardBackground,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x141A1A2E),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back,
                  size: 18,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              editor.isEditing ? 'Edit Article' : 'Write New Article',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading2.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ArticleEditorProvider editor) {
    if (editor.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (editor.loadFailed) {
      return Center(
        child: EmptyStateView(
          icon: Icons.cloud_off_rounded,
          title: "Couldn't load this article",
          message: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: editor.load,
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        if (editor.existing != null) ...[
          _StatusBanner(editor: editor),
          const SizedBox(height: 18),
        ],
        ArticleFormField(
          label: 'Article Title',
          required: true,
          child: ArticleInputSurface(
            child: TextField(
              controller: _titleController,
              enabled: !editor.isLocked,
              onChanged: editor.setTitle,
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.body.copyWith(fontSize: 13.5),
              decoration: _inputDecoration('Enter article title'),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ArticleFormField(
          label: 'Brief / Excerpt',
          required: true,
          counter: '${editor.brief.length}/${ArticleService.briefMaxLength}',
          child: ArticleInputSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              controller: _briefController,
              enabled: !editor.isLocked,
              onChanged: editor.setBrief,
              minLines: 3,
              maxLines: 4,
              maxLength: ArticleService.briefMaxLength,
              // Hard limit matching the web form's maxLength={300}; the
              // counter above is the visible affordance.
              inputFormatters: [
                LengthLimitingTextInputFormatter(ArticleService.briefMaxLength),
              ],
              textCapitalization: TextCapitalization.sentences,
              style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.5),
              decoration: _inputDecoration(
                'A short summary that appears in listings...',
              ).copyWith(counterText: ''),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _buildContentField(editor),
        const SizedBox(height: 18),
        _buildCategoryField(editor),
        const SizedBox(height: 18),
        ArticleFormField(
          label: 'Tags',
          child: ArticleInputSurface(
            child: TextField(
              controller: _tagsController,
              enabled: !editor.isLocked,
              onChanged: editor.setTags,
              style: AppTextStyles.body.copyWith(fontSize: 13.5),
              decoration: _inputDecoration(
                'e.g. real estate, investment, tips',
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        ArticleFormField(
          label: 'Featured Image URL',
          child: ArticleInputSurface(
            child: TextField(
              controller: _imageController,
              enabled: !editor.isLocked,
              onChanged: editor.setImageUrl,
              keyboardType: TextInputType.url,
              style: AppTextStyles.body.copyWith(fontSize: 13.5),
              decoration: _inputDecoration('https://example.com/image.jpg'),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          // The web form is a URL field too — there is no upload path for
          // article images on either platform.
          'Paste a link to an image. Uploading from the device is not '
          'supported yet.',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildContentField(ArticleEditorProvider editor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ArticleFormField(
          label: 'Content',
          required: true,
          counter: '${editor.readTime} min read',
          child: ArticleInputSurface(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: _previewing
                ? _ContentPreview(text: editor.body)
                : TextField(
                    controller: _bodyController,
                    enabled: !editor.isLocked,
                    onChanged: editor.setBody,
                    minLines: 10,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      height: 1.6,
                    ),
                    decoration: _inputDecoration(
                      'Start writing your article...',
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Plain text for now. Leave a blank line between paragraphs — '
          'formatting tools are coming.',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: AppColors.textHint,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryField(ArticleEditorProvider editor) {
    return ArticleFormField(
      label: 'Category',
      required: true,
      child: ArticleInputSurface(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: editor.category,
            isExpanded: true,
            hint: Text(
              'Select a category',
              style: AppTextStyles.body.copyWith(
                fontSize: 13.5,
                color: AppColors.textHint,
              ),
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
            ),
            style: AppTextStyles.body.copyWith(fontSize: 13.5),
            // The seven values the web form offers, verbatim.
            items: [
              for (final option in ArticleService.categories)
                DropdownMenuItem(value: option, child: Text(option)),
            ],
            onChanged: editor.isLocked ? null : editor.setCategory,
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      isDense: true,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      filled: false,
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(
        fontSize: 13.5,
        color: AppColors.textHint,
      ),
    );
  }

  Widget _buildActionBar(ArticleEditorProvider editor) {
    if (editor.isLocked) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          boxShadow: [
            BoxShadow(
              color: Color(0x0F1A1A2E),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              editor.lockReason == ArticleLockReason.richContent
                  ? 'This article was written on the web. Open it there to '
                        'edit without losing its formatting.'
                  : 'This article is already under review and can no longer '
                        'be edited.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F1A1A2E),
            blurRadius: 12,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: _BarButton(
                  label: 'Save Draft',
                  style: _BarButtonStyle.outlined,
                  enabled: editor.canSaveDraft,
                  onTap: () => _saveDraft(editor),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BarButton(
                  label: _previewing ? 'Edit' : 'Preview',
                  style: _BarButtonStyle.tonal,
                  enabled: !editor.saving,
                  onTap: () => setState(() => _previewing = !_previewing),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BarButton(
                  // "Submit for Review" for everyone but an admin: the backend
                  // writes draft/pending for non-admins, so a "Publish" label
                  // would promise something it cannot do.
                  label: editor.primaryActionLabel,
                  style: _BarButtonStyle.filled,
                  enabled: editor.canSubmit,
                  busy: editor.saving,
                  onTap: () => _submit(editor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Moderation state for an article being edited.
class _StatusBanner extends StatelessWidget {
  final ArticleEditorProvider editor;

  const _StatusBanner({required this.editor});

  @override
  Widget build(BuildContext context) {
    final article = editor.existing!;
    final approval = (article.approvalStatus ?? 'pending').toLowerCase();

    final (Color fg, Color bg, IconData icon) = switch (approval) {
      'approved' => (
        AppColors.success,
        const Color(0x1A22C55E),
        Icons.check_circle_outline,
      ),
      'rejected' => (
        AppColors.error,
        const Color(0x1AEF4444),
        Icons.error_outline,
      ),
      _ => (AppColors.warning, const Color(0x1AF97316), Icons.schedule),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  article.statusLabel,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
                if (approval == 'rejected' &&
                    (article.rejectionReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    article.rejectionReason!,
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Read-only rendering of the composed paragraphs.
class _ContentPreview extends StatelessWidget {
  final String text;

  const _ContentPreview({required this.text});

  @override
  Widget build(BuildContext context) {
    final paragraphs = text
        .trim()
        .split(RegExp(r'\n[ \t]*\n+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (paragraphs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'Nothing to preview yet',
            style: AppTextStyles.caption.copyWith(fontSize: 12.5),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final paragraph in paragraphs) ...[
            Text(
              paragraph,
              style: AppTextStyles.body.copyWith(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

enum _BarButtonStyle { filled, tonal, outlined }

class _BarButton extends StatelessWidget {
  final String label;
  final _BarButtonStyle style;
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  const _BarButton({
    required this.label,
    required this.style,
    required this.enabled,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final isFilled = style == _BarButtonStyle.filled;

    final background = switch (style) {
      _BarButtonStyle.filled => AppColors.primary,
      _BarButtonStyle.tonal => AppColors.primaryLight,
      _BarButtonStyle.outlined => Colors.transparent,
    };

    final foreground = isFilled ? Colors.white : AppColors.primary;

    return Semantics(
      label: label,
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: ScaleTap(
          onTap: enabled && !busy ? onTap : null,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
              border: style == _BarButtonStyle.outlined
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : null,
              boxShadow: isFilled && enabled
                  ? AppColors.primaryActionShadow
                  : null,
            ),
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.button.copyWith(
                        fontSize: 13,
                        color: foreground,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
