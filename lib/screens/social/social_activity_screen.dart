import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/empty_state_view.dart';
import '../../core/widgets/scale_tap.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import '../../widgets/shared/app_surface_card.dart';
import '../shared/section_loader.dart';
import 'widgets/social_screen_shell.dart';

/// Social ▸ Publishing Activity — the design's `isSocialActivity` screen.
///
/// The caller's publish timeline from `social_share_logs`, newest first.
///
/// React can retry a failed publish (`retryQueueItem`, which inserts into
/// `social_share_queue`). That is a write and is not ported; a failed row shows
/// its error instead.
class SocialActivityScreen extends StatelessWidget {
  const SocialActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SocialActivitySection(),
      child: const _ActivityView(),
    );
  }
}

class _ActivityView extends StatefulWidget {
  const _ActivityView();

  @override
  State<_ActivityView> createState() => _ActivityViewState();
}

class _ActivityViewState extends State<_ActivityView>
    with DeferredSectionLoader<_ActivityView> {
  @override
  void loadSection(String userId) =>
      context.read<SocialActivitySection>().loadFor(userId);

  @override
  Widget build(BuildContext context) {
    final section = context.watch<SocialActivitySection>();

    return SocialActivityBody(
      logs: section.value,
      loading: section.loading,
      failed: section.failed,
      onRefresh: reloadSection,
    );
  }
}

class SocialActivityBody extends StatelessWidget {
  final List<ShareLog> logs;
  final bool loading;
  final bool failed;
  final VoidCallback onRefresh;

  const SocialActivityBody({
    super.key,
    required this.logs,
    required this.loading,
    required this.failed,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SocialScreenShell(
      title: 'Publishing Activity',
      subtitle: 'Your publish timeline',
      children: [
        const SizedBox(height: 18),
        DashboardCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(child: SocialCardTitle('Publishing activity')),
                  Semantics(
                    label: 'Refresh',
                    button: true,
                    child: ScaleTap(
                      onTap: onRefresh,
                      child: ColoredBox(
                        color: AppColors.cardBackground,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.refresh,
                              size: 16,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Refresh',
                              style: AppTextStyles.body.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingXL),
              if (loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (failed)
                const EmptyStateView(
                  icon: Icons.error_outline,
                  message: "Couldn't load your publishing activity.",
                  iconCircleSize: 52,
                  padding: EdgeInsets.symmetric(vertical: 4),
                )
              else if (logs.isEmpty)
                const EmptyStateView(
                  icon: Icons.schedule,
                  message: 'Nothing published yet. Create a property or '
                      'project and use "Publish Everywhere".',
                  iconCircleSize: 52,
                  padding: EdgeInsets.symmetric(vertical: 4),
                )
              else
                for (var i = 0; i < logs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _LogRow(log: logs[i]),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  final ShareLog log;

  const _LogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final failed = log.status == 'failed';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            log.platform == 'instagram'
                ? Icons.camera_alt_outlined
                : Icons.facebook,
            size: 18,
            color: failed ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  log.contentType.isEmpty ? 'Post' : log.contentType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (failed && (log.error?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.error!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      color: AppColors.error,
                      height: 1.35,
                    ),
                  ),
                ] else if (log.caption?.isNotEmpty ?? false) ...[
                  const SizedBox(height: 2),
                  Text(
                    log.caption!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppConstants.spacingS),
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: log.succeeded
                  ? AppColors.success
                  : (failed ? AppColors.error : AppColors.background),
              borderRadius: BorderRadius.circular(AppConstants.pillRadius),
            ),
            child: Text(
              log.status,
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: log.succeeded || failed
                    ? Colors.white
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
