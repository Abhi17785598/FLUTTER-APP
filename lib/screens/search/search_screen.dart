import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/property_provider.dart';
import '../../providers/filter_provider.dart';
import '../../models/property_model.dart';
import '../../models/global_search_suggestion.dart';
import '../../models/smart_query_result.dart';
import '../../services/property_service.dart';
import '../../services/ai_search_service.dart';
import '../../services/voice_search_service.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/section_header.dart';
import '../../widgets/property_card_horizontal.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/verified_badge.dart';
import '../../widgets/status_tag.dart';

class SearchScreen extends StatefulWidget {
  // Set when navigated here from a mic icon elsewhere in the app (e.g. the
  // Home screen's search-bar preview) so voice listening starts immediately
  // instead of requiring a second tap once this screen loads.
  final bool autoStartVoice;

  const SearchScreen({super.key, this.autoStartVoice = false});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final PropertyService _propertyService = PropertyService();
  final AiSearchService _aiSearchService = AiSearchService();
  final VoiceSearchService _voiceSearchService = VoiceSearchService();

  Timer? _debounce;
  List<GlobalSearchSuggestion> _suggestions = [];
  bool _isLoadingSuggestions = false;
  // Once the user submits (keyboard search action or tapping a suggestion),
  // this screen switches from showing the debounced-suggestions dropdown to
  // showing real query results, matching the website's own split between
  // autocomplete (debounced, typing) and the actual search (only on submit).
  bool _hasSubmittedSearch = false;

  // Smart Search — when on, a submitted query is first parsed by AI
  // (AiSearchService) into structured filters before running the search.
  bool _smartSearchEnabled = false;
  bool _isParsingSmartQuery = false;

  // Voice Search — on-device speech-to-text feeding the same search box.
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    // If we're about to auto-start voice listening, don't also pop the
    // keyboard up — the user tapped a mic icon to speak, not to type.
    if (!widget.autoStartVoice) {
      _searchFocusNode.requestFocus();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<NavigationProvider>(context, listen: false).setIndex(1);
      if (widget.autoStartVoice) {
        _toggleVoiceSearch();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    if (_isListening) {
      _voiceSearchService.cancelListening();
    }
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _hasSubmittedSearch = false);
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _fetchSuggestions(value),
    );
  }

  Future<void> _fetchSuggestions(String term) async {
    setState(() => _isLoadingSuggestions = true);
    try {
      final results = await _propertyService.globalSearch(term);
      if (!mounted) return;
      setState(() {
        // project/builder suggestion types point at routes that don't exist
        // in this app yet — dropped rather than left to dead-end.
        _suggestions =
            results.where((s) => s.type == 'city' || s.type == 'property').toList();
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      debugPrint('[SearchScreen] suggestions failed: $e');
      if (!mounted) return;
      setState(() => _isLoadingSuggestions = false);
    }
  }

  /// Submits the current query. When Smart Search is on, the text is first
  /// parsed by AI (AiSearchService, calling the website's existing
  /// openai-proxy edge function) into structured filters — city/bhk/
  /// category/listingType/budget — which are applied through the SAME
  /// FilterProvider/PropertyProvider pipeline as a manual filter selection,
  /// so Smart Search can never bypass or duplicate the search logic itself.
  Future<void> _submitSearch(String value) async {
    final trimmed = value.trim();
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    final propertyProvider = Provider.of<PropertyProvider>(context, listen: false);

    if (_smartSearchEnabled && trimmed.isNotEmpty) {
      setState(() => _isParsingSmartQuery = true);
      final result = await _aiSearchService.parseQuery(trimmed);
      if (!mounted) return;
      setState(() => _isParsingSmartQuery = false);
      _applySmartQueryResult(result);
    } else {
      filterProvider.setSearchText(trimmed);
    }

    if (!mounted) return;
    setState(() {
      _hasSubmittedSearch = true;
      _suggestions = [];
    });
    _searchFocusNode.unfocus();
    propertyProvider.runSearch(filterProvider.toQueryParams(), reset: true);
  }

  void _applySmartQueryResult(SmartQueryResult result) {
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    filterProvider.setSearchText(result.keywords);
    filterProvider.setCategory(result.category);
    filterProvider.setListingType(result.listingType);
    filterProvider.setBhk(result.bhk);
    if (result.city != null && result.city!.isNotEmpty) {
      filterProvider.setCities([result.city!]);
    }
    if (result.budgetMin != null || result.budgetMax != null) {
      filterProvider.setBudgetRange(RangeValues(
        result.budgetMin ?? AppConstants.priceMin,
        result.budgetMax ?? AppConstants.priceMax,
      ));
    }
  }

  void _toggleSmartSearch() {
    setState(() => _smartSearchEnabled = !_smartSearchEnabled);
  }

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      await _voiceSearchService.stopListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    final started = await _voiceSearchService.startListening(
      onResult: (text, isFinal) {
        if (!mounted) return;
        _searchController.text = text;
        _searchController.selection =
            TextSelection.collapsed(offset: text.length);
        _onQueryChanged(text);
        setState(() {});
        if (isFinal) {
          setState(() => _isListening = false);
          if (text.trim().isNotEmpty) {
            _submitSearch(text);
          }
        }
      },
    );

    if (!mounted) return;
    if (started) {
      setState(() => _isListening = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice search is not available on this device.'),
        ),
      );
    }
  }

  void _onSuggestionTap(GlobalSearchSuggestion suggestion) {
    if (suggestion.type == 'property') {
      Navigator.pushNamed(
        context,
        AppConstants.propertyDetailScreen,
        arguments: {'propertyId': suggestion.id},
      );
      return;
    }

    // city suggestion
    _searchController.text = suggestion.label;
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    final propertyProvider = Provider.of<PropertyProvider>(context, listen: false);
    filterProvider.setSearchText('');
    filterProvider.setCities([suggestion.label]);
    setState(() {
      _hasSubmittedSearch = true;
      _suggestions = [];
    });
    _searchFocusNode.unfocus();
    propertyProvider.runSearch(filterProvider.toQueryParams(), reset: true);
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    Provider.of<FilterProvider>(context, listen: false).setSearchText('');
    setState(() {
      _suggestions = [];
      _hasSubmittedSearch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isQueryNotEmpty = _searchController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SearchBarWidget(
                        hint: _isListening
                            ? 'Listening…'
                            : 'Search properties, locations...',
                        onTap: null,
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: (val) {
                          _onQueryChanged(val);
                          setState(() {});
                        },
                        onSubmitted: _submitSearch,
                        onClear: _clearSearch,
                        trailing: _buildMicButton(),
                      ),
                    ),
                    if (_isParsingSmartQuery) ...[
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ] else if (_smartSearchEnabled) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                size: 14, color: AppColors.primary),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Smart Search on — try "2 bhk under 50 lakhs in Noida"',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (!isQueryNotEmpty) ...[
                      _buildFilterChips(context),
                      const SizedBox(height: 24),
                      SectionHeader(
                        title: 'Recommended For You',
                        actionLabel: 'See all ›',
                        onActionTap: () {
                          Navigator.pushNamed(context, AppConstants.searchResultsScreen);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildRecommendedProperties(),
                      const SizedBox(height: 24),
                      SectionHeader(
                        title: 'Recent Searches',
                        actionLabel: 'Clear all',
                        onActionTap: () {},
                      ),
                      _buildRecentSearches(),
                    ] else if (!_hasSubmittedSearch) ...[
                      _buildSuggestions(),
                    ] else ...[
                      _buildSubmittedResults(),
                    ],
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(
        currentIndex: 1,
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                } else {
                  Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Search',
            style: AppTextStyles.heading2,
          ),
          const Spacer(),
          GestureDetector(
            onTap: _toggleSmartSearch,
            child: Container(
              width: 40,
              height: 40,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _smartSearchEnabled ? AppColors.primary : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                color: _smartSearchEnabled ? Colors.white : AppColors.textSecondary,
                size: 20,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppConstants.searchResultsScreen),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.map_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _toggleVoiceSearch,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: _isListening ? Colors.red.withOpacity(0.1) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          _isListening ? Icons.mic : Icons.mic_none,
          size: 20,
          color: _isListening ? Colors.red : AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Opens the shared FiltersScreen (same instance/state/Apply-button logic
  /// used from the Results screen) and, only if the user actually pressed
  /// Apply (FiltersScreen now pops with `true`, not just on Back), forwards
  /// to SearchResultsScreen so the updated FilterProvider/PropertyProvider
  /// state — already correct, single source of truth — is actually visible.
  /// Without this, applying a filter from here silently updated
  /// PropertyProvider.searchResults while this screen kept showing the
  /// unrelated unfiltered "Recommended For You" list, making it look like
  /// the filter did nothing.
  void _openFiltersFromChip(BuildContext context) {
    Navigator.pushNamed(context, AppConstants.filtersScreen).then((applied) {
      if (applied == true && mounted) {
        Navigator.pushNamed(context, AppConstants.searchResultsScreen);
      }
    });
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

  Widget _buildFilterChips(BuildContext context) {
    return Consumer<FilterProvider>(
      builder: (context, filterProvider, child) {
        final listingTypeLabel = switch (filterProvider.listingType) {
          'sell' => 'Buy',
          'rent' => 'Rent',
          'lease' => 'Lease',
          _ => 'Buy ▾',
        };
        final categoryLabel = filterProvider.category != null
            ? _categoryDisplayName(filterProvider.category!)
            : 'Property Type ▾';
        final isDefaultBudget =
            filterProvider.budgetRange.start <= AppConstants.priceMin &&
                filterProvider.budgetRange.end >= AppConstants.priceMax;
        final priceLabel = isDefaultBudget ? 'Price ▾' : 'Price';
        final filtersLabel = filterProvider.activeFilterCount > 0
            ? 'Filters (${filterProvider.activeFilterCount})'
            : 'Filters';

        final chips = [listingTypeLabel, categoryLabel, priceLabel, filtersLabel];
        return SizedBox(
      height: AppConstants.filterChipHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isFiltersChip = chip == filtersLabel;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => _openFiltersFromChip(context),
              child: Container(
                height: AppConstants.filterChipHeight,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isFiltersChip
                      ? AppColors.primaryLight
                      : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isFiltersChip
                        ? AppColors.primary
                        : AppColors.textHint.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    chip,
                    style: AppTextStyles.chip.copyWith(
                      color: isFiltersChip
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: isFiltersChip ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
      },
    );
  }

  Widget _buildRecommendedProperties() {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        final properties = propertyProvider.properties.take(4).toList();
        return SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: properties.length,
            itemBuilder: (context, index) {
              return PropertyCardHorizontal(
                property: properties[index],
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppConstants.propertyDetailScreen,
                    arguments: {'propertyId': properties[index].id},
                  );
                },
                onFavoriteToggle: () {
                  propertyProvider.toggleShortlist(properties[index].id);
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    final recentSearches = [
      {'location': 'Gachibowli, Hyderabad', 'details': 'Buy • 3 BHK • ₹1 Cr – ₹2 Cr'},
      {'location': 'Jubilee Hills, Hyderabad', 'details': 'Buy • 4 BHK • ₹3 Cr – ₹5 Cr'},
      {'location': 'Madhapur, Hyderabad', 'details': 'Rent • 2 BHK • ₹25K – ₹35K'},
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: recentSearches.length,
      itemBuilder: (context, index) {
        final search = recentSearches[index];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.access_time,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          search['location'] as String,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          search['details'] as String,
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {},
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
            const Divider(height: 0.5),
          ],
        );
      },
    );
  }

  Widget _buildSuggestions() {
    if (_isLoadingSuggestions) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text(
          _searchController.text.trim().length < 3
              ? 'Keep typing to see suggestions…'
              : 'Press search to look for "${_searchController.text}".',
          style: AppTextStyles.caption,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Suggestions',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _suggestions.length,
          itemBuilder: (context, index) {
            final suggestion = _suggestions[index];
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                suggestion.type == 'city' ? Icons.location_city : Icons.home_work_outlined,
                color: AppColors.primary,
              ),
              title: Text(suggestion.label),
              subtitle:
                  suggestion.description != null ? Text(suggestion.description!) : null,
              onTap: () => _onSuggestionTap(suggestion),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubmittedResults() {
    return Consumer<PropertyProvider>(
      builder: (context, propertyProvider, child) {
        if (propertyProvider.isSearching && propertyProvider.searchResults.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final results = propertyProvider.searchResults;
        if (results.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Search Results (${propertyProvider.totalResultCount} found)',
                style: AppTextStyles.heading2.copyWith(fontSize: 18),
              ),
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: results.length,
              itemBuilder: (context, index) {
                return _buildPropertyListItem(context, results[index], propertyProvider);
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off_rounded,
              color: AppColors.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No properties found',
            style: AppTextStyles.heading2.copyWith(fontSize: 20),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'We couldn\'t find any properties matching "${_searchController.text}". Check your spelling or try different keywords.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _clearSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildPropertyListItem(BuildContext context, PropertyModel property, PropertyProvider propertyProvider) {
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
                        property.isShortlisted ? Icons.favorite : Icons.favorite_border,
                        color: property.isShortlisted ? Colors.red : AppColors.textSecondary,
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
                        _buildSpecIconListItem(Icons.bed, '${property.beds}'),
                        const SizedBox(width: 12),
                        _buildSpecIconListItem(Icons.bathtub, '${property.baths}'),
                        const SizedBox(width: 12),
                        _buildSpecIconListItem(Icons.square_foot, '${property.sqft}'),
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

  Widget _buildSpecIconListItem(IconData icon, String value) {
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
}
