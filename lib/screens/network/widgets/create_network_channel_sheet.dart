import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/network_models.dart';
import '../../../providers/network_communication_provider.dart';
import '../../../widgets/shared/toggle_row.dart';
import '../../messaging/widgets/chat_avatar.dart';

/// Network ▸ Communication's Create Channel sheet.
///
/// Deliberately not a reuse of `showCreateChannelSheet` (the generic Messages
/// one) — a network channel needs a purpose, member types and an auto-join
/// flag the generic flow has no fields for, and the generic flow's own
/// behaviour must not change. Field set, values and labels mirror the
/// portal's `NetworkCommunicationHub.tsx` Create Channel modal exactly.
///
/// Returns `true` once the channel was created (whether or not every
/// downstream write succeeded — the caller reads
/// [NetworkCommunicationProvider.createChannelError] for that), or `null` if
/// dismissed.
Future<bool?> showCreateNetworkChannelSheet(BuildContext context) {
  final provider = context.read<NetworkCommunicationProvider>();
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChangeNotifierProvider<NetworkCommunicationProvider>.value(
      value: provider,
      child: const _CreateNetworkChannelSheet(),
    ),
  );
}

class _CreateNetworkChannelSheet extends StatefulWidget {
  const _CreateNetworkChannelSheet();

  @override
  State<_CreateNetworkChannelSheet> createState() =>
      _CreateNetworkChannelSheetState();
}

class _CreateNetworkChannelSheetState
    extends State<_CreateNetworkChannelSheet> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _memberSearchController = TextEditingController();

  String? _purpose;
  Set<String> _memberTypes = {'broker', 'influencer'};
  bool _autoJoin = false;
  String? _validationError;

  // Specific people hand-picked from the network, independent of the
  // type-filtered auto-join above — mirrors the generic Messages "Create
  // Channel" sheet's member picker, but searches [acceptedMembers] (already
  // loaded for this screen) client-side rather than hitting the backend.
  final Map<String, NetworkMember> _selectedMembers = {};
  String _memberSearchQuery = '';

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  void _addMember(NetworkMember member) {
    setState(() {
      _selectedMembers[member.memberId] = member;
      _memberSearchController.clear();
      _memberSearchQuery = '';
    });
  }

  void _removeMember(String memberId) {
    setState(() => _selectedMembers.remove(memberId));
  }

  void _toggleMemberType(String value, bool selected) {
    setState(() {
      if (selected) {
        _memberTypes = {..._memberTypes, value};
      } else {
        _memberTypes = _memberTypes.where((t) => t != value).toSet();
      }
    });
  }

  Future<void> _submit() async {
    final provider = context.read<NetworkCommunicationProvider>();
    if (provider.creatingChannel) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _validationError = 'Channel name is required.');
      return;
    }
    if (_purpose == null) {
      setState(() => _validationError = 'Channel purpose is required.');
      return;
    }
    if (_autoJoin && _memberTypes.isEmpty) {
      setState(
        () =>
            _validationError = 'Select at least one member type for auto-join.',
      );
      return;
    }

    setState(() => _validationError = null);

    final success = await provider.createChannel(
      name: name,
      description: _descriptionController.text,
      channelPurpose: _purpose!,
      isAutoJoin: _autoJoin,
      memberTypes: _memberTypes.toList(),
      manualMemberIds: _selectedMembers.keys.toList(),
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }

    // A failed or partial creation stays on the sheet with the entered
    // content intact and the provider's own error surfaced — never silently
    // closed as if nothing went wrong.
    setState(() {
      _validationError =
          provider.createChannelError ??
          "Couldn't create the channel. Please try again.";
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NetworkCommunicationProvider>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final creating = provider.creatingChannel;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
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
                      borderRadius: BorderRadius.circular(
                        AppConstants.pillRadius,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Create Network Channel',
                  style: AppTextStyles.heading3.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set up a new communication channel for your network',
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                ),
                const SizedBox(height: 18),
                _label('Channel Name*'),
                const SizedBox(height: 6),
                _field(
                  _nameController,
                  'e.g. Downtown Buyers',
                  enabled: !creating,
                ),
                const SizedBox(height: 14),
                _label('Description (optional)'),
                const SizedBox(height: 6),
                _field(
                  _descriptionController,
                  'What is this channel about?',
                  maxLines: 3,
                  enabled: !creating,
                ),
                const SizedBox(height: 14),
                _label('Channel Purpose*'),
                const SizedBox(height: 6),
                _purposeDropdown(enabled: !creating),
                const SizedBox(height: 14),
                _label('Member Types'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: kNetworkMemberTypes
                      .map(
                        (type) => FilterChip(
                          label: Text(type.label),
                          selected: _memberTypes.contains(type.value),
                          onSelected: creating
                              ? null
                              : (selected) =>
                                    _toggleMemberType(type.value, selected),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 8),
                ToggleRow(
                  label: 'Auto-add eligible members',
                  description:
                      'Automatically add accepted network members of the '
                      'selected type(s) when this channel is created.',
                  value: _autoJoin,
                  onChanged: creating
                      ? null
                      : (v) => setState(() => _autoJoin = v),
                ),
                const SizedBox(height: 14),
                _label('Add Specific Members (optional)'),
                const SizedBox(height: 6),
                _field(
                  _memberSearchController,
                  'Search your network by name...',
                  enabled: !creating,
                  onChanged: (v) =>
                      setState(() => _memberSearchQuery = v.trim()),
                ),
                if (_selectedMembers.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedMembers.values
                        .map((m) => _selectedMemberChip(m, enabled: !creating))
                        .toList(),
                  ),
                ],
                if (_memberSearchQuery.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: _memberSearchResults(provider, enabled: !creating),
                  ),
                ],
                if (_validationError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _validationError!,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const Key('createNetworkChannelSubmit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: creating ? null : _submit,
                    child: creating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('Create Channel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _purposeDropdown({required bool enabled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _purpose,
          hint: Text(
            'Select channel purpose',
            style: AppTextStyles.body.copyWith(
              fontSize: 13.5,
              color: AppColors.textHint,
            ),
          ),
          items: kChannelPurposeOptions
              .map(
                (o) => DropdownMenuItem(
                  value: o.value,
                  child: Text(
                    o.label,
                    style: AppTextStyles.body.copyWith(fontSize: 13.5),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled ? (v) => setState(() => _purpose = v) : null,
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: AppTextStyles.caption.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );

  Widget _field(
    TextEditingController controller,
    String hint, {
    int maxLines = 1,
    bool enabled = true,
    ValueChanged<String>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        enabled: enabled,
        onChanged: onChanged,
        style: AppTextStyles.body.copyWith(fontSize: 13.5),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: hint,
          hintStyle: AppTextStyles.body.copyWith(
            fontSize: 13.5,
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }

  Widget _selectedMemberChip(NetworkMember member, {required bool enabled}) {
    final name = member.displayName?.isNotEmpty == true
        ? member.displayName!
        : 'Unknown';
    return Container(
      padding: const EdgeInsets.only(left: 4, right: 8, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppConstants.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ChatAvatar(
            avatarUrl: member.avatarUrl,
            initials: name[0].toUpperCase(),
            size: 22,
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => _removeMember(member.memberId) : null,
            child: const Icon(Icons.close, size: 14, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }

  Widget _memberSearchResults(
    NetworkCommunicationProvider provider, {
    required bool enabled,
  }) {
    final query = _memberSearchQuery.toLowerCase();
    final results = provider.acceptedMembers
        .where((m) => !_selectedMembers.containsKey(m.memberId))
        .where((m) => (m.displayName ?? '').toLowerCase().contains(query))
        .toList();

    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'No matching network members',
            style: AppTextStyles.caption.copyWith(fontSize: 12.5),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: results.length,
      itemBuilder: (context, index) {
        final member = results[index];
        final name = member.displayName?.isNotEmpty == true
            ? member.displayName!
            : 'Unknown';
        return InkWell(
          onTap: enabled ? () => _addMember(member) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                ChatAvatar(
                  avatarUrl: member.avatarUrl,
                  initials: name[0].toUpperCase(),
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(fontSize: 13.5),
                  ),
                ),
                Text(
                  networkMemberTypeLabel(member.memberType),
                  style: AppTextStyles.caption.copyWith(fontSize: 11.5),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
