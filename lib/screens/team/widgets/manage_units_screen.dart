import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/builder_section_options.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/builder_section_models.dart';
import '../../../services/builder_sections_service.dart';
import 'team_tab_states.dart';

/// Mobile mirror of the portal's `ProjectInventoryManager.tsx` — opened from a
/// project's "Manage Units" action in `TeamInventoryTab`.
///
/// Scoped entirely by [projectId], the same way the portal component is
/// (`projectId` is its only data prop) — a unit has no `builder_id` of its
/// own, so there is nothing else to scope by here; `project_inventory`'s RLS
/// (`Team members can manage project inventory`) is what actually restricts
/// this to a project the caller's membership covers.
///
/// Covers the core fields `InventoryUnit` already models — `unit_type`,
/// `unit_number`, `floor_number`, `area_sqft`, `price`, `status`. The
/// portal's own editor additionally has `amenities`, `features`,
/// `facing_direction` and `floor_plan_url`; those are deliberately out of
/// scope here, matching the model.
class ManageUnitsScreen extends StatefulWidget {
  const ManageUnitsScreen({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  final String projectId;
  final String projectTitle;

  @override
  State<ManageUnitsScreen> createState() => _ManageUnitsScreenState();
}

class _ManageUnitsScreenState extends State<ManageUnitsScreen> {
  final ProjectInventoryService _inventory = ProjectInventoryService();

  bool _loading = true;
  String? _error;
  List<InventoryUnit> _units = const [];
  String? _busyUnitId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final units = await _inventory.unitsForProject(widget.projectId);
      if (!mounted) return;
      setState(() {
        _units = units;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load units. Please try again.';
        _loading = false;
      });
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

  Future<void> _addUnit() async {
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _UnitFormSheet(),
    );
    if (payload == null || !mounted) return;

    try {
      await _inventory.createUnit(projectId: widget.projectId, payload: payload);
      if (!mounted) return;
      _toast('Unit added.');
      await _load();
    } catch (_) {
      _toast('Could not add that unit. Please try again.', isError: true);
    }
  }

  Future<void> _editUnit(InventoryUnit unit) async {
    final payload = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UnitFormSheet(existing: unit),
    );
    if (payload == null || !mounted) return;

    setState(() => _busyUnitId = unit.id);
    try {
      await _inventory.updateUnit(unitId: unit.id, payload: payload);
      if (!mounted) return;
      _toast('Unit updated.');
      await _load();
    } catch (_) {
      _toast('Could not update that unit. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _busyUnitId = null);
    }
  }

  Future<void> _deleteUnit(InventoryUnit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete unit'),
        content: Text(
          'Delete ${unit.unitNumber?.isNotEmpty == true ? 'unit ${unit.unitNumber}' : 'this unit'}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyUnitId = unit.id);
    try {
      await _inventory.deleteUnit(unit.id);
      if (!mounted) return;
      setState(() {
        _units = _units.where((u) => u.id != unit.id).toList();
        _busyUnitId = null;
      });
      _toast('Unit deleted.');
    } catch (_) {
      if (mounted) setState(() => _busyUnitId = null);
      _toast('Could not delete that unit. Please try again.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(widget.projectTitle, style: AppTextStyles.heading3),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addUnit,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? TeamTabErrorState(message: _error!, onRetry: _load)
              : _units.isEmpty
                  ? const TeamTabEmptyState(message: 'No units yet.')
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.spacingL,
                          AppConstants.spacingL,
                          AppConstants.spacingL,
                          88,
                        ),
                        itemCount: _units.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppConstants.spacingM),
                        itemBuilder: (context, index) {
                          final unit = _units[index];
                          return _UnitCard(
                            unit: unit,
                            busy: _busyUnitId == unit.id,
                            onEdit: () => _editUnit(unit),
                            onDelete: () => _deleteUnit(unit),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final InventoryUnit unit;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                child: Text(
                  unit.unitNumber?.isNotEmpty == true
                      ? '${unit.unitType} · ${unit.unitNumber}'
                      : unit.unitType,
                  style: AppTextStyles.heading3,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  inventoryUnitStatusLabel(unit.status),
                  style: AppTextStyles.chip.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingS),
          Text(
            '${unit.areaSqft.toStringAsFixed(0)} sqft'
            '${unit.floorNumber != null ? ' · Floor ${unit.floorNumber}' : ''}'
            ' · ₹${unit.price.toStringAsFixed(0)}',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppConstants.spacingM),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (busy)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                TextButton(onPressed: onEdit, child: const Text('Edit')),
                TextButton(
                  onPressed: onDelete,
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Delete'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Add/Edit form. Returns the payload to write, or `null` on cancel.
class _UnitFormSheet extends StatefulWidget {
  const _UnitFormSheet({this.existing});

  final InventoryUnit? existing;

  @override
  State<_UnitFormSheet> createState() => _UnitFormSheetState();
}

class _UnitFormSheetState extends State<_UnitFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _unitType;
  late final TextEditingController _unitNumber;
  late final TextEditingController _floorNumber;
  late final TextEditingController _areaSqft;
  late final TextEditingController _price;
  late String _status;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _unitType = TextEditingController(text: existing?.unitType ?? '');
    _unitNumber = TextEditingController(text: existing?.unitNumber ?? '');
    _floorNumber =
        TextEditingController(text: existing?.floorNumber?.toString() ?? '');
    _areaSqft = TextEditingController(
      text: existing != null && existing.areaSqft > 0
          ? existing.areaSqft.toString()
          : '',
    );
    _price = TextEditingController(
      text: existing != null && existing.price > 0 ? existing.price.toString() : '',
    );
    _status = existing?.status ?? 'available';
  }

  @override
  void dispose() {
    _unitType.dispose();
    _unitNumber.dispose();
    _floorNumber.dispose();
    _areaSqft.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(<String, dynamic>{
      'unit_type': _unitType.text.trim(),
      'unit_number':
          _unitNumber.text.trim().isEmpty ? null : _unitNumber.text.trim(),
      'floor_number': _floorNumber.text.trim().isEmpty
          ? null
          : int.tryParse(_floorNumber.text.trim()),
      'area_sqft': double.tryParse(_areaSqft.text.trim()) ?? 0,
      'price': double.tryParse(_price.text.trim()) ?? 0,
      'status': _status,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingL,
          AppConstants.spacingM,
          AppConstants.spacingL,
          AppConstants.spacingXL,
        ),
        child: SafeArea(
          top: false,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEdit ? 'Edit Unit' : 'Add Unit',
                    style: AppTextStyles.heading3,
                  ),
                  const SizedBox(height: AppConstants.spacingL),
                  TextFormField(
                    controller: _unitType,
                    decoration: const InputDecoration(labelText: 'Unit type'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  TextFormField(
                    controller: _unitNumber,
                    decoration:
                        const InputDecoration(labelText: 'Unit number (optional)'),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  TextFormField(
                    controller: _floorNumber,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Floor (optional)'),
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  TextFormField(
                    controller: _areaSqft,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Area (sqft)'),
                    validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) > 0
                        ? null
                        : 'Enter a valid area',
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  TextFormField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Price'),
                    validator: (v) => (double.tryParse(v?.trim() ?? '') ?? 0) > 0
                        ? null
                        : 'Enter a valid price',
                  ),
                  const SizedBox(height: AppConstants.spacingM),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: [
                      for (final option in kInventoryUnitStatusOptions)
                        DropdownMenuItem(
                          value: option.value,
                          child: Text(option.label),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _status = value ?? _status),
                  ),
                  const SizedBox(height: AppConstants.spacingXL),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      child: Text(isEdit ? 'Save Changes' : 'Add Unit'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
