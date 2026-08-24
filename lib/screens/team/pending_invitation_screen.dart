import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/builder_section_options.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/builder_section_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../services/builder_sections_service.dart';

/// Mobile equivalent of the portal's `AcceptInvite.tsx`.
///
/// Reached automatically by `PendingInvitationGate` (the mirror of
/// `TeamInviteGate.tsx`), never by a deep link yet — that's a later phase.
/// Reads its list from [AuthProvider.pendingTeamInvitations] rather than
/// querying `builder_team_invitations` itself, per that provider already
/// being the single source of truth for this person's own pending rows.
///
/// Shows every pending invitation, not just the first — `AcceptInvite.tsx`'s
/// own detection always resolves to one (its email fallback query is
/// `.limit(1)`), but this app's provider does not truncate the list, so more
/// than one pending row is a real state this screen has to represent rather
/// than silently collapse.
///
/// Works unmodified for both populations `accept-team-invite` distinguishes
/// server-side (`index.ts:131-151`): a brand-new invitee, whose
/// `profiles.user_type` the function sets to `'team_member'`, and an existing
/// PropCid user, whose `user_type` it leaves untouched. This screen never
/// reads or writes `user_type` itself — it only ever calls the existing
/// Edge Function and re-reads `AuthProvider`'s cache afterward.
class PendingInvitationScreen extends StatelessWidget {
  const PendingInvitationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final invitations = context.watch<AuthProvider>().pendingTeamInvitations;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          invitations.length > 1 ? 'Team Invitations' : 'Team Invitation',
          style: AppTextStyles.heading3,
        ),
      ),
      body: invitations.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(AppConstants.spacingL),
              itemCount: invitations.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppConstants.spacingL),
              itemBuilder: (context, index) =>
                  _InvitationCard(invitation: invitations[index]),
            ),
    );
  }
}

/// Reached if this screen is opened after every pending invitation on it has
/// already been resolved elsewhere (e.g. the person accepted on another
/// device) — [PendingInvitationGate] only ever pushes this screen when the
/// list was non-empty at that moment, but it can go stale while this screen
/// is open.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_read_outlined,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              'No pending invitations right now.',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.spacingXL),
            ElevatedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _CardStatus { idle, accepting, accepted, error }

class _InvitationCard extends StatefulWidget {
  const _InvitationCard({required this.invitation});

  final BuilderTeamInvitation invitation;

  @override
  State<_InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<_InvitationCard> {
  final AuthService _authService = AuthService();
  final BuilderTeamService _teamService = BuilderTeamService();

  bool _loadingBuilder = true;
  Map<String, dynamic>? _builderProfile;

  _CardStatus _status = _CardStatus.idle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBuilderProfile();
  }

  /// Resolves who invited this person for display. `builder_team_invitations`
  /// itself carries no display name — the portal only gets one back from
  /// `accept-team-invite`'s success response (`index.ts:160-165`), i.e. only
  /// after accepting — so this reads `profiles` directly by `builderId`,
  /// reusing [AuthService.getUserProfile] rather than adding a second way to
  /// fetch a profile row.
  Future<void> _loadBuilderProfile() async {
    final builderId = widget.invitation.builderId;
    if (builderId == null || builderId.isEmpty) {
      if (mounted) setState(() => _loadingBuilder = false);
      return;
    }

    try {
      final profile = await _authService.getUserProfile(builderId);
      if (!mounted) return;
      setState(() {
        _builderProfile = profile;
        _loadingBuilder = false;
      });
    } catch (_) {
      // Non-fatal: the card still works without a name, just less legibly.
      if (mounted) setState(() => _loadingBuilder = false);
    }
  }

  String get _builderLabel {
    final profile = _builderProfile;
    if (profile == null) return 'A builder';
    final company = profile['company_name']?.toString();
    if (company != null && company.isNotEmpty) return company;
    final name = profile['display_name']?.toString();
    if (name != null && name.isNotEmpty) return name;
    return 'A builder';
  }

  Future<void> _accept() async {
    setState(() {
      _status = _CardStatus.accepting;
      _errorMessage = null;
    });

    try {
      final result = await _teamService.acceptInvite(
        invitationId: widget.invitation.id,
        token: widget.invitation.token,
      );

      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      await auth.refreshTeamStatus();

      // Confirmation, not blind trust in the function's response — the row
      // must actually be there before this is called complete.
      final confirmed = auth.activeTeamMemberships.any(
        (m) => m.builderId == result.builderId && m.status == 'active',
      );

      if (!mounted) return;
      setState(() {
        if (confirmed) {
          _status = _CardStatus.accepted;
        } else {
          _status = _CardStatus.error;
          _errorMessage =
              "Accepted, but we couldn't confirm your access "
              'yet. Pull to refresh and try again in a moment.';
        }
      });
    } on BuilderSectionException catch (e) {
      if (!mounted) return;
      setState(() {
        _status = _CardStatus.error;
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = _CardStatus.error;
        _errorMessage = 'Could not accept that invitation. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final invitation = widget.invitation;
    final accepted = _status == _CardStatus.accepted;

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _loadingBuilder
                    ? Text('Loading…', style: AppTextStyles.caption)
                    : Text(_builderLabel, style: AppTextStyles.heading3),
              ),
              _StatusChip(accepted: accepted),
            ],
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            'Invited you to help manage their workspace.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppConstants.spacingL),
          _sectionLabel('ACCESS'),
          const SizedBox(height: AppConstants.spacingS),
          Wrap(
            spacing: AppConstants.spacingS,
            runSpacing: AppConstants.spacingS,
            children: [
              for (final module in invitation.modules)
                _Pill(label: builderTeamModuleLabel(module)),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          _sectionLabel('PROJECTS'),
          const SizedBox(height: AppConstants.spacingS),
          Text(_projectScopeLabel(invitation), style: AppTextStyles.body),
          const SizedBox(height: AppConstants.spacingXL),
          if (accepted)
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                const SizedBox(width: AppConstants.spacingS),
                Expanded(
                  child: Text(
                    'Invitation accepted successfully.',
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            )
          else ...[
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: AppTextStyles.body.copyWith(color: AppColors.error),
              ),
              const SizedBox(height: AppConstants.spacingS),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _status == _CardStatus.accepting ? null : _accept,
                child: _status == _CardStatus.accepting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Accept Invitation'),
              ),
            ),
          ],
          if (accepted) ...[
            const SizedBox(height: AppConstants.spacingM),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                // `AcceptInvite.tsx:113-121` — after acceptance the portal
                // navigates into `/team-workspace`, it never just returns
                // the person to wherever they were. `pushReplacement`
                // rather than `push`: this screen only ever got here via
                // `PendingInvitationGate`'s own auto-push, so leaving an
                // already-accepted card behind in the back stack would be a
                // dead end, not a screen worth returning to.
                onPressed: () => Navigator.of(
                  context,
                ).pushReplacementNamed(AppConstants.teamWorkspaceScreen),
                child: const Text('Continue'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: AppColors.textHint,
        letterSpacing: 0.5,
      ),
    );
  }

  /// `null` ⇒ every one of the builder's projects — the same convention
  /// `BuilderTeamMember.hasAllProjects` documents on the membership side.
  String _projectScopeLabel(BuilderTeamInvitation invitation) {
    final projectIds = invitation.projectIds;
    if (projectIds == null) return 'All of their projects';
    if (projectIds.length == 1) return '1 project';
    return '${projectIds.length} projects';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.accepted});

  final bool accepted;

  @override
  Widget build(BuildContext context) {
    final color = accepted ? AppColors.success : AppColors.statusPending;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        accepted ? 'Accepted' : 'Pending',
        style: AppTextStyles.chip.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.chip.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
