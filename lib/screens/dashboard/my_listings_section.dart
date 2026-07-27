import 'package:flutter/material.dart';

import '../../models/property_model.dart';
import '../../services/property_service.dart';
import '../post_property/post_property_screen.dart';

// ── Brand palette (mirrors every other dashboard screen) ──────────────────────
class _Brand {
  static const Color c2 = Color(0xFF3424C8);
  static const Color c4 = Color(0xFF6657FF);
}

/// A self-contained "My Listings" section for use inside any dashboard screen.
///
/// Fetches properties for [userId] from the `properties` table, renders them
/// as cards with Edit and Delete actions. Does not require a provider in the
/// widget tree — state is managed locally via [PropertyService] calls.
class MyListingsSection extends StatefulWidget {
  final String userId;

  const MyListingsSection({required this.userId, super.key});

  @override
  State<MyListingsSection> createState() => _MyListingsSectionState();
}

class _MyListingsSectionState extends State<MyListingsSection> {
  bool _loading = false;
  List<PropertyModel> _properties = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results =
          await PropertyService().getPropertiesByUser(widget.userId);
      if (mounted) {
        setState(() {
          _properties = results;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _openEditScreen(PropertyModel property) async {
    PropertyEditBundle bundle;
    try {
      bundle = await PropertyService().fetchForEdit(property.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not load property for editing: $e'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (!mounted) return;
    final refreshNeeded = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PostPropertyScreen(
          editPropertyId: property.id,
          editBundle: bundle,
        ),
      ),
    );

    if (refreshNeeded == true && mounted) await _load();
  }

  Future<void> _showDeleteDialog(PropertyModel property) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Property'),
        content: const Text(
          'Are you sure you want to delete this property? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await PropertyService().deleteProperty(property.id);
      if (mounted) {
        setState(() {
          _properties =
              _properties.where((p) => p.id != property.id).toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Property deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: CircularProgressIndicator(color: _Brand.c2),
        ),
      );
    }

    if (_error != null) {
      return _ErrorState(onRetry: _load, message: _error!);
    }

    if (_properties.isEmpty) {
      return const _EmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _properties.length,
      itemBuilder: (_, index) {
        final property = _properties[index];
        return _PropertyCard(
          property: property,
          onEdit: () => _openEditScreen(property),
          onDelete: () => _showDeleteDialog(property),
        );
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _Brand.c2.withOpacity(0.12),
                  _Brand.c4.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.home_work_outlined,
              size: 32,
              color: _Brand.c2.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No property listings yet.",
            textAlign: TextAlign.center,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1C1530),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Use the Post Property wizard to publish your first listing.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.55),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const _ErrorState({required this.onRetry, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Failed to load listings.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.red.shade600,
                  ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Property Card ─────────────────────────────────────────────────────────────

class _PropertyCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PropertyCard({
    required this.property,
    required this.onEdit,
    required this.onDelete,
  });

  static String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Color _statusColor(String? status) => switch (status) {
        'active' => Colors.green,
        'sold' => Colors.blue,
        'inactive' => Colors.grey,
        _ => Colors.amber,
      };

  String _statusLabel(String? status) => switch (status) {
        'active' => 'Active',
        'sold' => 'Sold',
        'inactive' => 'Inactive',
        _ => 'Pending',
      };

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final coverUrl = property.resolvedImageUrls.isNotEmpty
        ? property.resolvedImageUrls.first
        : null;
    final statusColor = _statusColor(property.status);
    final statusLabel = _statusLabel(property.status);
    final category = (property.category ?? 'Property')
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover image ────────────────────────────────────────────────────
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: coverUrl != null
                  ? Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Category + Status ──────────────────────────────────────
                Row(
                  children: [
                    _badge(
                      textTheme,
                      label: category,
                      bg: _Brand.c2.withOpacity(0.1),
                      fg: _Brand.c2,
                    ),
                    const SizedBox(width: 8),
                    _badge(
                      textTheme,
                      label: statusLabel,
                      bg: statusColor.withOpacity(0.12),
                      fg: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  property.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1C1530),
                  ),
                ),
                const SizedBox(height: 6),

                // ── Price ──────────────────────────────────────────────────
                Text(
                  property.priceDisplay,
                  style: textTheme.titleSmall?.copyWith(
                    color: _Brand.c2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Location ───────────────────────────────────────────────
                if (property.location.isNotEmpty)
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 14,
                          color: scheme.onSurface.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),

                // ── Created date ───────────────────────────────────────────
                if (property.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 12,
                          color: scheme.onSurface.withOpacity(0.4)),
                      const SizedBox(width: 4),
                      Text(
                        _formatDate(property.createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withOpacity(0.45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // ── Action buttons ─────────────────────────────────────────
                Row(
                  children: [
                    _ActionButton(
                      label: 'View',
                      icon: Icons.open_in_new_rounded,
                      color: _Brand.c2,
                      onTap: () {},
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      color: Colors.orange,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 8),
                    _ActionButton(
                      label: 'Delete',
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(
    TextTheme textTheme, {
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFEEECF8),
      child: const Center(
        child: Icon(Icons.home_work_outlined,
            size: 48, color: Color(0xFFBBB6E0)),
      ),
    );
  }
}

// ── Action Button ─────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final effectiveColor = disabled ? Colors.grey.shade400 : color;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: effectiveColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: effectiveColor.withOpacity(disabled ? 0.2 : 0.3),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: effectiveColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
