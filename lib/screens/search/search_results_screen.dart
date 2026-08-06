import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/property_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/available_locations_provider.dart';
import '../../models/property_model.dart';
import '../../models/search_query_params.dart';
import '../../models/smart_query_result.dart';
import '../../services/location_service.dart';
import '../../voice_agent/services/intent_stash.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/property_search_map_widget.dart';
import 'widgets/active_filter_chip_row.dart';
import 'widgets/ai_confirmation_strip.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/map_card_strip.dart';
import 'widgets/property_card_search_grid.dart';
import 'widgets/property_card_search_row.dart';
import 'widgets/property_quick_preview_sheet.dart';
import 'widgets/search_error_state.dart';
import 'widgets/search_result_skeletons.dart';
import 'widgets/search_results_header.dart';
import 'widgets/view_switcher.dart';

class SearchResultsScreen extends StatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  SearchViewMode _viewMode = SearchViewMode.list;
  PropertyModel? _selectedMapProperty;

  /// What the AI understood from the query that landed the user here, or null
  /// when this search did not come from a natural-language parse.
  SmartQueryResult? _aiUnderstanding;

  // One controller per scrollable surface. A single shared controller would be
  // attached to two scroll views the moment both existed, and each surface has
  // its own extent anyway — this way List and Grid each remember their own
  // offset across a switch instead of snapping back to the top.
  final ScrollController _listController = ScrollController();
  final ScrollController _gridController = ScrollController();

  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _listController.addListener(_onListScroll);
    _gridController.addListener(_onGridScroll);
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

      // Read-and-remove, the same contract the voice-agent key above uses, so
      // the strip shows once for the search that produced it and does not
      // resurface on a later visit.
      final aiResult =
          IntentStash.get<SmartQueryResult>(kAiUnderstandingKey);
      if (aiResult != null) {
        IntentStash.remove(kAiUnderstandingKey);
        setState(() => _aiUnderstanding = aiResult);
      }

      propertyProvider.runSearch(filterProvider.toQueryParams(), reset: true);
    });
  }

  /// Cleared as soon as the user touches any other control, so the strip never
  /// describes a search that has since been changed underneath it.
  void _dismissAiStrip() {
    if (_aiUnderstanding == null) return;
    setState(() => _aiUnderstanding = null);
  }

  /// The facets the AI extracted, formatted for the confirmation strip.
  ///
  /// Includes the detected city, which the active-filter chip row deliberately
  /// leaves out — that omission mirrors the website's filter-badge rule, but a
  /// misread city is exactly the kind of thing worth surfacing here.
  List<String> _aiFacetLabels(SmartQueryResult result) {
    return <String>[
      if (result.city != null && result.city!.isNotEmpty) result.city!,
      if (result.category != null) _categoryDisplayName(result.category!),
      if (result.listingType != null)
        _listingTypeDisplayName(result.listingType!),
      if (result.bhk != null) _bhkLabel(result.bhk!),
      if (result.budgetMin != null || result.budgetMax != null)
        '${PropertyModel.formatIndianPrice(result.budgetMin ?? AppConstants.priceMin)}'
            ' - ${PropertyModel.formatIndianPrice(result.budgetMax ?? AppConstants.priceMax)}',
    ];
  }

  @override
  void dispose() {
    _listController.removeListener(_onListScroll);
    _listController.dispose();
    _gridController.removeListener(_onGridScroll);
    _gridController.dispose();
    super.dispose();
  }

  void _onListScroll() => _maybeLoadMore(_listController);
  void _onGridScroll() => _maybeLoadMore(_gridController);

  /// Unchanged pagination trigger, parameterised so both surfaces share it.
  void _maybeLoadMore(ScrollController controller) {
    if (!controller.hasClients) return;
    if (controller.position.pixels >=
        controller.position.maxScrollExtent - 300) {
      final filterProvider = context.read<FilterProvider>();
      context
          .read<PropertyProvider>()
          .loadMoreResults(filterProvider.toQueryParams());
    }
  }

  void _setViewMode(SearchViewMode mode) {
    // A segmented control is a discrete selection — the lightest tick available.
    HapticFeedback.selectionClick();
    setState(() => _viewMode = mode);
    if (mode == SearchViewMode.map) {
      // Always reload — do NOT gate this behind a "loaded once" flag. The
      // map previously cached its very first load forever, so changing
      // filters/sort/near-me (or applying filters and coming back) left it
      // showing stale pins that no longer matched the active search. Every
      // switch into map view now re-fetches with the current filters.
      final filterProvider = context.read<FilterProvider>();
      context
          .read<PropertyProvider>()
          .loadMapResults(filterProvider.toQueryParams());
    }
  }

  /// Single choke point for "a filter/sort/location change happened" — runs
  /// the list search and, if the map is the currently active view, also
  /// refreshes it with the same params. Without this, each filter-changing
  /// action (sort, city, near-me, the Filters screen) only ever updated the
  /// list, leaving an already-open map silently out of sync.
  void _runSearchAndSyncMap() {
    // Every filter/sort/city change funnels through here, which makes it the one
    // place that needs to retire the AI strip.
    _dismissAiStrip();
    final filterProvider = context.read<FilterProvider>();
    final propertyProvider = context.read<PropertyProvider>();
    final params = filterProvider.toQueryParams();
    propertyProvider.runSearch(params, reset: true);
    if (_viewMode == SearchViewMode.map) {
      propertyProvider.loadMapResults(params);
    }
  }

  /// Re-issues the identical search after a failure.
  ///
  /// Separate from `_runSearchAndSyncMap` on purpose: that path also retires the
  /// AI confirmation strip, because it is only ever reached by the user changing
  /// a filter. A retry changes nothing about the query, so the interpretation of
  /// it is still accurate and stays on screen.
  void _retrySearch() {
    final filterProvider = context.read<FilterProvider>();
    final propertyProvider = context.read<PropertyProvider>();
    final params = filterProvider.toQueryParams();
    propertyProvider.runSearch(params, reset: true);
    if (_viewMode == SearchViewMode.map) {
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

  /// Opens the filter sheet and, only if the user actually applied something,
  /// re-runs the search through the existing choke point.
  ///
  /// The sheet commits to FilterProvider and reports back; it never runs a query
  /// itself. Routing the result through `_runSearchAndSyncMap` means the map is
  /// refreshed automatically when it is the active view, which the old
  /// push-to-`/filters` flow had to special-case by hand.
  Future<void> _openFiltersScreen() async {
    final bool applied = await showSearchFilterSheet(context);
    if (!mounted || !applied) return;
    _runSearchAndSyncMap();
  }

  /// Serves both the Back button and the query pill.
  ///
  /// They coexist by design — the redesign makes the pill the way back to the
  /// Search Entry screen, and the explicit arrow is kept for consistency with
  /// the rest of the app — and popping is the right behaviour for both: it
  /// restores the previous Search Entry instance with the user's typed query
  /// still in its field, which is exactly what "edit my search" should do.
  ///
  /// `canPop` is checked because the voice agent can navigate straight here
  /// with no entry screen beneath.
  void _navigateBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, AppConstants.searchScreen);
    }
  }

  void _openPropertyDetail(PropertyModel property) {
    Navigator.pushNamed(
      context,
      AppConstants.propertyDetailScreen,
      arguments: {'propertyId': property.id},
    );
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

  String _listingTypeDisplayName(String listingType) {
    switch (listingType) {
      case 'sell':
        return 'Buy';
      case 'rent':
        return 'Rent';
      case 'lease':
        return 'Lease';
      default:
        return listingType;
    }
  }

  bool _isDefaultBudget(FilterProvider filterProvider) =>
      filterProvider.budgetRange.start <= AppConstants.priceMin &&
      filterProvider.budgetRange.end >= AppConstants.priceMax;

  String _budgetLabel(FilterProvider filterProvider) =>
      '${PropertyModel.formatIndianPrice(filterProvider.budgetRange.start)}'
      ' - ${PropertyModel.formatIndianPrice(filterProvider.budgetRange.end)}';

  String _bhkLabel(int bhk) => bhk >= 5 ? '5+ BHK' : '$bhk BHK';

  /// The query the header echoes back: the free-text search if there is one,
  /// otherwise the selected city, otherwise a neutral prompt.
  String _queryLabel(FilterProvider filterProvider) {
    final text = filterProvider.searchText.trim();
    if (text.isNotEmpty) return text;
    if (filterProvider.cities.isNotEmpty) return filterProvider.cities.first;
    return 'Search properties';
  }

  /// Budget and Near Me are both filtered client-side out of one safety-capped
  /// batch (see PropertyProvider.runSearch), so on those branches the count
  /// physically cannot exceed the cap — reporting an exact figure once it gets
  /// there would state a total the query never established. Every other branch
  /// reports the true database count, including a legitimate 300.
  String _resultCountLabel(
    FilterProvider filterProvider,
    PropertyProvider propertyProvider,
  ) {
    final int count = propertyProvider.totalResultCount;
    final bool isCappedBranch =
        !_isDefaultBudget(filterProvider) || filterProvider.nearMeEnabled;
    final bool capped =
        isCappedBranch && count >= AppConstants.mapResultsSafetyCap;
    final String value =
        capped ? '${AppConstants.mapResultsSafetyCap}+' : '$count';
    return '$value Properties';
  }

  /// One chip per facet `FilterProvider.activeFilterCount` counts, so the row
  /// and the filter button's indicator can never disagree.
  List<ActiveFilterChip> _buildActiveChips(FilterProvider filterProvider) {
    final chips = <ActiveFilterChip>[];

    if (filterProvider.category != null) {
      chips.add(ActiveFilterChip(
        label: _categoryDisplayName(filterProvider.category!),
        onRemove: () {
          // Subtype only has meaning underneath a category, so it goes with it.
          // Clearing the category alone would leave a residential subtype
          // filtering the next query with no category behind it.
          filterProvider.setCategory(null);
          filterProvider.setSubtype(null);
          _runSearchAndSyncMap();
        },
      ));
    }

    if (filterProvider.listingType != null) {
      chips.add(ActiveFilterChip(
        label: _listingTypeDisplayName(filterProvider.listingType!),
        onRemove: () {
          filterProvider.setListingType(null);
          _runSearchAndSyncMap();
        },
      ));
    }

    if (!_isDefaultBudget(filterProvider)) {
      chips.add(ActiveFilterChip(
        label: _budgetLabel(filterProvider),
        onRemove: () {
          filterProvider.setBudgetRange(
            const RangeValues(AppConstants.priceMin, AppConstants.priceMax),
          );
          _runSearchAndSyncMap();
        },
      ));
    }

    if (filterProvider.bhk != null) {
      chips.add(ActiveFilterChip(
        label: _bhkLabel(filterProvider.bhk!),
        onRemove: () {
          filterProvider.setBhk(null);
          _runSearchAndSyncMap();
        },
      ));
    }

    if (filterProvider.subtype != null) {
      chips.add(ActiveFilterChip(
        label: filterProvider.subtype!,
        onRemove: () {
          filterProvider.setSubtype(null);
          _runSearchAndSyncMap();
        },
      ));
    }

    if (filterProvider.postedBy != null) {
      chips.add(ActiveFilterChip(
        label: 'Posted by ${filterProvider.postedBy}',
        onRemove: () {
          filterProvider.setPostedBy(null);
          _runSearchAndSyncMap();
        },
      ));
    }

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final filterProvider = context.watch<FilterProvider>();
    final propertyProvider = context.watch<PropertyProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            SearchResultsHeader(
              onBackTap: _navigateBack,
              queryLabel: _queryLabel(filterProvider),
              onQueryTap: _navigateBack,
              activeFilterCount: filterProvider.activeFilterCount,
              onFilterTap: _openFiltersScreen,
              nearMeEnabled: filterProvider.nearMeEnabled,
              onNearMeTap: _handleNearMeTap,
              resultCountLabel:
                  _resultCountLabel(filterProvider, propertyProvider),
              cityLabel: filterProvider.cities.isNotEmpty
                  ? filterProvider.cities.first
                  : 'All Cities',
              onCityTap: _showCityPicker,
              sortLabel: filterProvider.sort.label,
              onSortTap: _showSortSheet,
              activeChips: _buildActiveChips(filterProvider),
              viewMode: _viewMode,
              onViewModeChanged: _setViewMode,
            ),
            if (_aiUnderstanding != null)
              AiConfirmationStrip(
                facets: _aiFacetLabels(_aiUnderstanding!),
                onEditFilters: () {
                  _dismissAiStrip();
                  _openFiltersScreen();
                },
                onDismiss: _dismissAiStrip,
              ),
            Expanded(child: _buildSurface()),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 1,
      ),
    );
  }

  Widget _buildSurface() {
    switch (_viewMode) {
      case SearchViewMode.list:
        return _buildListView();
      case SearchViewMode.grid:
        return _buildGridView();
      case SearchViewMode.map:
        return _buildMapView();
    }
  }

  Widget _buildListView() {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final properties = propertyProvider.searchResults;

        if (propertyProvider.isSearching && properties.isEmpty) {
          return const SearchResultsListSkeleton();
        }
        // Ordered after the loading check so a retry shows the skeleton while it
        // runs, and gated on emptiness so a failed loadMoreResults cannot
        // replace a list the user is already reading.
        if (propertyProvider.hasError && properties.isEmpty) {
          return SearchErrorState(onRetry: _retrySearch);
        }
        if (properties.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _listController,
          padding: const EdgeInsets.fromLTRB(
            AppConstants.spacingXL,
            AppConstants.spacingM,
            AppConstants.spacingXL,
            AppConstants.spacingM,
          ),
          itemCount: properties.length + (propertyProvider.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= properties.length) {
              return _buildLoadMoreIndicator();
            }
            final property = properties[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
              child: PropertyCardSearchRow(
                property: property,
                onTap: () => _openPropertyDetail(property),
                onFavoriteToggle: () {
                  HapticFeedback.lightImpact();
                  propertyProvider.toggleShortlist(property.id);
                },
              ),
            );
          },
        );
      },
    );
  }

  /// A CustomScrollView rather than a GridView.builder so the "loading more"
  /// footer can be its own sliver instead of a grid cell that would inherit the
  /// tile extent and sit in one column.
  Widget _buildGridView() {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final properties = propertyProvider.searchResults;

        if (propertyProvider.isSearching && properties.isEmpty) {
          return const SearchResultsGridSkeleton();
        }
        if (propertyProvider.hasError && properties.isEmpty) {
          return SearchErrorState(onRetry: _retrySearch);
        }
        if (properties.isEmpty) {
          return _buildEmptyState();
        }

        return CustomScrollView(
          controller: _gridController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spacingXL,
                AppConstants.spacingM,
                AppConstants.spacingXL,
                0,
              ),
              sliver: SliverGrid(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: AppConstants.spacingS,
                  mainAxisSpacing: AppConstants.spacingL,
                  mainAxisExtent: kSearchGridTileExtent,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final property = properties[index];
                    return PropertyCardSearchGrid(
                      property: property,
                      onTap: () => _openPropertyDetail(property),
                    );
                  },
                  childCount: properties.length,
                ),
              ),
            ),
            if (propertyProvider.isLoadingMore)
              SliverToBoxAdapter(child: _buildLoadMoreIndicator()),
            const SliverToBoxAdapter(
              child: SizedBox(height: AppConstants.spacingM),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadMoreIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppConstants.spacingL),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  /// Filter-aware empty state — lists exactly which filters are currently
  /// applied (a narrow price range especially is easy to set without
  /// noticing and then silently zero out every later search) and offers a
  /// one-tap way to clear them, instead of a generic "no results" message
  /// that gives no clue why.
  Widget _buildEmptyState() {
    final filterProvider = context.watch<FilterProvider>();

    final activeDescriptions = <String>[
      if (!_isDefaultBudget(filterProvider)) _budgetLabel(filterProvider),
      if (filterProvider.category != null)
        _categoryDisplayName(filterProvider.category!),
      if (filterProvider.listingType != null) filterProvider.listingType!,
      if (filterProvider.bhk != null) _bhkLabel(filterProvider.bhk!),
      if (filterProvider.postedBy != null)
        'Posted by ${filterProvider.postedBy}',
      if (filterProvider.cities.isNotEmpty) filterProvider.cities.join(', '),
    ];

    // Scrollable rather than a bare Column: the fixed 64 dp vertical padding
    // plus the icon, headline and body add up to more than the surface gets
    // once the header, the AI strip and a short viewport all take their share —
    // it overflowed by 17 px in exactly that combination. Scrolling degrades
    // gracefully and costs nothing when there is room, since Center still sizes
    // the content to itself.
    return Center(
      child: SingleChildScrollView(
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
                  style:
                      AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Selects [property] and opens its quick preview.
  ///
  /// Pins and strip cards share this, because the redesign wires both to the
  /// same `openPreview`. Setting the selection first is a bonus the existing map
  /// widget gives for free: it already pans to and ring-highlights whatever
  /// `selectedProperty` it is handed, so tapping a strip card also moves the map
  /// to that property. Clearing the selection on dismiss deselects the pin.
  Future<void> _openQuickPreview(PropertyModel property) async {
    setState(() => _selectedMapProperty = property);

    final bool viewDetails = await showPropertyQuickPreview(context, property);
    if (!mounted) return;

    setState(() => _selectedMapProperty = null);
    if (viewDetails) _openPropertyDetail(property);
  }

  /// Recenters the map on the full result set.
  ///
  /// Implemented as "clear the selection and reload the map results" rather than
  /// by reaching for the map's camera: `PropertySearchMapWidget` already refits
  /// its bounds whenever the property list identity changes, and
  /// `loadMapResults` assigns a fresh list every call. So this refits to every
  /// pin without the widget having to expose its controller — and it doubles as
  /// a refresh against the current filters.
  void _recenterMap() {
    setState(() => _selectedMapProperty = null);
    final filterProvider = context.read<FilterProvider>();
    context
        .read<PropertyProvider>()
        .loadMapResults(filterProvider.toQueryParams());
  }

  Widget _buildMapView() {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final properties = propertyProvider.mapResults;

        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingXL,
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(AppConstants.cardRadius),
                  child: Stack(
                    children: [
                      PropertySearchMapWidget(
                        properties: properties,
                        selectedProperty: _selectedMapProperty,
                        onMarkerTap: (property) {
                          if (property == null) return;
                          _openQuickPreview(property);
                        },
                      ),
                      Positioned(
                        top: 14,
                        right: 14,
                        child: _buildRecenterButton(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (properties.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingM),
              MapCardStrip(
                properties: properties,
                onCardTap: _openQuickPreview,
              ),
            ],
            const SizedBox(height: AppConstants.spacingM),
          ],
        );
      },
    );
  }

  Widget _buildRecenterButton() {
    return Semantics(
      label: 'Recenter map on all results',
      button: true,
      child: GestureDetector(
        onTap: _recenterMap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppConstants.pillRadius),
            boxShadow: AppColors.surfaceCardShadow,
          ),
          child: const Icon(
            Icons.my_location,
            size: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
