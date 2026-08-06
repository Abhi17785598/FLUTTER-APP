import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'active_filter_chip_row.dart';
import 'view_switcher.dart';

/// Height of the query pill and the buttons flanking it.
const double _kPillHeight = 44;

/// Height of the City / Sort chips.
const double _kChipHeight = 34;

/// The pinned block above the results surfaces.
///
/// Purely presentational — every action arrives as a callback and every value as
/// a parameter, so it reads no providers and holds no state. That keeps the
/// screen the single owner of search orchestration and leaves this widget
/// trivially previewable.
///
/// Order matches the redesign: query pill + filter button, result count,
/// City/Sort chips, the active-filter chips (only when there are any), then the
/// view switcher.
class SearchResultsHeader extends StatelessWidget {
  /// Leaves this screen. The redesign gives the query pill this role and draws
  /// no arrow, but an explicit Back control is kept alongside it so the gesture
  /// stays consistent with every other screen in the app.
  final VoidCallback onBackTap;

  final String queryLabel;
  final VoidCallback onQueryTap;

  final int activeFilterCount;
  final VoidCallback onFilterTap;

  final bool nearMeEnabled;
  final VoidCallback onNearMeTap;

  final String resultCountLabel;

  final String cityLabel;
  final VoidCallback onCityTap;

  final String sortLabel;
  final VoidCallback onSortTap;

  final List<ActiveFilterChip> activeChips;

  final SearchViewMode viewMode;
  final ValueChanged<SearchViewMode> onViewModeChanged;

  const SearchResultsHeader({
    super.key,
    required this.onBackTap,
    required this.queryLabel,
    required this.onQueryTap,
    required this.activeFilterCount,
    required this.onFilterTap,
    required this.nearMeEnabled,
    required this.onNearMeTap,
    required this.resultCountLabel,
    required this.cityLabel,
    required this.onCityTap,
    required this.sortLabel,
    required this.onSortTap,
    required this.activeChips,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingXL,
        14,
        AppConstants.spacingXL,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Same 44 dp / r14 / white treatment as the two buttons at the
              // end of this row, so the four controls read as one group.
              _buildIconButton(
                icon: Icons.arrow_back,
                iconColor: AppColors.textPrimary,
                semanticLabel: 'Back',
                onTap: onBackTap,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(child: _buildQueryPill()),
              const SizedBox(width: AppConstants.spacingS),
              // Near Me is not in the redesign's results header — the redesign
              // puts a crosshair on the map instead, which is Phase 5. It is
              // kept here so the existing, working radius search (LocationService
              // -> 15 km -> capped at 100) stays reachable in the meantime rather
              // than disappearing for two phases.
              _buildIconButton(
                icon: nearMeEnabled ? Icons.near_me : Icons.near_me_outlined,
                iconColor:
                    nearMeEnabled ? AppColors.primary : AppColors.textPrimary,
                semanticLabel:
                    nearMeEnabled ? 'Turn off Near Me' : 'Search near me',
                onTap: onNearMeTap,
              ),
              const SizedBox(width: AppConstants.spacingS),
              _buildFilterButton(),
            ],
          ),
          const SizedBox(height: AppConstants.spacingM),
          Text(
            resultCountLabel,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: _buildDropdownChip(
                  label: cityLabel,
                  onTap: onCityTap,
                  semanticLabel: 'Change city',
                ),
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: _buildDropdownChip(
                  label: sortLabel,
                  onTap: onSortTap,
                  semanticLabel: 'Change sort order',
                ),
              ),
            ],
          ),
          if (activeChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            ActiveFilterChipRow(chips: activeChips),
          ],
          const SizedBox(height: AppConstants.spacingM),
          ViewSwitcher(value: viewMode, onChanged: onViewModeChanged),
        ],
      ),
    );
  }

  /// Shows the active query and, on tap, returns to the Search Entry screen —
  /// the same affordance the redesign gives it (`backToSearchEntry`).
  Widget _buildQueryPill() {
    return Semantics(
      label: 'Edit search: $queryLabel',
      button: true,
      child: GestureDetector(
        onTap: onQueryTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: _kPillHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.searchBarRadius),
            boxShadow: AppColors.surfaceCardShadow,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppConstants.spacingS),
              Expanded(
                child: Text(
                  queryLabel,
                  style: AppTextStyles.body.copyWith(fontSize: 12.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton() {
    return Semantics(
      label: 'Filters',
      button: true,
      child: GestureDetector(
        onTap: onFilterTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Container(
              width: _kPillHeight,
              height: _kPillHeight,
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius:
                    BorderRadius.circular(AppConstants.searchBarRadius),
                boxShadow: AppColors.surfaceCardShadow,
              ),
              child: const Icon(
                Icons.tune,
                size: 20,
                color: AppColors.textPrimary,
              ),
            ),
            // A dot, not a number: the redesign marks "filters are on" and the
            // exact count already appears inside the filter sheet's own header.
            if (activeFilterCount > 0)
              Positioned(
                top: 7,
                right: 7,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color iconColor,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: _kPillHeight,
          height: _kPillHeight,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.searchBarRadius),
            boxShadow: AppColors.surfaceCardShadow,
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildDropdownChip({
    required String label,
    required VoidCallback onTap,
    required String semanticLabel,
  }) {
    return Semantics(
      label: '$semanticLabel: $label',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: _kChipHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingM),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.pillRadius),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 5),
              const Icon(
                Icons.keyboard_arrow_down,
                size: 16,
                color: AppColors.textHint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
