// screens/dashboard/widgets/builder_inventory_summary.dart
//
// The six summary cards above the portal's Inventory list
// (`BuilderInventoryManager.tsx:327-400`), which Flutter had none of.
//
// Portal → here, card for card:
//
//   Total Projects      projects.length
//   Active              status == 'active'
//   Under Construction  status == 'under_construction'
//   Completed           status == 'completed'
//   Total Units         Σ project_inventory rows
//   Units Sold          Σ rows with status == 'sold'
//
// All six are unconditional on the portal — `totalUnits`/`soldUnits` render as
// `0` in their own card exactly like the other four, never hidden. This used
// to hide the last two tiles below a `_totalUnits > 0` guard, so a builder who
// had not yet added any `project_inventory` rows for any project saw four
// cards instead of six, reading as though the feature were missing entirely.
// Matching the portal's own unconditional layout removed that guard.
//
// PRESENTATION ONLY
// -----------------
// Every figure is a fold over two collections the Builder dashboard already holds:
// `_projects` (from `ProjectService.listMine`) and `_unitCounts` (from
// `ProjectInventoryService.countsByProject`). No query, no service change, no new
// model.
//
// The portal lays these out as six equal cards in a row, which at 320 dp would be
// 53 dp each. Here they are a horizontally scrollable strip of compact tiles — the
// same treatment the broker leads strip uses — so every figure keeps a readable
// number and its own label.
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/builder_section_models.dart';
import '../../../models/project_model.dart';

class BuilderInventorySummary extends StatelessWidget {
  const BuilderInventorySummary({
    super.key,
    required this.projects,
    required this.unitCounts,
  });

  final List<ProjectModel> projects;
  final Map<String, InventoryCounts> unitCounts;

  int _withStatus(String status) =>
      projects.where((p) => p.status == status).length;

  int get _totalUnits =>
      unitCounts.values.fold<int>(0, (sum, c) => sum + c.total);

  int get _soldUnits =>
      unitCounts.values.fold<int>(0, (sum, c) => sum + c.sold);

  @override
  Widget build(BuildContext context) {
    // Nothing to summarise before the projects land. The list below shows its own
    // spinner, so a second one here would be two spinners for one load.
    if (projects.isEmpty) return const SizedBox.shrink();

    final tiles = <_Tile>[
      _Tile('Total Projects', '${projects.length}', AppColors.primary),
      _Tile('Active', '${_withStatus('active')}', AppColors.success),
      _Tile(
        'Under Construction',
        '${_withStatus('under_construction')}',
        AppColors.statusNewLaunch,
      ),
      _Tile('Completed', '${_withStatus('completed')}', AppColors.primary),
      // Unconditional, matching the portal — see the file header. `0` here
      // means "no inventory added yet", which is worth showing directly
      // rather than making the whole card disappear.
      _Tile('Total Units', '$_totalUnits', AppColors.textSecondary),
      _Tile('Units Sold', '$_soldUnits', AppColors.warning),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const ClampingScrollPhysics(),
      child: Row(
        children: [
          for (final tile in tiles)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              constraints: const BoxConstraints(minWidth: 78),
              decoration: BoxDecoration(
                color: tile.tint.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tile.tint.withValues(alpha: 0.14)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tile.value,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: tile.tint,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    tile.label,
                    style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile {
  const _Tile(this.label, this.value, this.tint);

  final String label;
  final String value;
  final Color tint;
}
