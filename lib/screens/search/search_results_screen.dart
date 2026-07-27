import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/property_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/available_locations_provider.dart';
import '../../models/property_model.dart';
import '../../models/search_query_params.dart';
import '../../services/location_service.dart';
import '../../voice_agent/services/intent_stash.dart';
import '../../widgets/status_tag.dart';
import '../../widgets/verified_badge.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/property_search_map_widget.dart';
import '../../widgets/map_property_summary_card.dart';

enum _ViewMode { list, map }

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  _ViewMode _viewMode = _ViewMode.list;
  PropertyModel? _selectedMapProperty;
  final ScrollController _scrollController = ScrollController();
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final propertyProvider = context.read<PropertyProvider>();
      final filterProvider = context.read<FilterProvider>();

      // Bridge: apply voice agent filters from IntentStash before running search.
      final vaFilters =
          IntentStash.get<Map<String, dynamic>>('va_search_filters');
      if (vaFilters != null) {
        filterProvider.resetFilters();

        final propertyType = vaFilters['property_type'] as String?;
        if (propertyType != null) filterProvider.setCategory(propertyType);

        final listingTypeRaw = vaFilters['listing_type'] as String?;
        if (listingTypeRaw != null) {
          // AI emits "sale"; FilterProvider expects "sell".
          final listingType =
              listingTypeRaw == 'sale' ? 'sell' : listingTypeRaw;
          filterProvider.setListingType(listingType);
        }

        final bedrooms = vaFilters['bedrooms'];
        if (bedrooms != null) {
          filterProvider.setBhk(int.tryParse(bedrooms.toString()));
        }

        final city = vaFilters['city'] as String?;
        if (city != null && city.isNotEmpty) {
          filterProvider.setCities([city]);
        }

        final minPrice =
            double.tryParse(vaFilters['min_price']?.toString() ?? '') ??
                AppConstants.priceMin;
        final maxPrice =
            double.tryParse(vaFilters['max_price']?.toString() ?? '') ??
                AppConstants.priceMax;
        filterProvider.setBudgetRange(RangeValues(minPrice, maxPrice));

        IntentStash.remove('va_search_filters');
      }

      propertyProvider.runSearch(filterProvider.toQueryParams(), reset: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      final filterProvider = context.read<FilterProvider>();
      context
          .read<PropertyProvider>()
          .loadMoreResults(filterProvider.toQueryParams());
    }
  }

  void _setViewMode(_ViewMode mode) {
    setState(() => _viewMode = mode);
    if (mode == _ViewMode.map) {
      // Always reload — do NOT gate this behind a "loaded once" flag. The
      // map previously cached its very first load forever, so changing
      // filters/sort/near-me (or applying filters and coming back) left it
      // showing stale pins that no longer matched the active search. Every
      // switch into map view now re-fetches with the current filters.
      final filterProvider = context.read<FilterProvider>();
      context.read<PropertyProvider>().loadMapResults(filterProvider.toQueryParams());
    }
  }

  /// Single choke point for "a filter/sort/location change happened" — runs
  /// the list search and, if the map is the currently active view, also
  /// refreshes it with the same params. Without this, each filter-changing
  /// action (sort, city, near-me, the Filters screen) only ever updated the
  /// list, leaving an already-open map silently out of sync.
  void _runSearchAndSyncMap() {
    final filterProvider = context.read<FilterProvider>();
    final propertyProvider = context.read<PropertyProvider>();
    final params = filterProvider.toQueryParams();
    propertyProvider.runSearch(params, reset: true);
    if (_viewMode == _ViewMode.map) {
      propertyProvider.loadMapResults(params);
    }
  }

  Future<void> _handleNearMeTap() async {
    final filterProvider = context.read<FilterProvider>();

    if (filterProvider.nearMeEnabled) {
      filterProvider.disableNearMe();
      _runSearchAndSyncMap();
      return;
    }

    final result = await _locationService.getCurrentPosition();
    if (!mounted) return;
    if (result.isSuccess) {
      filterProvider.enableNearMe(result.latitude!, result.longitude!);
      _runSearchAndSyncMap();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Location access is needed to show properties near you.'),
        ),
      );
    }
  }

  void _openFiltersScreen() {
    // Filters are applied on the FiltersScreen itself (it calls runSearch
    // directly), but that screen has no idea whether this screen is
    // currently showing the map — so refresh the map here, once control
    // returns, if that's the active view.
    Navigator.pushNamed(context, AppConstants.filtersScreen).then((_) {
      if (!mounted || _viewMode != _ViewMode.map) return;
      final filterProvider = context.read<FilterProvider>();
      context.read<PropertyProvider>().loadMapResults(filterProvider.toQueryParams());
    });
  }

  void _showSortSheet() {
    final filterProvider = context.read<FilterProvider>();
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in PropertySortOption.values)
                ListTile(
                  title: Text(option.label),
                  trailing: filterProvider.sort == option
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    filterProvider.setSort(option);
                    _runSearchAndSyncMap();
                    Navigator.pop(sheetContext);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showCityPicker() {
    final filterProvider = context.read<FilterProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          expand: false,
          builder: (context, scrollController) {
            return Consumer<AvailableLocationsProvider>(
              builder: (context, locationsProvider, child) {
                if (locationsProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  controller: scrollController,
                  children: [
                    ListTile(
                      title: const Text('All Cities'),
                      trailing: filterProvider.cities.isEmpty
                          ? const Icon(Icons.check, color: AppColors.primary)
                          : null,
                      onTap: () {
                        filterProvider.setCities([]);
                        _runSearchAndSyncMap();
                        Navigator.pop(sheetContext);
                      },
                    ),
                    for (final location in locationsProvider.locations)
                      ListTile(
                        title: Text(location.city),
                        subtitle:
                            location.state != null ? Text(location.state!) : null,
                        trailing: filterProvider.cities.contains(location.city)
                            ? const Icon(Icons.check, color: AppColors.primary)
                            : null,
                        onTap: () {
                          filterProvider.setCities([location.city]);
                          _runSearchAndSyncMap();
                          Navigator.pop(sheetContext);
                        },
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  String _categoryDisplayName(String category) {
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
        return category;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            _buildFilterChips(context),
            _buildPromoBanner(),
            Expanded(
              child: _viewMode == _ViewMode.list
                  ? _buildListView()
                  : _buildMapView(),
            ),
            _buildBottomActionBar(context),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 1,
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final filterProvider = context.watch<FilterProvider>();
    final propertyProvider = context.watch<PropertyProvider>();
    final cityLabel =
        filterProvider.cities.isNotEmpty ? filterProvider.cities.first : 'All Cities';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () => Navigator.pop(context),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: _showCityPicker,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          cityLabel,
                          style: AppTextStyles.heading2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 20),
                    ],
                  ),
                  Text(
                    '${propertyProvider.totalResultCount} Properties',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              filterProvider.nearMeEnabled ? Icons.near_me : Icons.near_me_outlined,
              size: 20,
            ),
            color: filterProvider.nearMeEnabled ? AppColors.primary : null,
            onPressed: _handleNearMeTap,
          ),
          IconButton(
            icon: Icon(
              _viewMode == _ViewMode.list ? Icons.map_outlined : Icons.list,
              size: 20,
            ),
            onPressed: () => _setViewMode(
              _viewMode == _ViewMode.list ? _ViewMode.map : _ViewMode.list,
            ),
          ),
          TextButton(
            onPressed: _showSortSheet,
            child: Text('↕ ${filterProvider.sort.label}'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filterProvider = context.watch<FilterProvider>();

    final listingTypeLabel = switch (filterProvider.listingType) {
      'sell' => 'Buy',
      'rent' => 'Rent',
      'lease' => 'Lease',
      _ => 'Buy/Rent ▾',
    };
    final categoryLabel = filterProvider.category != null
        ? _categoryDisplayName(filterProvider.category!)
        : 'Property Type ▾';
    final isDefaultBudget = filterProvider.budgetRange.start <= AppConstants.priceMin &&
        filterProvider.budgetRange.end >= AppConstants.priceMax;
    final priceLabel = isDefaultBudget
        ? 'Price ▾'
        : '${PropertyModel.formatIndianPrice(filterProvider.budgetRange.start)}'
            ' - ${PropertyModel.formatIndianPrice(filterProvider.budgetRange.end)}';

    final chips = <String>[
      '🔧 Filters',
      listingTypeLabel,
      categoryLabel,
      priceLabel,
    ];

    return SizedBox(
      height: AppConstants.filterChipHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isFiltersChip = index == 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: _openFiltersScreen,
              child: Stack(
                children: [
                  Container(
                    height: AppConstants.filterChipHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.textHint.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        chip,
                        style: AppTextStyles.chip,
                      ),
                    ),
                  ),
                  if (isFiltersChip && filterProvider.activeFilterCount > 0)
                    Positioned(
                      right: 8,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${filterProvider.activeFilterCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: AppConstants.promoBannerHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EFFE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.star,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Looking for the perfect home?',
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Let us help you find it.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Get Help',
              style: TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () {},
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final properties = propertyProvider.searchResults;

        if (propertyProvider.isSearching && properties.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (properties.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: properties.length + (propertyProvider.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= properties.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              );
            }
            return _buildPropertyListItem(context, properties[index], propertyProvider);
          },
        );
      },
    );
  }

  /// Filter-aware empty state — lists exactly which filters are currently
  /// applied (a narrow price range especially is easy to set without
  /// noticing and then silently zero out every later search) and offers a
  /// one-tap way to clear them, instead of a generic "no results" message
  /// that gives no clue why.
  Widget _buildEmptyState() {
    final filterProvider = context.watch<FilterProvider>();
    final isDefaultBudget = filterProvider.budgetRange.start <= AppConstants.priceMin &&
        filterProvider.budgetRange.end >= AppConstants.priceMax;

    final activeDescriptions = <String>[
      if (!isDefaultBudget)
        '${PropertyModel.formatIndianPrice(filterProvider.budgetRange.start)} - '
            '${PropertyModel.formatIndianPrice(filterProvider.budgetRange.end)}',
      if (filterProvider.category != null)
        _categoryDisplayName(filterProvider.category!),
      if (filterProvider.listingType != null) filterProvider.listingType!,
      if (filterProvider.bhk != null)
        filterProvider.bhk == 5 ? '5+ BHK' : '${filterProvider.bhk} BHK',
      if (filterProvider.postedBy != null) 'Posted by ${filterProvider.postedBy}',
      if (filterProvider.cities.isNotEmpty) filterProvider.cities.join(', '),
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              activeDescriptions.isEmpty
                  ? 'No properties found'
                  : 'No properties match these filters',
              style: AppTextStyles.heading2.copyWith(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            if (activeDescriptions.isNotEmpty) ...[
              Text(
                'Currently applied: ${activeDescriptions.join(' • ')}',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  filterProvider.resetFilters();
                  _runSearchAndSyncMap();
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                ),
                child: const Text('Clear All Filters'),
              ),
            ] else
              Text(
                'Try adjusting your search or checking back later.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        return Stack(
          children: [
            PropertySearchMapWidget(
              properties: propertyProvider.mapResults,
              selectedProperty: _selectedMapProperty,
              onMarkerTap: (property) {
                setState(() => _selectedMapProperty = property);
              },
            ),
            if (_selectedMapProperty != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: MapPropertySummaryCard(
                  property: _selectedMapProperty!,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppConstants.propertyDetailScreen,
                      arguments: {'propertyId': _selectedMapProperty!.id},
                    );
                  },
                  onClose: () => setState(() => _selectedMapProperty = null),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPropertyListItem(
      BuildContext context, PropertyModel property, PropertyProvider propertyProvider) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppConstants.propertyDetailScreen,
          arguments: {'propertyId': property.id},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppConstants.cardRadius),
                    bottomLeft: Radius.circular(AppConstants.cardRadius),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: property.imageUrl,
                    width: AppConstants.propertyListItemImageSize,
                    height: AppConstants.propertyListItemImageSize,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.textHint.withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: AppColors.textHint.withOpacity(0.1),
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
                if (property.isVerified)
                  const Positioned(
                    top: 8,
                    left: 8,
                    child: VerifiedBadge(),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () {
                      propertyProvider.toggleShortlist(property.id);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        property.isShortlisted
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: property.isShortlisted
                            ? Colors.red
                            : AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 10,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${property.photoCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            property.title,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 20),
                          onPressed: () {},
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.location,
                            style: AppTextStyles.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      property.priceDisplay,
                      style: AppTextStyles.price.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      property.pricePerSqft,
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildSpecIcon(Icons.bed, '${property.beds}'),
                        const SizedBox(width: 12),
                        _buildSpecIcon(Icons.bathtub, '${property.baths}'),
                        const SizedBox(width: 12),
                        _buildSpecIcon(Icons.square_foot, '${property.sqft}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                     children: List<Widget>.from(
  property.statusTags.take(2).map(
    (tag) => StatusTag(label: tag.toString()),
  ),
),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecIcon(IconData icon, String value) {
    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 4),
        Text(
          value,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      height: AppConstants.bottomActionBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.textHint,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              icon: Icons.bookmark_border,
              label: 'Save Search',
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Get Alert',
                    style: AppTextStyles.button.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              icon: Icons.compare_arrows,
              label: 'Compare',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
