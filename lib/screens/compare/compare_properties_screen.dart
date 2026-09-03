import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../models/amenity_model.dart';
import '../../models/property_model.dart';
import '../../providers/compare_provider.dart';
import '../../providers/property_provider.dart';
import '../../services/property_service.dart';

/// Compare Properties — global-state, portal-parity rewrite.
///
/// Reads its selection from [CompareProvider] (the same store every property
/// card's compare toggle writes to) rather than owning two local slots, so
/// adding/removing a property anywhere in the app is reflected here and vice
/// versa. `widget.propertyIds` is kept only for the voice agent / a future
/// deep link that names properties explicitly — if the global selection is
/// still empty when this screen opens, those ids seed it once; the two
/// in-app entry points (Home quick action, header dropdown) always pass an
/// empty list today, so this path is inert for them.
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

  final PropertyService _propertyService = PropertyService();

  bool _isLoading = true;
  bool _hasError = false;
  bool _showDiffsOnly = false;
  List<PropertyModel> _properties = [];

  /// Two separate scrollables — the property header strip has no reserved
  /// left column (so Property A starts at normal screen padding), while the
  /// comparison matrix below it keeps a fixed attribute-label column to its
  /// left. Because their viewports start at different x-offsets they can't
  /// share one `ScrollController` (Flutter only allows a controller to
  /// attach to one active `Scrollable`), so they're linked manually: each
  /// mirrors its raw scroll offset onto the other, guarded by
  /// [_isSyncingScroll] to avoid a feedback loop.
  final ScrollController _headerScrollController = ScrollController();
  final ScrollController _matrixScrollController = ScrollController();
  bool _isSyncingScroll = false;

  /// How many persisted/requested ids silently failed to resolve (deleted,
  /// deactivated or unapproved since they were added) — surfaced once as an
  /// info banner rather than a crash or a substituted property.
  int _unavailableCount = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _headerScrollController.addListener(
      () => _mirrorScroll(
        from: _headerScrollController,
        to: _matrixScrollController,
      ),
    );
    _matrixScrollController.addListener(
      () => _mirrorScroll(
        from: _matrixScrollController,
        to: _headerScrollController,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProperties());
  }

  @override
  void dispose() {
    _animController.dispose();
    _headerScrollController.dispose();
    _matrixScrollController.dispose();
    super.dispose();
  }

  /// Mirrors [from]'s raw pixel offset onto [to], clamped to [to]'s own
  /// scroll range (the two regions can have slightly different content
  /// widths — the header strip includes the "Add" tile, the matrix
  /// doesn't — so their max extents aren't always identical).
  void _mirrorScroll({
    required ScrollController from,
    required ScrollController to,
  }) {
    if (_isSyncingScroll || !to.hasClients || !from.hasClients) return;
    final clamped = from.offset.clamp(0.0, to.position.maxScrollExtent);
    if (clamped == to.offset) return;
    _isSyncingScroll = true;
    to.jumpTo(clamped);
    _isSyncingScroll = false;
  }

  // ─── Data loading / resolution ──────────────────────────────

  Future<void> _loadProperties() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final compareProvider = context.read<CompareProvider>();
      final propertyProvider = context.read<PropertyProvider>();

      // Seeds the global selection from an explicit deep link only when
      // nothing is already selected — never overrides an in-progress
      // comparison the user already built via the property cards.
      if (compareProvider.selectedIds.isEmpty &&
          widget.propertyIds.isNotEmpty) {
        final seeded = await _resolveIds(widget.propertyIds, propertyProvider);
        for (final property in seeded) {
          compareProvider.add(property);
        }
      }

      final requestedIds = compareProvider.selectedIds;
      final resolved = await _resolveIds(requestedIds, propertyProvider);

      final resolvedIds = resolved.map((p) => p.id).toSet();
      final missingIds = requestedIds
          .where((id) => !resolvedIds.contains(id))
          .toList();
      // Never substitute a different property for one that can't be
      // resolved — drop the slot instead.
      for (final id in missingIds) {
        compareProvider.remove(id);
      }
      compareProvider.reconcileWithPool(resolved);

      if (!mounted) return;
      setState(() {
        _properties = resolved;
        _unavailableCount = missingIds.length;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ComparePropertiesScreen] load failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  /// Cache first (`PropertyProvider.findCached`), then a single targeted
  /// fetch for whatever is still missing — the project's existing
  /// resolve-by-id pattern (see `PropertyDetailScreen`), just batched.
  /// Preserves [ids]' order in the result; an id that resolves nowhere is
  /// simply absent, never swapped for an unrelated property.
  Future<List<PropertyModel>> _resolveIds(
    List<String> ids,
    PropertyProvider propertyProvider,
  ) async {
    if (ids.isEmpty) return [];

    final byId = <String, PropertyModel>{};
    final missing = <String>[];
    for (final id in ids) {
      final cached = propertyProvider.findCached(id);
      if (cached != null) {
        byId[id] = cached;
      } else {
        missing.add(id);
      }
    }

    if (missing.isNotEmpty) {
      final rows = await _propertyService.getPropertiesByIds(missing);
      for (final row in rows) {
        final model = PropertyModel.fromSupabase(row);
        byId[model.id] = model;
      }
    }

    return [
      for (final id in ids)
        if (byId.containsKey(id)) byId[id]!,
    ];
  }

  // ─── Compare actions ─────────────────────────────────────────

  Future<void> _openPicker() async {
    final compareProvider = context.read<CompareProvider>();
    final propertyProvider = context.read<PropertyProvider>();

    final candidates = propertyProvider.properties.where((p) {
      if (compareProvider.isSelected(p.id)) return false;
      return compareProvider.canAdd(p);
    }).toList();

    final result = await showModalBottomSheet<PropertyModel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PropertyPickerSheet(properties: candidates),
    );
    if (result == null || !mounted) return;

    final addResult = compareProvider.add(result);
    if (addResult == CompareAddResult.limitReached ||
        addResult == CompareAddResult.categoryMismatch) {
      _showMessage(_messageFor(addResult));
      return;
    }
    _loadProperties();
  }

  void _removeProperty(String propertyId) {
    context.read<CompareProvider>().remove(propertyId);
    _loadProperties();
  }

  void _clearAll() {
    context.read<CompareProvider>().clear();
    _loadProperties();
  }

  String _messageFor(CompareAddResult result) {
    switch (result) {
      case CompareAddResult.limitReached:
        return 'You can compare up to ${CompareProvider.maxCompare} properties at a time.';
      case CompareAddResult.categoryMismatch:
        return "Can't compare these — you can only compare properties of the "
            'same category and listing type.';
      case CompareAddResult.added:
      case CompareAddResult.removed:
        return '';
    }
  }

  void _showMessage(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  // ─── UI ─────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final compareProvider = context.watch<CompareProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            children: [
              _buildAppBar(compareProvider),
              if (_unavailableCount > 0) _buildUnavailableBanner(),
              Expanded(child: _buildBody(compareProvider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(CompareProvider compareProvider) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (_hasError) {
      return _buildErrorState();
    }
    if (_properties.isEmpty) {
      return _buildEmptyState();
    }
    if (_properties.length == 1) {
      return _buildSingleSelectedState();
    }

    final canAddMore = _properties.length < CompareProvider.maxCompare;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 12),
          _buildToggleRow(),
          _buildScrollHint(canAddMore: canAddMore),
          const SizedBox(height: 10),
          _buildHeaderStrip(canAddMore: canAddMore),
          const SizedBox(height: 16),
          _buildComparisonMatrix(),
          // Clears the app's persistent floating assistant orb, which can
          // rest anywhere near the bottom of the screen — the last row must
          // never end up hidden underneath it.
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  /// A visible cue that there's more to see by swiping — the real-device
  /// pass flagged the horizontal scroll as not obvious on its own. Shown
  /// whenever there are more columns (properties + a possible "Add" tile)
  /// than comfortably fit on a phone width at once.
  Widget _buildScrollHint({required bool canAddMore}) {
    final totalColumns = _properties.length + (canAddMore ? 1 : 0);
    if (totalColumns <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Row(
        children: [
          const Icon(
            Icons.swipe_left_alt_outlined,
            size: 14,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 4),
          Text(
            'Swipe to compare all ${_properties.length} properties',
            style: AppTextStyles.caption.copyWith(
              fontSize: 10.5,
              color: AppColors.textHint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(CompareProvider compareProvider) {
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
              child: const Icon(
                Icons.arrow_back_ios_new,
                size: 16,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compare Properties', style: AppTextStyles.heading2),
                Text(
                  compareProvider.count == 0
                      ? 'Side-by-side comparison'
                      : '${compareProvider.count}/${CompareProvider.maxCompare} selected',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (compareProvider.count > 0)
            TextButton(onPressed: _clearAll, child: const Text('Clear All')),
        ],
      ),
    );
  }

  Widget _buildUnavailableBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _unavailableCount == 1
                  ? 'A property in your comparison is no longer available and was removed.'
                  : '$_unavailableCount properties in your comparison are no longer available and were removed.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              "Couldn't load your comparison",
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadProperties,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.compare_arrows_rounded,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add at least 2 properties to compare',
              style: AppTextStyles.heading3,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the compare icon on any listing, or add one below.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openPicker,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Property'),
            ),
          ],
        ),
      ),
    );
  }

  /// The 1-selected state — shown instead of the near-empty "add one more"
  /// prompt, so the user can actually see and manage the property they
  /// already picked rather than staring at a mostly-blank screen.
  Widget _buildSingleSelectedState() {
    final property = _properties.first;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selected Property', style: AppTextStyles.heading3),
          const SizedBox(height: 12),
          SizedBox(
            width: 220,
            child: _buildHeaderCard(property, isBestValue: false),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _openPicker,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.primary,
                    size: 26,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add another property',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Select at least 2 properties to compare',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text('Compare Details', style: AppTextStyles.heading3),
          ),
          GestureDetector(
            onTap: () => setState(() => _showDiffsOnly = !_showDiffsOnly),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: _showDiffsOnly ? AppColors.primaryGradient : null,
                color: _showDiffsOnly ? null : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: _showDiffsOnly
                    ? AppColors.primaryGlow
                    : AppColors.cardShadow,
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

  // ─── Property header strip ──────────────────────────────────
  //
  // Deliberately its OWN horizontally-scrolling row, with nothing to its
  // left but the screen's normal padding — earlier real-device testing
  // showed property cards rendered as the first "row" inside the matrix's
  // label-column layout inherited that column's width as dead space before
  // Property A. Kept in sync with the matrix below via [_mirrorScroll]
  // rather than a shared `ScrollController` (see the field docs).

  Widget _buildHeaderStrip({required bool canAddMore}) {
    final bestValueIndex = _bestValueIndex(_properties);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        controller: _headerScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < _properties.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: _kColumnWidth,
                  child: _buildHeaderCard(
                    _properties[i],
                    isBestValue: bestValueIndex == i,
                  ),
                ),
              ),
            if (canAddMore) _buildAddColumn(),
          ],
        ),
      ),
    );
  }

  // ─── Comparison matrix ───────────────────────────────────────
  //
  // A fixed attribute-label column (never scrolls) beside a horizontally
  // scrollable row of per-property value columns. Section titles ("Property
  // Details", "Trust & Verification", ...) are NOT rendered inside the
  // narrow label column — that's what made them wrap onto 2-3 lines on a
  // real device. Instead every row/section is first flattened into
  // `_MatrixSlot`s so the label column and every value column can reserve
  // an identical blank slot for a section title, and the actual title text
  // is drawn once, full-width, in a `Positioned` overlay above both — never
  // constrained to the label column's width.

  Widget _buildComparisonMatrix() {
    final sections = _buildSections(_properties);
    final slots = _buildSlots(sections);

    double y = 0;
    final banners = <_SectionBanner>[];
    for (final slot in slots) {
      if (slot.sectionTitle != null) {
        banners.add(_SectionBanner(slot.sectionTitle!, y));
      }
      y += slot.height;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabelColumn(slots),
              Expanded(
                child: Scrollbar(
                  controller: _matrixScrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  child: SingleChildScrollView(
                    controller: _matrixScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < _properties.length; i++)
                          _buildValueColumn(
                            _properties[i],
                            i,
                            slots,
                            allProperties: _properties,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          for (final banner in banners)
            Positioned(
              top: banner.top,
              left: 0,
              right: 0,
              child: Container(
                height: _kSectionCellHeight,
                color: AppColors.background,
                alignment: Alignment.centerLeft,
                child: Text(
                  banner.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Flattens visible sections/rows into a single ordered slot list — the
  /// label column, every value column, and the banner-offset computation
  /// above all walk this SAME list, so a section or row that's hidden by
  /// "Differences only" disappears from all three consistently.
  List<_MatrixSlot> _buildSlots(List<_CompareSection> sections) {
    final slots = <_MatrixSlot>[];
    for (final section in sections) {
      if (!_sectionHasVisibleRows(section)) continue;
      slots.add(_MatrixSlot.section(section.title));
      for (final row in section.rows) {
        if (!_showDiffsOnly || row.valuesDiffer(_properties)) {
          slots.add(_MatrixSlot.row(row));
        }
      }
    }
    return slots;
  }

  bool _sectionHasVisibleRows(_CompareSection section) {
    if (!_showDiffsOnly) return true;
    return section.rows.any((row) => row.valuesDiffer(_properties));
  }

  Widget _buildLabelColumn(List<_MatrixSlot> slots) {
    return Container(
      width: _kLabelColumnWidth,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final slot in slots)
            if (slot.sectionTitle != null)
              // Blank — the real title is drawn once, full-width, by the
              // `Positioned` banner in `_buildComparisonMatrix`.
              SizedBox(height: slot.height)
            else
              Container(
                height: slot.height,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Icon(slot.row!.icon, size: 13, color: AppColors.primary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        slot.row!.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildValueColumn(
    PropertyModel property,
    int index,
    List<_MatrixSlot> slots, {
    required List<PropertyModel> allProperties,
  }) {
    return Container(
      width: _kColumnWidth,
      margin: const EdgeInsets.only(right: 8),
      child: Column(
        children: [
          for (final slot in slots)
            if (slot.sectionTitle != null)
              SizedBox(height: slot.height)
            else
              _buildValueCell(slot.row!, property, allProperties, index),
        ],
      ),
    );
  }

  Widget _buildValueCell(
    _CompareRow row,
    PropertyModel property,
    List<PropertyModel> allProperties,
    int index,
  ) {
    final bestIndex = row.bestIndex?.call(allProperties);
    final isWinner = bestIndex == index;
    final isDiff = row.valuesDiffer(allProperties);

    return Container(
      height: row.height ?? _kDataCellHeight,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isWinner
              ? AppColors.success.withOpacity(0.12)
              : (isDiff ? AppColors.error.withOpacity(0.05) : null),
          borderRadius: BorderRadius.circular(6),
        ),
        child: row.buildValue != null
            ? row.buildValue!(property)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isWinner) ...[
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 10,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 3),
                  ],
                  Flexible(
                    child: Text(
                      row.getValue(property),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isWinner
                            ? AppColors.success
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeaderCard(PropertyModel property, {required bool isBestValue}) {
    return Container(
      height: _kHeaderCellHeight,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
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
                  property.imageUrl,
                  height: _kHeaderImageHeight,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: _kHeaderImageHeight,
                    color: AppColors.primaryLight,
                    child: const Icon(
                      Icons.home_outlined,
                      size: 28,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: () => _removeProperty(property.id),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.cardShadow,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (property.isVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.verifiedBadge,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '✓ Verified',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (isBestValue) ...[
                      if (property.isVerified) const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '★ Best Value',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  property.title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  property.location,
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  property.priceDisplay,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.priceColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddColumn() {
    return Container(
      width: _kAddColumnWidth,
      child: GestureDetector(
        onTap: _openPicker,
        child: Container(
          height: _kHeaderCellHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            border: Border.all(color: AppColors.textHint),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Best Value + row/section construction ──────────────────

  /// Lowest valid price-per-area among the compared set — mirrors the
  /// portal's `bestValuePropertyId` (CompareProperties.tsx). Null/zero
  /// price or area are treated as "no bid" rather than a false zero, and a
  /// tie shows the badge on nobody, same policy as every per-row winner.
  int? _bestValueIndex(List<PropertyModel> properties) {
    return _bestIndexByValue([
      for (final p in properties)
        (p.price > 0 && p.sqft > 0) ? p.price / p.sqft : null,
    ], higherIsBetter: false);
  }

  List<_CompareSection> _buildSections(List<PropertyModel> properties) {
    if (properties.isEmpty) return [];
    final category = properties.first.category;

    return [
      _CompareSection('Basic Info', [
        _CompareRow(
          label: 'Category',
          icon: Icons.category_outlined,
          getValue: (p) => _categoryLabel(p.category),
        ),
        _CompareRow(
          label: 'Listing Type',
          icon: Icons.sell_outlined,
          getValue: (p) => _listingTypeLabel(p.propertyType),
        ),
        _CompareRow(
          label: 'Status',
          icon: Icons.check_circle_outline,
          getValue: (p) =>
              p.possessionStatus ??
              (p.statusTags.isNotEmpty ? p.statusTags.first : '—'),
        ),
      ]),
      _CompareSection('Pricing', [
        _CompareRow(
          label: 'Price',
          icon: Icons.currency_rupee,
          getValue: (p) => p.priceDisplay,
          bestIndex: (props) => _bestIndexByValue([
            for (final p in props) p.price > 0 ? p.price : null,
          ], higherIsBetter: false),
        ),
        _CompareRow(
          label: 'Price/Sqft',
          icon: Icons.square_foot,
          getValue: (p) => (p.price > 0 && p.sqft > 0)
              ? '₹${(p.price / p.sqft).toStringAsFixed(0)}'
              : (p.pricePerSqft.isNotEmpty ? p.pricePerSqft : '—'),
          bestIndex: (props) => _bestIndexByValue([
            for (final p in props)
              (p.price > 0 && p.sqft > 0) ? p.price / p.sqft : null,
          ], higherIsBetter: false),
        ),
        _CompareRow(
          label: 'Area',
          icon: Icons.straighten,
          getValue: (p) => p.sqft > 0 ? '${p.sqft} sqft' : '—',
          bestIndex: (props) => _bestIndexByValue([
            for (final p in props) p.sqft > 0 ? p.sqft.toDouble() : null,
          ], higherIsBetter: true),
        ),
      ]),
      _CompareSection('Property Details', _propertyDetailRows(category)),
      _CompareSection('Amenities', [
        _CompareRow(
          label: 'Amenities',
          icon: Icons.pool_outlined,
          getValue: (p) => '${p.amenities.length} amenities',
          buildValue: (p) => _buildAmenitiesCell(p.amenities),
          height: _kAmenitiesCellHeight,
        ),
      ]),
      _CompareSection('Trust & Verification', [
        _CompareRow(
          label: 'Verified',
          icon: Icons.verified_outlined,
          getValue: (p) => p.isVerified ? 'Yes' : 'No',
          bestIndex: (props) {
            final anyVerified = props.any((p) => p.isVerified);
            final allSame = props.every(
              (p) => p.isVerified == props.first.isVerified,
            );
            if (!anyVerified || allSame) return null;
            return props.indexWhere((p) => p.isVerified);
          },
        ),
        _CompareRow(
          label: 'Approval',
          icon: Icons.fact_check_outlined,
          getValue: (p) => p.approvalStatus ?? '—',
        ),
      ]),
      _CompareSection('Posted By', [
        _CompareRow(
          label: 'Builder',
          icon: Icons.business_outlined,
          getValue: (p) => p.builderName.isNotEmpty ? p.builderName : '—',
        ),
      ]),
    ];
  }

  /// Category-aware rows — built once off the FIRST property's category,
  /// which is safe because [CompareProvider] enforces every compared
  /// property shares the same category and listing type.
  List<_CompareRow> _propertyDetailRows(String? category) {
    switch (category) {
      case 'commercial':
        return [
          _CompareRow(
            label: 'Washrooms',
            icon: Icons.wc_outlined,
            getValue: (p) => '${p.baths}',
            bestIndex: (props) => _bestIndexByValue([
              for (final p in props) p.baths.toDouble(),
            ], higherIsBetter: true),
          ),
          _CompareRow(
            label: 'Parking',
            icon: Icons.local_parking_outlined,
            getValue: (p) => '${p.parking}',
            bestIndex: (props) => _bestIndexByValue([
              for (final p in props) p.parking.toDouble(),
            ], higherIsBetter: true),
          ),
          _CompareRow(
            label: 'Built-up Area',
            icon: Icons.crop_square,
            getValue: (p) => p.builtUpAreaSqft != null
                ? '${p.builtUpAreaSqft!.toStringAsFixed(0)} sqft'
                : '—',
          ),
          _CompareRow(
            label: 'Carpet Area',
            icon: Icons.crop_square_outlined,
            getValue: (p) => p.carpetAreaSqft != null
                ? '${p.carpetAreaSqft!.toStringAsFixed(0)} sqft'
                : '—',
          ),
          _CompareRow(
            label: 'Floor',
            icon: Icons.layers_outlined,
            getValue: (p) => (p.floorNumber != null && p.totalFloors != null)
                ? '${p.floorNumber} / ${p.totalFloors}'
                : '—',
          ),
          _CompareRow(
            label: 'Furnishing',
            icon: Icons.chair_outlined,
            getValue: (p) => p.furnished == null
                ? '—'
                : (p.furnished! ? 'Furnished' : 'Unfurnished'),
          ),
          _CompareRow(
            label: 'Power Load',
            icon: Icons.bolt_outlined,
            getValue: (p) => p.powerLoadKw != null
                ? '${p.powerLoadKw!.toStringAsFixed(1)} kW'
                : '—',
          ),
          _CompareRow(
            label: 'Cafeteria',
            icon: Icons.local_cafe_outlined,
            getValue: (p) =>
                p.hasCafeteria == null ? '—' : (p.hasCafeteria! ? 'Yes' : 'No'),
          ),
          _CompareRow(
            label: 'Conference Rooms',
            icon: Icons.meeting_room_outlined,
            getValue: (p) =>
                p.conferenceRooms != null ? '${p.conferenceRooms}' : '—',
          ),
        ];
      case 'land':
        return [
          _CompareRow(
            label: 'Boundary Wall',
            icon: Icons.fence_outlined,
            getValue: (p) =>
                p.boundaryWall == null ? '—' : (p.boundaryWall! ? 'Yes' : 'No'),
          ),
          _CompareRow(
            label: 'Water Source',
            icon: Icons.water_drop_outlined,
            getValue: (p) =>
                (p.waterSource != null && p.waterSource!.isNotEmpty)
                ? p.waterSource!
                : '—',
          ),
          _CompareRow(
            label: 'Road Width',
            icon: Icons.add_road_outlined,
            getValue: (p) => p.roadWidthFt != null
                ? '${p.roadWidthFt!.toStringAsFixed(0)} ft'
                : '—',
          ),
          _CompareRow(
            label: 'Soil Type',
            icon: Icons.terrain_outlined,
            getValue: (p) => (p.soilType != null && p.soilType!.isNotEmpty)
                ? p.soilType!
                : '—',
          ),
          _CompareRow(
            label: 'Slope',
            icon: Icons.trending_up_rounded,
            getValue: (p) => p.slopePercentage != null
                ? '${p.slopePercentage!.toStringAsFixed(1)}%'
                : '—',
          ),
        ];
      case 'residential':
        return [
          _CompareRow(
            label: 'Bedrooms',
            icon: Icons.bed_outlined,
            getValue: (p) => '${p.beds} BHK',
            bestIndex: (props) => _bestIndexByValue([
              for (final p in props) p.beds.toDouble(),
            ], higherIsBetter: true),
          ),
          _CompareRow(
            label: 'Bathrooms',
            icon: Icons.bathtub_outlined,
            getValue: (p) => '${p.baths}',
            bestIndex: (props) => _bestIndexByValue([
              for (final p in props) p.baths.toDouble(),
            ], higherIsBetter: true),
          ),
          _CompareRow(
            label: 'Balconies',
            icon: Icons.balcony_outlined,
            getValue: (p) => p.balconies != null ? '${p.balconies}' : '—',
          ),
          _CompareRow(
            label: 'Furnishing',
            icon: Icons.chair_outlined,
            getValue: (p) => p.furnished == null
                ? '—'
                : (p.furnished! ? 'Furnished' : 'Unfurnished'),
          ),
          _CompareRow(
            label: 'Parking',
            icon: Icons.local_parking_outlined,
            getValue: (p) => '${p.parking}',
            bestIndex: (props) => _bestIndexByValue([
              for (final p in props) p.parking.toDouble(),
            ], higherIsBetter: true),
          ),
          _CompareRow(
            label: 'Floor',
            icon: Icons.layers_outlined,
            getValue: (p) => (p.floorNumber != null && p.totalFloors != null)
                ? '${p.floorNumber} / ${p.totalFloors}'
                : '—',
          ),
          _CompareRow(
            label: 'Facing',
            icon: Icons.explore_outlined,
            getValue: (p) =>
                (p.facingDirection != null && p.facingDirection!.isNotEmpty)
                ? p.facingDirection!
                : '—',
          ),
          _CompareRow(
            label: 'Age',
            icon: Icons.calendar_today_outlined,
            getValue: (p) =>
                p.ageOfProperty != null ? '${p.ageOfProperty} yrs' : '—',
          ),
        ];
      // Mirrors the portal's own CompareProperties.tsx, which only ever
      // renders category-specific detail rows for residential, commercial
      // and land — PG/co-living and Other get no extra section there at
      // all. This used to fall through to the residential case above, so
      // an Other/PG listing (which has no properties_residential row, and
      // therefore PropertyModel.beds/baths hardcoded at 0 — see
      // property_model.dart's `fromSupabase`) showed "Bedrooms: 0 BHK" and
      // "Bathrooms: 0" here.
      case 'pg_coliving':
      default:
        return const [];
    }
  }

  Widget _buildAmenitiesCell(List<AmenityModel> amenities) {
    if (amenities.isEmpty) {
      return Text(
        '—',
        textAlign: TextAlign.center,
        style: AppTextStyles.caption,
      );
    }
    const int cap = 3;
    final shown = amenities.take(cap).toList();
    final remaining = amenities.length - shown.length;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final amenity in shown)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              amenity.name,
              style: const TextStyle(fontSize: 9, color: AppColors.primary),
            ),
          ),
        if (remaining > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '+$remaining more',
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.textSecondary,
              ),
            ),
          ),
      ],
    );
  }

  String _categoryLabel(String? category) {
    switch (category) {
      case 'residential':
        return 'Residential';
      case 'commercial':
        return 'Commercial';
      case 'land':
        return 'Land';
      case 'pg_coliving':
        return 'PG/Co-living';
      case 'others':
        return 'Others';
      default:
        return category ?? '—';
    }
  }

  String _listingTypeLabel(String? propertyType) {
    switch (propertyType) {
      case 'sell':
        return 'Buy';
      case 'rent':
        return 'Rent';
      case 'lease':
        return 'Lease';
      default:
        return propertyType ?? '—';
    }
  }
}

// Fixed cell sizing for the label-column + horizontally-scrollable
// value-columns layout — every value column and the label column share
// these exact heights row-for-row, so nothing needs to sync two separate
// scroll positions: the header card is just the first "row" inside each
// column, scrolling together with the rest by construction.
//
// Column width is a sensible minimum for mobile (168 dp comfortably fits a
// price, a 2-line title and labels like "PG/Co-living" without clipping),
// not a shrink-to-fit share of the screen — real-device testing showed a
// narrower fixed width clipping exactly that content.
const double _kLabelColumnWidth = 98;
const double _kColumnWidth = 168;
const double _kAddColumnWidth = 110;
const double _kHeaderCellHeight = 184;
const double _kHeaderImageHeight = 66;
const double _kSectionCellHeight = 28;
const double _kDataCellHeight = 46;
// Amenity chips wrap onto up to two lines; the default row height clips
// them, so this one row gets its own taller slot (both the label cell and
// the value cells for this row use it, so alignment is unaffected).
const double _kAmenitiesCellHeight = 60;

/// Index of the best (lowest/highest, per [higherIsBetter]) value in
/// [values], or null when nobody has a valid value or the best value is
/// tied — never guesses at a winner from incomplete or equal data.
int? _bestIndexByValue(List<double?> values, {required bool higherIsBetter}) {
  double? best;
  int? bestIndex;
  bool tie = false;
  for (var i = 0; i < values.length; i++) {
    final v = values[i];
    if (v == null) continue;
    if (best == null || (higherIsBetter ? v > best : v < best)) {
      best = v;
      bestIndex = i;
      tie = false;
    } else if (v == best) {
      tie = true;
    }
  }
  if (bestIndex == null || tie) return null;
  return bestIndex;
}

// ─────────────────────────────────────────────
//  Compare Row / Section data classes
// ─────────────────────────────────────────────
class _CompareSection {
  final String title;
  final List<_CompareRow> rows;
  const _CompareSection(this.title, this.rows);
}

class _CompareRow {
  final String label;
  final IconData icon;
  final String Function(PropertyModel) getValue;

  /// Optional custom cell content (e.g. amenity chips) — falls back to a
  /// plain centred [getValue] text when absent.
  final Widget Function(PropertyModel)? buildValue;

  /// Returns the index of the winning property among the full compared
  /// list, or null when there's no meaningful winner for this row (no
  /// comparator, all-null, or a tie).
  final int? Function(List<PropertyModel>)? bestIndex;

  /// Overrides [_kDataCellHeight] for rows whose content needs more room
  /// (e.g. wrapped amenity chips). The label cell and every value cell for
  /// this row all read the same override, so row alignment never drifts.
  final double? height;

  const _CompareRow({
    required this.label,
    required this.icon,
    required this.getValue,
    this.buildValue,
    this.bestIndex,
    this.height,
  });

  bool valuesDiffer(List<PropertyModel> properties) {
    if (properties.length < 2) return false;
    final first = getValue(properties.first);
    return properties.any((p) => getValue(p) != first);
  }
}

/// One vertical slot in the comparison matrix — either a blank spacer where
/// a full-width section-title banner will be drawn on top, or a data row.
/// The label column and every value column iterate the same list of these,
/// so their heights can never drift out of alignment.
class _MatrixSlot {
  final String? sectionTitle;
  final _CompareRow? row;

  const _MatrixSlot.section(this.sectionTitle) : row = null;
  const _MatrixSlot.row(this.row) : sectionTitle = null;

  double get height => sectionTitle != null
      ? _kSectionCellHeight
      : (row!.height ?? _kDataCellHeight);
}

/// A section title and the vertical offset (within the matrix) its banner
/// should be drawn at — computed once by walking the same `_MatrixSlot`
/// list used to lay out the label/value columns.
class _SectionBanner {
  final String title;
  final double top;
  const _SectionBanner(this.title, this.top);
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
      .where(
        (p) =>
            p.title.toLowerCase().contains(_query.toLowerCase()) ||
            p.location.toLowerCase().contains(_query.toLowerCase()),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    // A `Material` here, not a plain `Container(color: ...)` — the sheet's
    // `ListTile`s need an unobstructed `Material` ancestor for their ink
    // splashes to paint. `showModalBottomSheet` is opened with
    // `backgroundColor: Colors.transparent` (for the rounded-corner look),
    // so its own auto-provided `Material` is transparent; an opaque
    // `Container` sitting between that and the `ListTile`s below silently
    // swallows the splash and logs "ListTile background color or ink
    // splashes may be invisible" on every rebuild.
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
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
                        prefixIcon: Icon(
                          Icons.search,
                          size: 18,
                          color: AppColors.textHint,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.properties.isEmpty
                            ? 'No compatible properties to add'
                            : 'No matches',
                        style: AppTextStyles.caption,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final p = _filtered[i];
                        return ListTile(
                          onTap: () => Navigator.pop(context, p),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
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
                                child: const Icon(
                                  Icons.home_outlined,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ),
                          title: Text(
                            p.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            p.location,
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text(
                            p.priceDisplay,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.priceColor,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
