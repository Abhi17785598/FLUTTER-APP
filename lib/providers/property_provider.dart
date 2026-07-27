import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/utils/geo_utils.dart';
import '../models/property_model.dart';
import '../models/search_query_params.dart';
import '../services/property_service.dart';

class PropertyProvider extends ChangeNotifier {
  List<PropertyModel> _properties = [];
  // Query-driven search state — replaces the old fetch-everything-then-
  // filter-in-Dart `_filteredProperties`/searchProperties()/applyFilters().
  List<PropertyModel> _searchResults = [];
  List<PropertyModel> _mapResults = [];

  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _hasMoreResults = true;
  int _totalResultCount = 0;
  int _searchOffset = 0;

  // Used only when a non-default budget filter is active — see runSearch.
  // Holds the full budget-filtered matching set so pagination can slice
  // pages out of it in memory, instead of budget-filtering each raw DB page
  // independently (which silently drops real matches that land past the
  // first page).
  List<PropertyModel> _budgetBuffer = [];
  int _budgetBufferCursor = 0;

  List<PropertyModel> get properties => _properties;
  List<PropertyModel> get searchResults => _searchResults;
  List<PropertyModel> get mapResults => _mapResults;
  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreResults => _hasMoreResults;
  // NOTE: reflects the DB-level count (matching filters, before the
  // client-side budget filter below is applied) — see _applyBudgetFilter.
  int get totalResultCount => _totalResultCount;

 PropertyProvider() {
  loadProperties();
}

final PropertyService _propertyService = PropertyService();

Future<void> loadProperties() async {
  try {
    final data = await _propertyService.getProperties();
    _properties = data
        .map((item) => PropertyModel.fromSupabase(item))
        .toList();
    notifyListeners();
  } catch (e) {
    debugPrint('[PropertyProvider] loadProperties failed: $e');
  }
}

  /// Runs (or continues, when `reset: false`) a search against the live
  /// backend for the given filter/sort snapshot. Mirrors Search.tsx's own
  /// branch: normal search pages via `.range()`; near-me fetches a single
  /// safety-capped batch and Haversine-filters/sorts/caps client-side —
  /// see PropertyService.searchProperties and the plan's "Deliberate
  /// deviations" for why these two paths differ.
  Future<void> runSearch(SearchQueryParams params, {bool reset = true}) async {
    if (reset) {
      _searchOffset = 0;
      _searchResults = [];
      _budgetBuffer = [];
      _budgetBufferCursor = 0;
      _hasMoreResults = true;
      _isSearching = true;
      notifyListeners();
    }

    try {
      if (params.nearMeEnabled &&
          params.nearMeLat != null &&
          params.nearMeLng != null) {
        final page = await _propertyService.searchProperties(
          params: params,
          offset: 0,
          limit: AppConstants.mapResultsSafetyCap,
          includeRange: false,
        );
        _searchResults = _applyBudgetAndNearMeFilter(page.rows, params);
        _totalResultCount = _searchResults.length;
        _hasMoreResults = false; // near-me's capped set is fully in memory
      } else if (_isBudgetFilterActive(params)) {
        // Budget is never a DB filter (see _applyBudgetAndNearMeFilter), so
        // it can't be combined with `.range()` DB-level pagination — a page
        // of e.g. 20 DB rows may contain zero budget matches even though
        // real matches exist further down the full result set. Fetch one
        // safety-capped batch, budget-filter the WHOLE batch once, then page
        // through that filtered buffer in memory.
        if (reset) {
          final page = await _propertyService.searchProperties(
            params: params,
            offset: 0,
            limit: AppConstants.mapResultsSafetyCap,
            includeRange: false,
          );
          _budgetBuffer = _applyBudgetAndNearMeFilter(page.rows, params);
          _budgetBufferCursor = 0;
        }
        final nextCursor = (_budgetBufferCursor + AppConstants.searchPageSize)
            .clamp(0, _budgetBuffer.length);
        final pageModels =
            _budgetBuffer.sublist(_budgetBufferCursor, nextCursor);
        _searchResults =
            reset ? pageModels : [..._searchResults, ...pageModels];
        _budgetBufferCursor = nextCursor;
        _totalResultCount = _budgetBuffer.length;
        _hasMoreResults = _budgetBufferCursor < _budgetBuffer.length;
      } else {
        final page = await _propertyService.searchProperties(
          params: params,
          offset: _searchOffset,
          limit: AppConstants.searchPageSize,
        );
        // Budget is inactive on this branch (handled above), so this only
        // ever passes rows through unchanged.
        final models = _applyBudgetAndNearMeFilter(page.rows, params);

        _searchResults = reset ? models : [..._searchResults, ...models];
        _searchOffset += page.rows.length;
        _totalResultCount = page.totalCount ?? _searchOffset;
        _hasMoreResults = _searchOffset < (page.totalCount ?? _searchOffset);
      }
    } catch (e) {
      debugPrint('[PropertyProvider] runSearch failed: $e');
    } finally {
      if (reset) {
        _isSearching = false;
      }
      notifyListeners();
    }
  }

  bool _isBudgetFilterActive(SearchQueryParams params) {
    return !(params.budgetMin <= AppConstants.priceMin &&
        params.budgetMax >= AppConstants.priceMax);
  }

  Future<void> loadMoreResults(SearchQueryParams params) async {
    if (_isLoadingMore || !_hasMoreResults || params.nearMeEnabled) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      await runSearch(params, reset: false);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Always fetches the complete (safety-capped) matching set in one shot,
  /// independent of the list's incremental pagination cursor, so the map can
  /// `fitBounds` over everything the way the website's map does while the
  /// list pages incrementally.
  ///
  /// Runs the SAME budget + near-me post-filtering as runSearch's near-me
  /// branch — this previously only applied the budget filter, so enabling
  /// "Near Me" while the map was open (or refreshing the map while near-me
  /// was active) showed properties from anywhere within the safety cap
  /// instead of just the ones within 15km.
  Future<void> loadMapResults(SearchQueryParams params) async {
    try {
      final page = await _propertyService.searchProperties(
        params: params,
        offset: 0,
        limit: AppConstants.mapResultsSafetyCap,
        includeRange: false,
      );
      _mapResults = _applyBudgetAndNearMeFilter(page.rows, params);
      notifyListeners();
    } catch (e) {
      debugPrint('[PropertyProvider] loadMapResults failed: $e');
    }
  }

  /// Budget is never sent as a DB filter (see PropertyService.searchProperties
  /// for why) — this replicates the website's own client-side comparison
  /// against the parsed free-text `price` column exactly. When near-me is
  /// active, also Haversine-filters to the website's hardcoded 15km radius,
  /// sorts ascending by distance, and caps to 100 — shared by both runSearch
  /// (near-me branch) and loadMapResults so the two can never drift apart.
  List<PropertyModel> _applyBudgetAndNearMeFilter(
    List<Map<String, dynamic>> rows,
    SearchQueryParams params,
  ) {
    final bool isDefaultRange = params.budgetMin <= AppConstants.priceMin &&
        params.budgetMax >= AppConstants.priceMax;

    final filteredRows = isDefaultRange
        ? rows
        : rows.where((row) {
            final price = double.tryParse(row['price']?.toString() ?? '');
            if (price == null || price <= 0) return false;
            if (price < params.budgetMin) return false;
            if (price > params.budgetMax) return false;
            return true;
          }).toList();

    final models = filteredRows.map((r) => PropertyModel.fromSupabase(r)).toList();

    if (!params.nearMeEnabled ||
        params.nearMeLat == null ||
        params.nearMeLng == null) {
      return models;
    }

    final withDistance = <MapEntry<PropertyModel, double>>[];
    for (final model in models) {
      if (model.latitude == null || model.longitude == null) continue;
      final distanceKm = haversineKm(
        params.nearMeLat!,
        params.nearMeLng!,
        model.latitude!,
        model.longitude!,
      );
      if (distanceKm <= AppConstants.nearMeRadiusKm) {
        withDistance.add(MapEntry(model, distanceKm));
      }
    }
    withDistance.sort((a, b) => a.value.compareTo(b.value));
    return withDistance
        .take(AppConstants.nearMeResultCap)
        .map((e) => e.key)
        .toList();
  }

  /// Checks the bulk list, current search results, and current map results
  /// for an already-loaded copy of a property — lets the detail screen
  /// instant-paint before its dedicated fetch resolves.
  PropertyModel? findCached(String id) {
    for (final list in [_properties, _searchResults, _mapResults]) {
      for (final p in list) {
        if (p.id == id) return p;
      }
    }
    return null;
  }

  void toggleShortlist(String propertyId) {
    bool found = false;
    void updateList(List<PropertyModel> list) {
      final index = list.indexWhere((p) => p.id == propertyId);
      if (index != -1) {
        list[index] =
            list[index].copyWith(isShortlisted: !list[index].isShortlisted);
        found = true;
      }
    }

    updateList(_properties);
    updateList(_searchResults);
    updateList(_mapResults);
    if (found) notifyListeners();
  }

  List<PropertyModel> getShortlistedProperties() {
    return _properties.where((p) => p.isShortlisted).toList();
  }

  List<PropertyModel> getFeaturedProperties() {
    return _properties.where((p) => p.isFeatured).toList();
  }

  // Visit Management
  final List<Map<String, dynamic>> _visits = [
    {
      'propertyId': '1',
      'title': 'Luxury 3BHK Apartment',
      'location': 'Koramangala, Bangalore',
      'date': 'Tomorrow',
      'time': '10:00 AM',
      'agentName': 'Rajesh Kumar',
      'agentPhone': '+91 98765 43210',
      'status': 'Confirmed',
      'isUpcoming': true,
    },
    {
      'propertyId': '2',
      'title': 'Modern Villa',
      'location': 'Whitefield, Bangalore',
      'date': 'May 22, 2026',
      'time': '2:00 PM',
      'agentName': 'Priya Sharma',
      'agentPhone': '+91 98765 43211',
      'status': 'Pending',
      'isUpcoming': true,
    },
    {
      'propertyId': '3',
      'title': '2BHK Apartment',
      'location': 'Indiranagar, Bangalore',
      'date': 'May 15, 2026',
      'time': '11:00 AM',
      'agentName': 'Amit Patel',
      'rating': 4,
      'isUpcoming': false,
      'status': 'Completed',
    },
    {
      'propertyId': '4',
      'title': 'Studio Apartment',
      'location': 'HSR Layout, Bangalore',
      'date': 'May 10, 2026',
      'time': '3:00 PM',
      'agentName': 'Sneha Reddy',
      'rating': 5,
      'isUpcoming': false,
      'status': 'Completed',
    },
  ];

  List<Map<String, dynamic>> get visits => _visits;

  void addVisit(Map<String, dynamic> visit) {
    _visits.insert(0, visit);
    notifyListeners();
  }

  void cancelVisit(String propertyId) {
    final index = _visits.indexWhere((v) => v['propertyId'] == propertyId && v['isUpcoming'] == true && v['status'] != 'Cancelled');
    if (index != -1) {
      _visits[index] = {
        ..._visits[index],
        'status': 'Cancelled',
      };
      notifyListeners();
    }
  }

  int _enquiriesCount = 3;
  int get enquiriesCount => _enquiriesCount;

  void incrementEnquiries() {
    _enquiriesCount++;
    notifyListeners();
  }
}
