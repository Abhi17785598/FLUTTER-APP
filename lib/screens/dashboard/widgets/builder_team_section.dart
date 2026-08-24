// screens/dashboard/widgets/builder_team_section.dart
//
// Team on the builder dashboard's Content tab — the port of
// `BuilderTeamManager.tsx`.
//
// WHAT IS PORTED
// --------------
// Members, outstanding invitations, revoke on both, and the invite form with its
// module grants and project scope. All four match the portal field for field.
//
// WHAT IS NOT
// -----------
// `builder_team_activity` — the portal's third query (`:129-131`) feeds an activity
// feed. It is a read-only log with no actions on it, and the table is a separate
// migration (20270202000000); left out rather than ported half-way, and reported as
// a gap.
//
// THE INVITE GOES THROUGH THE EDGE FUNCTION
// -----------------------------------------
// `invite-team-member`, already deployed. It mints the token, writes the invitation
// row and sends the mail. Reimplementing any of that client-side would be the
// backend change this phase is not allowed to make — and would also bypass the
// max-10 trigger the function relies on.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/builder_section_options.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/builder_section_models.dart';
import '../../../models/project_model.dart';
import '../../../services/builder_sections_service.dart';
import 'builder_section_kit.dart';

/// The web origin an invite link should point at.
///
/// The portal passes `window.location.origin`. A phone has no origin, so the app
/// has to name the site the invitee will open the link on. Kept here as a single
/// constant rather than threaded through the UI: it is a property of the product,
/// not of this screen.
const String kInviteRedirectOrigin = 'https://propcid.com';

class BuilderTeamSection extends StatefulWidget {
  const BuilderTeamSection({
    super.key,
    required this.builderId,
    required this.projects,
    this.onCountChanged,
    this.service,
  });

  final String builderId;

  /// The builder's projects, for the invite form's per-project scope picker.
  ///
  /// Reuses the list the parent already loaded — `BuilderTeamManager.tsx:114-117`
  /// runs its own `builder_projects` query, which would be a third identical read
  /// on this tab.
  final List<ProjectModel> projects;

  final ValueChanged<int>? onCountChanged;

  @visibleForTesting
  final BuilderTeamService? service;

  @override
  State<BuilderTeamSection> createState() => _BuilderTeamSectionState();
}

class _BuilderTeamSectionState extends State<BuilderTeamSection> {
  late final BuilderTeamService _team = widget.service ?? BuilderTeamService();

  List<BuilderTeamMember>? _members;
  List<BuilderTeamInvitation>? _invitations;
  bool _failed = false;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  /// Active members only — the cap counts those, and so does the header.
  List<BuilderTeamMember> get _activeMembers =>
      (_members ?? const []).where((m) => m.status == 'active').toList();

  /// Invitations still worth showing: pending and not lapsed.
  List<BuilderTeamInvitation> get _openInvitations =>
      (_invitations ?? const []).where((i) => i.isPending).toList();

  bool get _capReached => _activeMembers.length >= kMaxBuilderTeamMembers;

  void _reportCount() => widget.onCountChanged?.call(
    _activeMembers.length + _openInvitations.length,
  );

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final results = await Future.wait([
        _team.listMembers(widget.builderId),
        _team.listInvitations(widget.builderId),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<BuilderTeamMember>;
        _invitations = results[1] as List<BuilderTeamInvitation>;
      });
      _reportCount();
    } catch (e) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openInviteSheet() async {
    if (_capReached) {
      _toast(
        'You can have at most $kMaxBuilderTeamMembers team members.',
        isError: true,
      );
      return;
    }

    final draft = await showModalBottomSheet<_InviteDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteSheet(projects: widget.projects),
    );
    if (draft == null || !mounted) return;

    setState(() => _busyId = 'invite');
    try {
      final result = await _team.invite(
        email: draft.email,
        modules: draft.modules,
        // Null, not an empty list: the column documents NULL as "all projects".
        projectIds: draft.scopeAll ? null : draft.projectIds,
        redirectOrigin: kInviteRedirectOrigin,
      );
      if (!mounted) return;

      if (result.needsManualShare) {
        // The function could not email an existing account holder. The portal
        // copies the link to the clipboard and says so; same here, because a link
        // shown and not copied is a link the builder has to transcribe.
        await Clipboard.setData(ClipboardData(text: result.actionLink!));
        _toast(
          'That person already has an account. Their invite link was copied — '
          'send it to them.',
        );
      } else {
        _toast('Invitation sent to ${draft.email}.');
      }
      await _load();
    } catch (e) {
      _toast(
        e is BuilderSectionException
            ? e.message
            : 'Could not send that invite. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _revokeMember(BuilderTeamMember member) async {
    final confirmed = await _confirmRevoke(
      title: 'Revoke Access',
      body:
          'Revoke ${member.email ?? 'this member'}\'s access?\n\n'
          'They lose it immediately. The record of the grant is kept.',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyId = member.id);
    try {
      await _team.revokeMember(member.id);
      if (!mounted) return;
      // Patched locally rather than re-fetched: the row stays, its status changes.
      setState(() {
        _members = _members
            ?.map((m) => m.id == member.id ? _revoked(m) : m)
            .toList();
      });
      _reportCount();
      _toast('Access revoked.');
    } catch (e) {
      _toast('Could not revoke that access. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  static BuilderTeamMember _revoked(BuilderTeamMember m) => BuilderTeamMember(
    id: m.id,
    memberUserId: m.memberUserId,
    email: m.email,
    modules: m.modules,
    projectIds: m.projectIds,
    status: 'revoked',
    createdAt: m.createdAt,
  );

  Future<void> _revokeInvitation(BuilderTeamInvitation invitation) async {
    final confirmed = await _confirmRevoke(
      title: 'Cancel Invitation',
      body:
          'Cancel the invitation to ${invitation.email}?\n\n'
          'Their link stops working.',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyId = invitation.id);
    try {
      await _team.revokeInvitation(invitation.id);
      if (!mounted) return;
      setState(() {
        _invitations = _invitations
            ?.where((i) => i.id != invitation.id)
            .toList();
      });
      _reportCount();
      _toast('Invitation cancelled.');
    } catch (e) {
      _toast(
        'Could not cancel that invitation. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<bool?> _confirmRevoke({required String title, required String body}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loaded = _members != null && _invitations != null;
    final members = _activeMembers;
    final invitations = _openInvitations;

    return BuilderSectionShell(
      failed: _failed,
      loaded: loaded,
      // Never collapses: the invite button is the point of this section, so an
      // empty team still has to render one.
      isEmpty: false,
      onRetry: _load,
      errorTitle: "Couldn't load your team",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${members.length} of $kMaxBuilderTeamMembers members',
                  style: AppTextStyles.caption,
                ),
              ),
              TextButton.icon(
                onPressed: _busyId == null ? _openInviteSheet : null,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: const Text('Invite'),
              ),
            ],
          ),
          if (_capReached)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Limit reached. Revoke a member to invite someone else.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error),
              ),
            ),

          if (_busyId == 'invite')
            const BuilderActionBusyRow()
          else if (members.isEmpty && invitations.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'No team members yet. Invite someone to help manage your '
                'inventory, offers, leads or site visits.',
                style: AppTextStyles.caption,
              ),
            ),

          for (final member in members) ...[
            const SizedBox(height: AppConstants.spacingM),
            _MemberCard(
              member: member,
              projects: widget.projects,
              busy: _busyId == member.id,
              onRevoke: () => _revokeMember(member),
            ),
          ],

          if (invitations.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'PENDING INVITATIONS',
              style: AppTextStyles.caption.copyWith(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
              ),
            ),
            for (final invitation in invitations) ...[
              const SizedBox(height: AppConstants.spacingM),
              _InvitationCard(
                invitation: invitation,
                busy: _busyId == invitation.id,
                onCancel: () => _revokeInvitation(invitation),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Shared renderer for the module chips both cards show.
class _ModuleChips extends StatelessWidget {
  const _ModuleChips({required this.modules});

  final List<String> modules;

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) {
      return const BuilderPill(label: 'No modules', tint: AppColors.error);
    }
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        for (final module in modules)
          BuilderPill(
            label: builderTeamModuleLabel(module),
            tint: AppColors.primary,
          ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.projects,
    required this.busy,
    required this.onRevoke,
  });

  final BuilderTeamMember member;
  final List<ProjectModel> projects;
  final bool busy;
  final VoidCallback onRevoke;

  /// "All projects", or the titles of the scoped ones.
  ///
  /// Titles rather than ids, because an id tells a builder nothing. Falls back to
  /// a count when a scoped project is no longer in the list — deleted since the
  /// grant, which the `project_ids` array does not cascade.
  String _scopeLabel() {
    final ids = member.projectIds;
    if (ids == null) return 'All projects';

    final titles = <String>[];
    var missing = 0;
    for (final id in ids) {
      final match = projects.where((p) => p.id == id);
      if (match.isEmpty) {
        missing++;
      } else {
        titles.add(match.first.title);
      }
    }

    if (titles.isEmpty) return '${ids.length} project(s)';
    if (missing == 0) return titles.join(', ');
    return '${titles.join(', ')} + $missing more';
  }

  @override
  Widget build(BuildContext context) {
    return BuilderSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.email ?? member.memberUserId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              BuilderPill(
                label: builderTeamStatusLabel(member.status),
                tint: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ModuleChips(modules: member.modules),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.apartment_outlined,
                size: 13,
                color: AppColors.textHint,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _scopeLabel(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 6),
          if (busy)
            const BuilderActionBusyRow()
          else
            BuilderAction(
              icon: Icons.person_remove_outlined,
              label: 'Revoke Access',
              tint: AppColors.error,
              onTap: onRevoke,
            ),
        ],
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({
    required this.invitation,
    required this.busy,
    required this.onCancel,
  });

  final BuilderTeamInvitation invitation;
  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return BuilderSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  invitation.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const BuilderPill(label: 'Pending', tint: AppColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          _ModuleChips(modules: invitation.modules),
          if (invitation.expiresAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.timer_outlined,
                  size: 13,
                  color: AppColors.textHint,
                ),
                const SizedBox(width: 4),
                // Flexible: "Expires Jan 1, 2099" at 130% text exceeds a 320 dp
                // card once the icon and padding are taken off.
                Flexible(
                  child: Text(
                    'Expires ${_formatDate(invitation.expiresAt!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppConstants.spacingM),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 6),
          if (busy)
            const BuilderActionBusyRow()
          else
            BuilderAction(
              icon: Icons.cancel_outlined,
              label: 'Cancel Invitation',
              tint: AppColors.error,
              onTap: onCancel,
            ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

/// One of the two project-scope choices.
class _ScopeOption extends StatelessWidget {
  const _ScopeOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;

  /// Null disables the row — the "pick projects" option when there are none.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final tint = disabled
        ? AppColors.textHint
        : (selected ? AppColors.primary : AppColors.textSecondary);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: tint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      color: disabled ? AppColors.textHint : null,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// What the invite sheet hands back.
class _InviteDraft {
  const _InviteDraft({
    required this.email,
    required this.modules,
    required this.scopeAll,
    required this.projectIds,
  });

  final String email;
  final List<String> modules;
  final bool scopeAll;
  final List<String> projectIds;
}

/// Email, module grants and project scope — `BuilderTeamManager.tsx`'s form,
/// including all four of its refusals (`:172-186`).
class _InviteSheet extends StatefulWidget {
  const _InviteSheet({required this.projects});

  final List<ProjectModel> projects;

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _email = TextEditingController();
  final Set<String> _modules = {};
  final Set<String> _projectIds = {};
  bool _scopeAll = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = "Enter the person's email address.");
      return;
    }
    if (_modules.isEmpty) {
      setState(() => _error = 'Grant at least one module.');
      return;
    }
    if (!_scopeAll && _projectIds.isEmpty) {
      setState(() => _error = 'Choose at least one project, or grant all.');
      return;
    }

    Navigator.pop(
      context,
      _InviteDraft(
        email: email,
        modules: _modules.toList(),
        scopeAll: _scopeAll,
        projectIds: _projectIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A Material, not a Container: this sheet holds CheckboxListTiles, and a
    // ListTile paints its background and ink splashes on the nearest Material
    // ancestor. Inside a plain coloured Container the framework asserts that
    // those effects would be invisible — correctly, since the Container's
    // decoration would cover them.
    return Material(
      color: AppColors.cardBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Invite a Team Member',
                style: AppTextStyles.heading2.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 2),
              Text(
                'They act on your data, limited to what you grant here.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 18),

              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              Text('Email', style: AppTextStyles.body.copyWith(fontSize: 12.5)),
              const SizedBox(height: 6),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                decoration: InputDecoration(
                  hintText: 'name@example.com',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.hairline),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Access',
                style: AppTextStyles.body.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 2),
              Text(
                'At least one is required.',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
              const SizedBox(height: 8),
              for (final module in kBuilderTeamModules)
                CheckboxListTile(
                  value: _modules.contains(module.value),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _modules.add(module.value);
                    } else {
                      _modules.remove(module.value);
                    }
                    _error = null;
                  }),
                  title: Text(
                    module.label,
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                  ),
                  subtitle: Text(
                    module.description,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  activeColor: AppColors.primary,
                ),
              const SizedBox(height: 10),

              Text(
                'Projects',
                style: AppTextStyles.body.copyWith(fontSize: 12.5),
              ),
              const SizedBox(height: 8),
              // Hand-rolled rather than `RadioListTile`: its `groupValue`/`onChanged`
              // pair is deprecated in favour of a `RadioGroup` ancestor, and this is
              // the same radio row the influencer video-type picker and both status
              // pickers already use.
              _ScopeOption(
                label: 'All projects',
                description: 'Includes any project you add later.',
                selected: _scopeAll,
                onTap: () => setState(() {
                  _scopeAll = true;
                  _error = null;
                }),
              ),
              _ScopeOption(
                label: 'Only the projects I pick',
                description: widget.projects.isEmpty
                    ? 'You have no projects to pick yet.'
                    : null,
                selected: !_scopeAll,
                onTap: widget.projects.isEmpty
                    ? null
                    : () => setState(() {
                        _scopeAll = false;
                        _error = null;
                      }),
              ),
              if (!_scopeAll)
                for (final project in widget.projects)
                  CheckboxListTile(
                    value: _projectIds.contains(project.id),
                    onChanged: (checked) => setState(() {
                      if (checked == true) {
                        _projectIds.add(project.id);
                      } else {
                        _projectIds.remove(project.id);
                      }
                      _error = null;
                    }),
                    title: Text(
                      project.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body.copyWith(fontSize: 12.5),
                    ),
                    contentPadding: const EdgeInsets.only(left: 16),
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    activeColor: AppColors.primary,
                  ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Send Invite'),
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
