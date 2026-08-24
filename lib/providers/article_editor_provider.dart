import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/utils/article_html.dart';
import '../models/article_model.dart';
import '../services/article_service.dart';

/// Why the editor is read-only, when it is.
enum ArticleLockReason {
  /// `approval_status` is not `pending`, so the RLS update policy would match
  /// zero rows.
  notPending,

  /// The stored HTML contains formatting the plain-text editor cannot
  /// represent; editing it here would strip the author's markup.
  richContent,
}

/// State for the Article Editor (blueprint §16.9).
///
/// Follows the shape of the other feature providers: a plain ChangeNotifier
/// over [ArticleService], loaded from the view's post-frame callback.
class ArticleEditorProvider extends ChangeNotifier {
  ArticleEditorProvider({
    required this.articleId,
    required this.userId,
    required this.userType,
    required this.authorName,
    required this.authorImageUrl,
    ArticleService? service,
  }) : _service = service ?? ArticleService();

  /// Null when composing a new article.
  final String? articleId;

  final String userId;
  final String? userType;
  final String authorName;
  final String? authorImageUrl;

  final ArticleService _service;

  // ── Form fields ───────────────────────────────────────────────────────────
  String title = '';
  String brief = '';

  /// Plain text. Converted to HTML on save via [plainTextToHtml].
  String body = '';

  String? category;
  String tags = '';
  String imageUrl = '';

  // ── Lifecycle state ───────────────────────────────────────────────────────
  bool _loading = false;
  bool _loadFailed = false;
  bool _saving = false;
  ArticleModel? _existing;
  ArticleLockReason? _lockReason;

  /// Set once a draft has been created, so a second save updates rather than
  /// inserting — the duplicate-article guard the web form documents.
  String? _persistedId;

  bool get loading => _loading;
  bool get loadFailed => _loadFailed;
  bool get saving => _saving;
  ArticleModel? get existing => _existing;
  ArticleLockReason? get lockReason => _lockReason;
  bool get isLocked => _lockReason != null;
  bool get isEditing => articleId != null;

  /// The id this draft was saved under, once a save has happened — the
  /// existing [articleId] when editing, or the id [_persist] just created.
  /// Null before the first successful save.
  String? get persistedId => _persistedId;

  bool get isAdmin {
    final type = userType?.toLowerCase();
    return type == 'admin' || type == 'super_admin';
  }

  /// Admins publish immediately; everyone else submits for review. The backend
  /// has no user-facing publish path, so the label must not promise one.
  String get primaryActionLabel => isAdmin ? 'Publish' : 'Submit for Review';

  int get readTime => estimateReadTime(body);

  List<String> get parsedTags =>
      tags.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();

  /// Mirrors the web form's submit guard: title, brief, content and category
  /// are all required.
  String? get validationError {
    if (title.trim().isEmpty) return 'Add a title.';
    if (brief.trim().isEmpty) return 'Add a brief.';
    if (body.trim().isEmpty) return 'Add some content.';
    if (category == null || category!.isEmpty) return 'Choose a category.';
    return null;
  }

  /// A draft needs far less — React autosaves as soon as a title and body
  /// exist.
  bool get canSaveDraft =>
      title.trim().isNotEmpty && body.trim().isNotEmpty && !_saving;

  bool get canSubmit => validationError == null && !_saving;

  // ── Loading ───────────────────────────────────────────────────────────────

  Future<void> load() async {
    final id = articleId;
    if (id == null) return;

    _loading = true;
    _loadFailed = false;
    notifyListeners();

    try {
      final article = await _service.getById(id);
      _existing = article;
      _persistedId = article.id;

      title = article.title;
      brief = article.brief;
      category = article.category;
      tags = article.tags.join(', ');
      imageUrl = article.imageUrl ?? '';

      if (!article.isEditable) {
        _lockReason = ArticleLockReason.notPending;
      } else if (isRichHtml(article.contentHtml)) {
        _lockReason = ArticleLockReason.richContent;
      }

      // Even when locked, the body is populated so the article can be read.
      body = htmlToPlainText(article.contentHtml);
    } catch (e) {
      debugPrint('ArticleEditorProvider.load failed: $e');
      _loadFailed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ── Field setters ─────────────────────────────────────────────────────────

  void setTitle(String value) {
    title = value;
    notifyListeners();
  }

  void setBrief(String value) {
    brief = value;
    notifyListeners();
  }

  void setBody(String value) {
    body = value;
    notifyListeners();
  }

  void setCategory(String? value) {
    category = value;
    notifyListeners();
  }

  void setTags(String value) {
    tags = value;
    notifyListeners();
  }

  void setImageUrl(String value) {
    imageUrl = value;
    notifyListeners();
  }

  // ── Saving ────────────────────────────────────────────────────────────────

  /// Saves without changing moderation state. Returns null on success or a
  /// message to show the user.
  Future<String?> saveDraft() => _persist(submitForReview: false);

  /// Submits for review (or publishes, for an admin).
  Future<String?> submit() {
    final invalid = validationError;
    if (invalid != null) return Future.value(invalid);
    return _persist(submitForReview: true);
  }

  Future<String?> _persist({required bool submitForReview}) async {
    if (_saving) return null;
    if (isLocked) return 'This article can no longer be edited.';

    _saving = true;
    notifyListeners();

    try {
      final contentHtml = plainTextToHtml(body);
      final existingId = _persistedId;

      // Slug is generated once and preserved across edits, matching the web
      // form's `editingArticle?.slug || generateSlug(title)`.
      final slug = _existing?.slug.isNotEmpty == true
          ? _existing!.slug
          : generateSlug(title.trim(), randomSuffix: _randomSuffix());

      if (existingId == null) {
        _persistedId = await _service.create(
          title: title.trim(),
          slug: slug,
          contentHtml: contentHtml,
          brief: brief.trim(),
          category: category,
          tags: parsedTags,
          imageUrl: imageUrl.trim().isEmpty ? null : imageUrl.trim(),
          authorName: authorName,
          authorImageUrl: authorImageUrl,
          readTime: readTime,
          userId: userId,
          userType: userType,
          isAdmin: isAdmin,
          submitForReview: submitForReview,
        );
      } else {
        await _service.update(
          id: existingId,
          title: title.trim(),
          slug: slug,
          contentHtml: contentHtml,
          brief: brief.trim(),
          category: category,
          tags: parsedTags,
          imageUrl: imageUrl.trim().isEmpty ? null : imageUrl.trim(),
          authorName: authorName,
          authorImageUrl: authorImageUrl,
          readTime: readTime,
          userId: userId,
          userType: userType,
          isAdmin: isAdmin,
          submitForReview: submitForReview,
        );
      }

      return null;
    } catch (e) {
      debugPrint('ArticleEditorProvider._persist failed: $e');
      return submitForReview
          ? 'Could not submit the article. Please try again.'
          : 'Could not save the draft. Please try again.';
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  /// Six lowercase alphanumerics, matching the web form's
  /// `Math.random().toString(36).substring(2, 8)`.
  String _randomSuffix() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
