import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../models/property_model.dart';
import '../../providers/property_provider.dart';

class ComparePropertiesScreen extends StatefulWidget {
  final List<String> propertyIds;
  const ComparePropertiesScreen({super.key, required this.propertyIds});

  @override
  State<ComparePropertiesScreen> createState() =>
      _ComparePropertiesScreenState();
}

class _ComparePropertiesScreenState extends State<ComparePropertiesScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  List<PropertyModel?> _slots = [null, null];
  bool _showDiffsOnly = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<PropertyProvider>(context, listen: false);
      final props = provider.properties;
      setState(() {
        if (widget.propertyIds.isNotEmpty) {
          _slots[0] = props.firstWhere(
              (p) => p.id == widget.propertyIds[0],
              orElse: () => props.first);
        }
        if (widget.propertyIds.length > 1) {
          _slots[1] = props.firstWhere(
              (p) => p.id == widget.propertyIds[1],
              orElse: () => props.length > 1 ? props[1] : props.first);
        }
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _pickProperty(int slot) async {
    final provider =
        Provider.of<PropertyProvider>(context, listen: false);
    final props = provider.properties;

    final result = await showModalBottomSheet<PropertyModel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PropertyPickerSheet(properties: props),
    );
    if (result != null) {
      setState(() => _slots[slot] = result);
    }
  }

  // ─── UI ─────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildPropertyHeaders(),
                      _buildToggleRow(),
                      _buildCompareTable(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: AppColors.cardShadow,
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 16, color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compare Properties', style: AppTextStyles.heading2),
                Text('Side-by-side comparison',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildPropertyHeaders() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildPropertyHeader(0)),
        const SizedBox(width: 10),
        Expanded(child: _buildPropertyHeader(1)),
      ],
    ),
  );
}

  Widget _buildPropertyHeader(int slot) {
    final prop = _slots[slot];

    return GestureDetector(
      onTap: () => _pickProperty(slot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          border: Border.all(
              color: prop != null
                  ? AppColors.primary.withOpacity(0.2)
                  : AppColors.textHint,
              width: prop != null ? 1.5 : 1,
              strokeAlign: BorderSide.strokeAlignOutside),
          boxShadow: AppColors.cardShadow,
        ),
        child: prop == null
            ? _buildEmptySlot()
            : _buildFilledHeader(prop, slot),
      ),
    );
  }

  Widget _buildEmptySlot() {
    return Container(
      height: 160,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add, color: AppColors.primary, size: 22),
          ),
          const SizedBox(height: 8),
          Text('Add Property',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary)),
          const SizedBox(height: 4),
          Text('Tap to select',
              style: AppTextStyles.caption.copyWith(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildFilledHeader(PropertyModel prop, int slot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppConstants.cardRadius),
                topRight: Radius.circular(AppConstants.cardRadius),
              ),
              child: Image.network(
                prop.imageUrl,
                height: 90,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 90,
                  color: AppColors.primaryLight,
                  child: const Icon(Icons.home_outlined,
                      size: 36, color: AppColors.primary),
                ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => _pickProperty(slot),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: const Icon(Icons.swap_horiz_rounded,
                      size: 14, color: AppColors.primary),
                ),
              ),
            ),
            if (prop.isVerified)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.verifiedBadge,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('✓ Verified',
                      style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prop.title,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(prop.location,
                  style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(prop.priceDisplay,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.priceColor)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text('Compare Details',
                style: AppTextStyles.heading3),
          ),
          GestureDetector(
            onTap: () => setState(() => _showDiffsOnly = !_showDiffsOnly),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient:
                    _showDiffsOnly ? AppColors.primaryGradient : null,
                color: _showDiffsOnly ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow:
                    _showDiffsOnly ? AppColors.primaryGlow : AppColors.cardShadow,
              ),
              child: Row(
                children: [
                  Icon(
                    _showDiffsOnly
                        ? Icons.check_circle
                        : Icons.filter_list_rounded,
                    size: 14,
                    color: _showDiffsOnly
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Differences only',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _showDiffsOnly
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompareTable() {
    final rows = _getCompareRows();
    final filtered = _showDiffsOnly
        ? rows.where((r) => r.isDifferent(_slots[0], _slots[1])).toList()
        : rows;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          for (int i = 0; i < filtered.length; i++) ...[
            _buildRow(filtered[i], i.isEven),
            if (i < filtered.length - 1)
              const Divider(height: 1, color: AppColors.background),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(_CompareRow row, bool isEven) {
    final v1 = row.getValue(_slots[0]);
    final v2 = row.getValue(_slots[1]);
    final isDiff = row.isDifferent(_slots[0], _slots[1]);
    final winner = row.getWinner(_slots[0], _slots[1]);

    return Container(
      color: isEven ? AppColors.background.withOpacity(0.5) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Icon(row.icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(row.label,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
          Expanded(child: _buildCellValue(v1, isDiff, winner == 0)),
          const SizedBox(width: 8),
          Expanded(child: _buildCellValue(v2, isDiff, winner == 1)),
        ],
      ),
    );
  }

  Widget _buildCellValue(String value, bool isDiff, bool isWinner) {
    if (value == '—') {
      return Text('—',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isWinner
            ? AppColors.success.withOpacity(0.12)
            : (isDiff ? AppColors.error.withOpacity(0.06) : null),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isWinner)
            const Icon(Icons.emoji_events_rounded,
                size: 10, color: AppColors.success),
          if (isWinner) const SizedBox(width: 3),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isWinner
                    ? AppColors.success
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_CompareRow> _getCompareRows() {
    return [
      _CompareRow(
        label: 'Price',
        icon: Icons.currency_rupee,
        getValue: (p) => p?.priceDisplay ?? '—',
        compare: (a, b) {
          if (a == null || b == null) return 0;
          return a.price < b.price ? 0 : 1;
        },
      ),
      _CompareRow(
        label: 'Price/Sqft',
        icon: Icons.square_foot,
        getValue: (p) => p?.pricePerSqft ?? '—',
      ),
      _CompareRow(
        label: 'Area',
        icon: Icons.straighten,
        getValue: (p) => p != null ? '${p.sqft} sqft' : '—',
        compare: (a, b) {
          if (a == null || b == null) return 0;
          return a.sqft > b.sqft ? 0 : 1;
        },
      ),
      _CompareRow(
        label: 'Bedrooms',
        icon: Icons.bed_outlined,
        getValue: (p) => p != null ? '${p.beds} BHK' : '—',
        compare: (a, b) {
          if (a == null || b == null) return 0;
          return a.beds >= b.beds ? 0 : 1;
        },
      ),
      _CompareRow(
        label: 'Bathrooms',
        icon: Icons.bathtub_outlined,
        getValue: (p) => p != null ? '${p.baths} Bath' : '—',
        compare: (a, b) {
          if (a == null || b == null) return 0;
          return a.baths >= b.baths ? 0 : 1;
        },
      ),
      _CompareRow(
        label: 'Parking',
        icon: Icons.local_parking_outlined,
        getValue: (p) => p != null ? '${p.parking} Slot' : '—',
        compare: (a, b) {
          if (a == null || b == null) return 0;
          return a.parking >= b.parking ? 0 : 1;
        },
      ),
      _CompareRow(
        label: 'Builder',
        icon: Icons.business_outlined,
        getValue: (p) => p?.builderName ?? '—',
      ),
      _CompareRow(
        label: 'Type',
        icon: Icons.home_outlined,
        getValue: (p) => p?.propertyType ?? '—',
      ),
      _CompareRow(
        label: 'Status',
        icon: Icons.check_circle_outline,
        getValue: (p) => p?.possessionStatus ?? p?.statusTags.firstOrNull ?? '—',
      ),
      _CompareRow(
        label: 'Rating',
        icon: Icons.star_outline_rounded,
        getValue: (p) =>
            p?.rating != null ? '${p!.rating!.toStringAsFixed(1)} ★' : '—',
        compare: (a, b) {
          if (a == null || b == null) return 0;
          final ra = a.rating ?? 0;
          final rb = b.rating ?? 0;
          return ra >= rb ? 0 : 1;
        },
      ),
      _CompareRow(
        label: 'Amenities',
        icon: Icons.pool_outlined,
        getValue: (p) =>
            p != null ? '${p.amenities.length} amenities' : '—',
        compare: (a, b) {
          if (a == null || b == null) return 0;
          return a.amenities.length >= b.amenities.length ? 0 : 1;
        },
      ),
      _CompareRow(
        label: 'Verified',
        icon: Icons.verified_outlined,
        getValue: (p) =>
            p == null ? '—' : (p.isVerified ? 'Yes ✓' : 'No'),
        compare: (a, b) {
          if (a == null || b == null) return 0;
          if (a.isVerified && !b.isVerified) return 0;
          if (!a.isVerified && b.isVerified) return 1;
          return -1;
        },
      ),
    ];
  }
}

// ─────────────────────────────────────────────
//  Compare Row Data Class
// ─────────────────────────────────────────────
class _CompareRow {
  final String label;
  final IconData icon;
  final String Function(PropertyModel?) getValue;
  // returns 0 if first wins, 1 if second wins, -1 if tie/N/A
  final int Function(PropertyModel?, PropertyModel?)? compare;

  const _CompareRow({
    required this.label,
    required this.icon,
    required this.getValue,
    this.compare,
  });

  bool isDifferent(PropertyModel? a, PropertyModel? b) {
    return getValue(a) != getValue(b);
  }

  int getWinner(PropertyModel? a, PropertyModel? b) {
    if (compare == null) return -1;
    return compare!(a, b);
  }
}

// ─────────────────────────────────────────────
//  Property Picker Bottom Sheet
// ─────────────────────────────────────────────
class _PropertyPickerSheet extends StatefulWidget {
  final List<PropertyModel> properties;
  const _PropertyPickerSheet({required this.properties});

  @override
  State<_PropertyPickerSheet> createState() => _PropertyPickerSheetState();
}

class _PropertyPickerSheetState extends State<_PropertyPickerSheet> {
  String _query = '';

  List<PropertyModel> get _filtered => widget.properties
      .where((p) =>
          p.title.toLowerCase().contains(_query.toLowerCase()) ||
          p.location.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textHint,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Property', style: AppTextStyles.heading3),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      hintText: 'Search properties...',
                      prefixIcon:
                          Icon(Icons.search, size: 18, color: AppColors.textHint),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    style:
                        const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final p = _filtered[i];
                return ListTile(
                  onTap: () => Navigator.pop(context, p),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      p.imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 52,
                        height: 52,
                        color: AppColors.primaryLight,
                        child: const Icon(Icons.home_outlined,
                            color: AppColors.primary),
                      ),
                    ),
                  ),
                  title: Text(p.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(p.location,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  trailing: Text(p.priceDisplay,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.priceColor)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}