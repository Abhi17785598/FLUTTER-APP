import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/scale_tap.dart';
import '../../../core/widgets/segmented_tab_pill.dart';
import '../../../models/article_summary.dart';
import '../../../models/property_model.dart';
import '../../../widgets/property_card_compact.dart';

/// "My Content" — All / Properties / Articles tabs over the user's own
/// listings and article submissions (blueprint §4.1, §16.4).
///
/// Owns only the selected-tab index; all data is passed in from
/// `ProfileProvider`.
class MyContentSection extends StatefulWidget {
  final List<PropertyModel> properties;
  final List<ArticleSummary> articles;
  final bool isLoading;
  final bool hasFailed;
  final VoidCallback onRetry;
  final void Function(PropertyModel property) onPropertyTap;
  final void Function(ArticleSummary article) onArticleTap;
  final VoidCallback onAddProperty;

  const MyContentSection({
    super.key,
    required this.properties,
    required this.articles,
    required this.isLoading,
    required this.hasFailed,
    required this.onRetry,
    required this.onPropertyTap,
    required this.onArticleTap,
    required this.onAddProperty,
  });

  @override
  State<MyContentSection> createState() => _MyContentSectionState();
}

class _MyContentSectionState extends State<MyContentSection> {
  static const List<String> _tabs = ['All', 'Properties', 'Articles'];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedTabPill(
          labels: _tabs,
          selectedIndex: _selected,
          onChanged: (i) => setState(() => _selected = i),
          itemVerticalPadding: 8,
        ),
        const SizedBox(height: AppConstants.spacingL),
        _buildBody(),
      ],
    );
  }

  Widget _buildBody() {
    if (widget.isLoading) return const _ContentShimmer();

    if (widget.hasFailed) {
      return EmptyStateView(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load your content",
        message: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: widget.onRetry,
      );
    }

    final showProperties = _selected == 0 || _selected == 1;
    final showArticles = _selected == 0 || _selected == 2;

    final properties = showProperties ? widget.properties : const [];
    final articles = showArticles ? widget.articles : const <ArticleSummary>[];

    if (properties.isEmpty && articles.isEmpty) return _buildEmpty();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final property in properties) ...[
          PropertyCardCompact(
            property: property,
            onTap: () => widget.onPropertyTap(property),
          ),
          const SizedBox(height: AppConstants.spacingM),
        ],
        for (final article in articles) ...[
          _ArticleRow(
            article: article,
            onTap: () => widget.onArticleTap(article),
          ),
          const SizedBox(height: AppConstants.spacingM),
        ],
      ],
    );
  }

  Widget _buildEmpty() {
    switch (_selected) {
      case 1:
        return EmptyStateView(
          icon: Icons.apartment_rounded,
          title: 'No properties yet',
          message: 'Your listings will appear here once you post one.',
          actionLabel: 'Add Property',
          onAction: widget.onAddProperty,
          iconCircleSize: 56,
          titleFontSize: 14.5,
        );
      case 2:
        return const EmptyStateView(
          icon: Icons.article_outlined,
          title: 'No articles yet',
          message: 'Articles you write will appear here.',
          iconCircleSize: 56,
          titleFontSize: 14.5,
        );
      default:
        return const EmptyStateView(
          icon: Icons.article_outlined,
          title: 'No content yet',
          message: 'Start creating content to see your content here',
          iconCircleSize: 56,
          titleFontSize: 14.5,
        );
    }
  }
}

/// Placeholder rows while the user's content loads — follows the
/// `PropertyCardShimmer` pattern rather than showing an empty state that would
/// wrongly read as "you have nothing" (blueprint §12).
class _ContentShimmer extends StatelessWidget {
  const _ContentShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        2,
        (_) => Padding(
          padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Container(
              height: 95,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(AppConstants.cardRadius),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One article in the My Content list.
class _ArticleRow extends StatelessWidget {
  final ArticleSummary article;
  final VoidCallback onTap;

  const _ArticleRow({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${article.title}, ${article.displayStatus}',
      button: true,
      child: ScaleTap(
        onTap: onTap,
        child: ColoredBox(
          color: AppColors.background,
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              boxShadow: AppColors.surfaceCardShadow,
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppConstants.imageThumbnailRadius,
                  ),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: article.imageUrl == null
                        ? const ColoredBox(
                            color: AppColors.primaryLight,
                            child: Icon(
                              Icons.article_outlined,
                              size: 22,
                              color: AppColors.primary,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: article.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => const ColoredBox(
                              color: AppColors.primaryLight,
                              child: Icon(
                                Icons.article_outlined,
                                size: 22,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        article.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _ArticleStatusChip(status: article.displayStatus),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Moderation/publication state chip.
///
/// Deliberately not `StatusTag`: that widget resolves its colours through
/// `AppColors.getStatusChipBg/Text`, which only knows property statuses and
/// falls through to one neutral style for everything else — "Published" and
/// "Rejected" would look identical. Teaching it article states would mean
/// editing global colour mappings, which is outside this milestone's scope.
class _ArticleStatusChip extends StatelessWidget {
  final String status;

  const _ArticleStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (status) {
      'Published' => (AppColors.success, Color(0x1A22C55E)),
      'Pending review' => (AppColors.warning, Color(0x1AF97316)),
      'Rejected' => (AppColors.error, Color(0x1AEF4444)),
      _ => (AppColors.textSecondary, Color(0x141A1A2E)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppConstants.chipRadius),
      ),
      child: Text(
        status,
        style: AppTextStyles.chip.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
