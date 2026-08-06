import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/social_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../widgets/shared/app_action_button.dart';
import '../../widgets/shared/app_surface_card.dart';
import 'widgets/social_screen_shell.dart';
import '../shared/section_loader.dart';

/// Social ▸ Accounts — the design's `isSocialAccounts` screen.
///
/// Shows whether a Facebook Page and an Instagram Business account are linked,
/// read from the token-free `social_accounts_safe` view.
///
/// Connecting is not implemented here. React runs the Meta OAuth handshake
/// through `meta-oauth-exchange` and a browser redirect; the mobile equivalent
/// needs a redirect/deep-link strategy that is still an open product decision,
/// so the button says what it does and routes to the placeholder rather than
/// starting a flow that cannot complete.
class SocialAccountsScreen extends StatelessWidget {
  const SocialAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SocialAccountSection(),
      child: const _AccountsView(),
    );
  }
}

class _AccountsView extends StatefulWidget {
  const _AccountsView();

  @override
  State<_AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<_AccountsView>
    with DeferredSectionLoader<_AccountsView> {
  @override
  void loadSection(String userId) =>
      context.read<SocialAccountSection>().loadFor(userId);

  @override
  Widget build(BuildContext context) {
    final section = context.watch<SocialAccountSection>();

    return SocialAccountsBody(
      account: section.value,
      loading: section.loading,
      failed: section.failed,
      onConnect: () => openSectionPlaceholder(
        context,
        'Connect Facebook & Instagram',
      ),
    );
  }
}

/// The visuals, split from the provider so the layout is testable without an
/// [AuthProvider] (which needs a live Supabase client).
class SocialAccountsBody extends StatelessWidget {
  final SocialAccount? account;
  final bool loading;
  final bool failed;
  final VoidCallback onConnect;

  const SocialAccountsBody({
    super.key,
    required this.account,
    required this.loading,
    required this.failed,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return SocialScreenShell(
      title: 'Accounts',
      subtitle: 'Connect Facebook & Instagram once',
      children: [
        const SizedBox(height: AppConstants.spacingXL),
        if (failed)
          const _StatusCard(
            icon: Icons.error_outline,
            title: 'Facebook Page',
            badge: 'Unavailable',
            description:
                "Couldn't read your connection status. Try again in a moment.",
          )
        else ...[
          _StatusCard(
            icon: Icons.facebook,
            title: 'Facebook Page',
            badge: loading
                ? 'Checking…'
                : (account?.hasFacebookPage ?? false)
                    ? 'Connected'
                    : 'Not connected',
            connected: !loading && (account?.hasFacebookPage ?? false),
            description: (account?.hasFacebookPage ?? false)
                ? account!.pageName!
                : 'Connect your Facebook Page to publish listings, projects '
                    'and updates automatically.',
          ),
          const SizedBox(height: AppConstants.spacingM),
          _StatusCard(
            icon: Icons.camera_alt_outlined,
            title: 'Instagram Business',
            badge: loading
                ? 'Checking…'
                : (account?.hasInstagram ?? false)
                    ? 'Linked'
                    : 'Not linked',
            connected: !loading && (account?.hasInstagram ?? false),
            description: (account?.hasInstagram ?? false)
                ? '@${account!.instagramUsername!}'
                : 'Instagram publishing uses the Instagram Business account '
                    'linked to your Facebook Page. Link one in Meta, then '
                    'reconnect.',
          ),
        ],
        if (!loading && !failed && (account?.lastError?.isNotEmpty ?? false))
          ...[
          const SizedBox(height: AppConstants.spacingM),
          _NoticeCard(text: account!.lastError!),
        ],
        // A token nearing expiry is the one piece of connection health worth
        // surfacing — React's `daysUntilExpiry`.
        if (!loading && !failed && _expiryWarning(account) != null) ...[
          const SizedBox(height: AppConstants.spacingM),
          _NoticeCard(text: _expiryWarning(account)!),
        ],
        const SizedBox(height: AppConstants.spacingL),
        AppActionButton(
          label: 'Connect Facebook & Instagram',
          height: 48,
          icon: Icons.link,
          elevated: true,
          onTap: onConnect,
        ),
      ],
    );
  }

  static String? _expiryWarning(SocialAccount? account) {
    if (account == null || !account.connected) return null;
    final days = account.daysUntilExpiry;
    if (days == null || days > 14) return null;
    if (days < 0) return 'Your Meta access has expired. Reconnect to resume publishing.';
    return 'Your Meta access expires in $days ${days == 1 ? 'day' : 'days'}. '
        'Reconnect to avoid interruption.';
  }
}

/// White card: glyph + title with a status pill, then supporting copy.
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String badge;
  final String description;
  final bool connected;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.badge,
    required this.description,
    this.connected = false,
  });

  @override
  Widget build(BuildContext context) {
    return DashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: AppColors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              Container(
                height: 22,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  // Dark pill when disconnected, matching the design; green
                  // once a real connection exists.
                  color: connected ? AppColors.success : AppColors.textPrimary,
                  borderRadius: BorderRadius.circular(AppConstants.pillRadius),
                ),
                child: Text(
                  badge,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            description,
            style: AppTextStyles.caption.copyWith(fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String text;

  const _NoticeCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3E2),
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Color(0xFFB45309),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11.5,
                height: 1.45,
                color: const Color(0xFFB45309),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
