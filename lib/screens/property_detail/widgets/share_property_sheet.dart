import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/profile_link.dart';
import '../../profile/actions/share_profile_sheet.dart'
    show ProfileLinkBox, ShareActionButton, copyProfileLink;

/// Share a property — mirrors the portal's PropertyShareModal
/// (`src/components/ShareToSocial.tsx`): a visible, copyable link, the
/// system share sheet, and the SAME 4 social buttons the reference actually
/// has (WhatsApp/Facebook/Twitter/LinkedIn — it has no Instagram/Telegram/
/// Email button, so none is added here). Reuses [ProfileLinkBox]/
/// [ShareActionButton]/[copyProfileLink] from the profile share sheet rather
/// than duplicating that already-working link-box/copy/share pattern.
void showSharePropertySheet(
  BuildContext context, {
  required String propertyId,
  required String title,
  String? location,
  String? priceDisplay,
}) {
  final String displayTitle = title.trim().isNotEmpty
      ? title
      : 'Check out this property';
  final String shareUrl = propertyShareUrl(propertyId, title: displayTitle);

  final buffer = StringBuffer()..writeln('🏡 $displayTitle');
  if (priceDisplay != null && priceDisplay.trim().isNotEmpty) {
    buffer.writeln('💰 $priceDisplay');
  }
  if (location != null && location.trim().isNotEmpty) {
    buffer.writeln('📍 $location');
  }
  buffer
    ..writeln()
    ..writeln('Discover more premium properties on PropCID.')
    ..write(shareUrl);

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SharePropertyBody(
      title: displayTitle,
      location: location,
      priceDisplay: priceDisplay,
      shareUrl: shareUrl,
      message: buffer.toString().trim(),
    ),
  );
}

class _SharePropertyBody extends StatelessWidget {
  final String title;
  final String? location;
  final String? priceDisplay;
  final String shareUrl;
  final String message;

  const _SharePropertyBody({
    required this.title,
    required this.location,
    required this.priceDisplay,
    required this.shareUrl,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEDF2),
                  borderRadius: BorderRadius.circular(AppConstants.pillRadius),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share Property',
              style: AppTextStyles.heading3.copyWith(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
            if ((location?.trim().isNotEmpty ?? false) ||
                (priceDisplay?.trim().isNotEmpty ?? false)) ...[
              const SizedBox(height: 2),
              Text(
                [
                  if (priceDisplay?.trim().isNotEmpty ?? false) priceDisplay,
                  if (location?.trim().isNotEmpty ?? false) location,
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Native "Share Now" — reference's PropertyShareModal shows this
            // as a full-width prominent button above the social grid.
            ShareActionButton(
              icon: Icons.ios_share_rounded,
              label: 'Share',
              filled: true,
              onTap: () {
                Navigator.of(context).pop();
                Share.share(message, subject: title);
              },
            ),
            const SizedBox(height: 14),
            // The same 4 social buttons the reference actually has, each
            // opening the SAME URL template ShareToSocial.tsx uses.
            Row(
              children: [
                Expanded(
                  child: _SocialButton(
                    icon: Icons.message_rounded,
                    label: 'WhatsApp',
                    color: const Color(0xFF25D366),
                    onTap: () => _openSocial(
                      context,
                      'https://wa.me/?text=${Uri.encodeComponent(message)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SocialButton(
                    icon: Icons.facebook_rounded,
                    label: 'Facebook',
                    color: const Color(0xFF1877F2),
                    onTap: () => _openSocial(
                      context,
                      'https://www.facebook.com/sharer/sharer.php?u=${Uri.encodeComponent(shareUrl)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SocialButton(
                    icon: Icons.alternate_email_rounded,
                    label: 'Twitter',
                    color: const Color(0xFF1DA1F2),
                    onTap: () => _openSocial(
                      context,
                      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(message)}&url=${Uri.encodeComponent(shareUrl)}',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SocialButton(
                    icon: Icons.business_center_rounded,
                    label: 'LinkedIn',
                    color: const Color(0xFF0A66C2),
                    onTap: () => _openSocial(
                      context,
                      'https://www.linkedin.com/sharing/share-offsite/?url=${Uri.encodeComponent(shareUrl)}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Visible, copyable link — the specific gap this sheet exists to
            // close (the old flow went straight to the OS share sheet with
            // no on-screen link at all).
            ProfileLinkBox(shareUrl: shareUrl),
            const SizedBox(height: 10),
            ShareActionButton(
              icon: Icons.copy_rounded,
              label: 'Copy Link',
              filled: false,
              onTap: () => copyProfileLink(context, shareUrl),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSocial(BuildContext context, String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[SharePropertySheet] Failed to open $url: $e');
    }
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
