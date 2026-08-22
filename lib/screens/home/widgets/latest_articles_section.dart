// screens/home/widgets/latest_articles_section.dart
//
// Home's "Latest Articles" rail plus its detail sheet — the Flutter
// counterpart to the portal's inline `cms_posts` query
// (`PublicHomePage.tsx`/`AuthenticatedHomePage.tsx`, queryKey
// `'home-articles'`) rendered via `BlogCard`, which on the web navigates to
// `/blog/articles/:slug` (`BlogDetail`).
//
// This app has no article-reader screen or HTML-rendering package yet, so
// the article opens in a bottom sheet (the same pattern `NewsSection` already
// uses for its own admin-curated rail) rather than a full page — a smaller,
// self-contained addition than introducing a new route and a new dependency
// for a single read-only view.
//
// HIDES ITSELF WHEN THERE IS NOTHING TO SHOW
// ------------------------------------------
// Same convention as `NewsSection` / `TrendingCitiesSection`: nothing renders
// while loading, on failure, or when there are genuinely no published
// articles.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../models/article_model.dart';
import '../../../services/article_service.dart';
import '../../../widgets/area_converter_sheet.dart' show SheetDragHandle;
import '../../../widgets/section_header.dart';

const double _kArticleRailHeight = 264;
const double _kArticleCardWidth = 220;
const double _kArticleThumbHeight = 120;
const double _kSheetRadius = 24;

class LatestArticlesSection extends StatefulWidget {
  const LatestArticlesSection({super.key, this.service});

  @visibleForTesting
  final ArticleService? service;

  @override
  State<LatestArticlesSection> createState() => _LatestArticlesSectionState();
}

class _LatestArticlesSectionState extends State<LatestArticlesSection> {
  late final Future<List<ArticleModel>> _future =
      (widget.service ?? ArticleService()).listPublished();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ArticleModel>>(
      future: _future,
      builder: (context, snapshot) {
        final articles = snapshot.data;
        if (articles == null || articles.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Latest Articles'),
              SizedBox(
                height: _kArticleRailHeight,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                  ),
                  itemCount: articles.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(right: AppConstants.spacingM),
                    child: ScaleTap(
                      onTap: () => _showArticleDetail(context, articles[i]),
                      child: _ArticleCard(article: articles[i]),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});

  final ArticleModel article;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kArticleCardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppColors.surfaceCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.cardRadius),
            ),
            child: _ArticleThumbnail(
              imageUrl: article.imageUrl,
              height: _kArticleThumbHeight,
              width: _kArticleCardWidth,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (article.category != null)
                    Text(
                      article.category!.toUpperCase(),
                      style: AppTextStyles.chip.copyWith(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    article.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${article.readTime} min read',
                        style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleThumbnail extends StatelessWidget {
  const _ArticleThumbnail({
    required this.imageUrl,
    required this.height,
    this.width,
  });

  final String? imageUrl;
  final double height;
  final double? width;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return _placeholder();
    return CachedNetworkImage(
      imageUrl: imageUrl!,
      height: height,
      width: width,
      fit: BoxFit.cover,
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) => _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        height: height,
        width: width,
        color: AppColors.primaryLight,
        alignment: Alignment.center,
        child: const Icon(
          Icons.article_rounded,
          size: 26,
          color: AppColors.primary,
        ),
      );
}

/// Strips HTML tags for a plain-text body — good enough for a read-only
/// sheet without pulling in an HTML-rendering package for this one screen.
/// Collapses runs of whitespace left behind by stripped block tags.
String _stripHtml(String html) {
  final withoutTags = html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  return withoutTags.replaceAll(RegExp(r'\s+'), ' ').trim();
}

void _showArticleDetail(BuildContext context, ArticleModel article) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.cardBackground,
    barrierColor: AppColors.textPrimary.withValues(alpha: 0.5),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_kSheetRadius)),
    ),
    builder: (_) => _ArticleDetailSheet(article: article),
  );
}

class _ArticleDetailSheet extends StatelessWidget {
  const _ArticleDetailSheet({required this.article});

  final ArticleModel article;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final body = _stripHtml(article.contentHtml);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.size.height * 0.86),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: AppConstants.spacingM),
              child: SheetDragHandle(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spacingXL,
                  0,
                  AppConstants.spacingXL,
                  AppConstants.spacingL,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius:
                          BorderRadius.circular(AppConstants.cardRadius),
                      child: _ArticleThumbnail(
                        imageUrl: article.imageUrl,
                        height: 190,
                        width: double.infinity,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spacingL),
                    if (article.category != null)
                      Text(
                        article.category!.toUpperCase(),
                        style: AppTextStyles.chip.copyWith(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      article.title,
                      style: AppTextStyles.heading3.copyWith(
                        fontSize: 17,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '${article.readTime} min read',
                          style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                        ),
                        if (article.publishedAt != null) ...[
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.event_rounded,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${article.publishedAt!.day}/'
                            '${article.publishedAt!.month}/'
                            '${article.publishedAt!.year}',
                            style:
                                AppTextStyles.caption.copyWith(fontSize: 11.5),
                          ),
                        ],
                      ],
                    ),
                    if (article.brief.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spacingM),
                      Text(
                        article.brief,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spacingM),
                      Text(
                        body,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13.5,
                          height: 1.6,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
