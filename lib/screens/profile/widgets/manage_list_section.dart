import 'package:flutter/material.dart';

import '../../../widgets/manage_list_tile.dart';

/// The "Manage" list at the foot of the Profile screen (blueprint §4.1).
///
/// Uses the shared [ManageListTile] card variant so these rows, the Workspace
/// Drawer and the More sheet all render from one widget.
class ManageListSection extends StatelessWidget {
  final VoidCallback onDashboard;
  final VoidCallback onMyProperties;
  final VoidCallback onSaved;
  final VoidCallback onMore;

  /// Builder-only "Projects" row. Preserved from the old Business section so
  /// the role-conditional destination is not silently dropped
  /// (blueprint §16.4).
  final VoidCallback? onProjects;

  const ManageListSection({
    super.key,
    required this.onDashboard,
    required this.onMyProperties,
    required this.onSaved,
    required this.onMore,
    this.onProjects,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      ManageListTile(
        icon: Icons.grid_view_rounded,
        label: 'Manage Dashboard',
        subtitle: 'Listings, performance & insights',
        onTap: onDashboard,
      ),
      ManageListTile(
        icon: Icons.apartment_rounded,
        label: 'My Properties',
        subtitle: 'View and manage your listings',
        onTap: onMyProperties,
      ),
      if (onProjects != null)
        ManageListTile(
          icon: Icons.business_center_rounded,
          label: 'Projects',
          subtitle: 'View all projects',
          onTap: onProjects,
        ),
      ManageListTile(
        icon: Icons.bookmark_border_rounded,
        label: 'Saved',
        subtitle: 'Properties you have saved',
        onTap: onSaved,
      ),
      ManageListTile(
        icon: Icons.more_horiz_rounded,
        label: 'More',
        subtitle: 'Feed, Network, Billing & more',
        onTap: onMore,
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          rows[i],
        ],
      ],
    );
  }
}
