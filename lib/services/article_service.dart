import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/article_model.dart';
import '../models/article_summary.dart';

/// Read and write access to the current user's own `cms_posts` submissions.
///
/// The list method backs the Profile screen's My Content → Articles tab; the
/// fetch/create/update methods back the Article Editor (blueprint §16.9).
class ArticleService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// The seven categories offered by the web form.
  ///
  /// Copied verbatim from `CATEGORIES` in ArticleWriteForm.tsx — the column is
  /// free-text, so this list is the only thing keeping mobile submissions
  /// consistent with the web app's taxonomy. Never invent a value here.
  static const List<String> categories = [
    'Market Trends',
    'Investment Tips',
    'Legal Updates',
    'Property Guide',
    'Interior Design',
    'Finance',
    'Other',
  ];

  /// Maximum brief length, matching the web form's `maxLength={300}`.
  static const int briefMaxLength = 300;

  /// The user's own submitted articles, newest first.
  ///
  /// Mirrors ProfileDashboardShell.tsx's `fetchUserArticles` — see blueprint
  /// §9. Same table, same filter (`submitted_by`), same ordering, same
  /// 10-row limit.
  ///
  /// One deliberate difference: `approval_status` is added to the column list.
  /// React's profile query selects only `status`, but blueprint §16.4 requires
  /// the tab to surface moderation state, and the column is part of the same
  /// row — no extra round-trip, no new access.
  Future<List<ArticleSummary>> listOwn(String userId) async {
    try {
      final rows = await _supabase
          .from('cms_posts')
          .select(
            'id, title, featured_image_url, cover_image, slug, status, '
            'approval_status, created_at',
          )
          .eq('submitted_by', userId)
          .order('created_at', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(rows as List)
          .map(ArticleSummary.fromSupabase)
          .toList();
    } catch (e) {
      debugPrint('ArticleService.listOwn failed: $e');
      rethrow;
    }
  }

  /// Full row for the editor.
  ///
  /// Mirrors the `loadFullArticle` effect in ArticleWriteForm.tsx, which
  /// re-fetches every column because the list view only selected a few.
  Future<ArticleModel> getById(String id) async {
    try {
      final row = await _supabase
          .from('cms_posts')
          .select('*')
          .eq('id', id)
          .single();

      return ArticleModel.fromSupabase(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('ArticleService.getById failed: $e');
      rethrow;
    }
  }

  /// The column set shared by every insert and update.
  ///
  /// Mirrors the `payload` object in ArticleWriteForm.tsx exactly, including
  /// its mirrored pairs: `content`/`content_html` both receive the same HTML,
  /// as do `excerpt`/`brief` and `featured_image_url`/`cover_image`.
  ///
  /// `seo_title` / `seo_description` are sent as null because those inputs are
  /// blog-only on the web and are not part of the article form.
  Map<String, dynamic> _buildPayload({
    required String title,
    required String slug,
    required String contentHtml,
    required String brief,
    required String? category,
    required List<String> tags,
    required String? imageUrl,
    required String authorName,
    required String? authorImageUrl,
    required int readTime,
    required String userId,
    required String? userType,
  }) {
    return {
      'title': title,
      'slug': slug,
      'content': contentHtml,
      'content_html': contentHtml,
      'excerpt': brief,
      'brief': brief,
      'category': category,
      'tags': tags,
      'featured_image_url': imageUrl,
      'cover_image': imageUrl,
      'author_name': authorName,
      'author_image_url': authorImageUrl,
      'read_time': readTime,
      'submitted_by': userId,
      'submitted_by_type': userType,
      'content_type': 'article',
      'seo_title': null,
      'seo_description': null,
    };
  }

  /// Creates a new article row and returns its id.
  ///
  /// [submitForReview] false writes the draft state React's autosave uses for
  /// a brand-new row (`status: 'draft'`, `approval_status: 'pending'`).
  /// True applies the submit branch: admins are auto-approved and published,
  /// everyone else stays `draft` / `pending` — there is no user-facing publish
  /// in this backend.
  Future<String> create({
    required String title,
    required String slug,
    required String contentHtml,
    required String brief,
    required String? category,
    required List<String> tags,
    required String? imageUrl,
    required String authorName,
    required String? authorImageUrl,
    required int readTime,
    required String userId,
    required String? userType,
    required bool isAdmin,
    required bool submitForReview,
  }) async {
    try {
      final payload = _buildPayload(
        title: title,
        slug: slug,
        contentHtml: contentHtml,
        brief: brief,
        category: category,
        tags: tags,
        imageUrl: imageUrl,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        readTime: readTime,
        userId: userId,
        userType: userType,
      );

      payload.addAll(_statusFields(
        isAdmin: isAdmin,
        submitForReview: submitForReview,
      ));

      final rows =
          await _supabase.from('cms_posts').insert(payload).select('id');

      final inserted = List<Map<String, dynamic>>.from(rows as List);
      if (inserted.isEmpty) {
        throw StateError('Article insert returned no row');
      }
      return inserted.first['id'].toString();
    } catch (e) {
      debugPrint('ArticleService.create failed: $e');
      rethrow;
    }
  }

  /// Updates an existing article.
  ///
  /// Two behaviours are lifted straight from the web form:
  ///
  ///  * A plain save never sends `status`/`approval_status`. The React
  ///    autosave comments that including them "silently reverts an
  ///    already-approved article to pending".
  ///  * Submitting updates the existing row rather than inserting. The React
  ///    comment notes that re-inserting here "caused duplicate articles".
  ///
  /// The `Users can update their own pending articles` policy also requires
  /// `approval_status = 'pending'`; callers must check [ArticleModel.isEditable]
  /// first, because an update that fails that policy matches zero rows and
  /// reports success.
  Future<void> update({
    required String id,
    required String title,
    required String slug,
    required String contentHtml,
    required String brief,
    required String? category,
    required List<String> tags,
    required String? imageUrl,
    required String authorName,
    required String? authorImageUrl,
    required int readTime,
    required String userId,
    required String? userType,
    required bool isAdmin,
    required bool submitForReview,
  }) async {
    try {
      final payload = _buildPayload(
        title: title,
        slug: slug,
        contentHtml: contentHtml,
        brief: brief,
        category: category,
        tags: tags,
        imageUrl: imageUrl,
        authorName: authorName,
        authorImageUrl: authorImageUrl,
        readTime: readTime,
        userId: userId,
        userType: userType,
      );

      if (submitForReview) {
        payload.addAll(_statusFields(
          isAdmin: isAdmin,
          submitForReview: true,
        ));
      }

      await _supabase.from('cms_posts').update(payload).eq('id', id);
    } catch (e) {
      debugPrint('ArticleService.update failed: $e');
      rethrow;
    }
  }

  /// The status columns, mirroring the web form's submit branch.
  Map<String, dynamic> _statusFields({
    required bool isAdmin,
    required bool submitForReview,
  }) {
    if (!submitForReview) {
      // Brand-new draft — the state React's autosave inserts.
      return {'status': 'draft', 'approval_status': 'pending'};
    }

    return {
      'approval_status': isAdmin ? 'approved' : 'pending',
      'status': isAdmin ? 'published' : 'draft',
      'published_at':
          isAdmin ? DateTime.now().toUtc().toIso8601String() : null,
      'is_featured': false,
    };
  }
}
