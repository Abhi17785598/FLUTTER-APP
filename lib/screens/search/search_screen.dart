import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/filter_provider.dart';
import '../../providers/recent_searches_provider.dart';
import '../../models/global_search_suggestion.dart';
import '../../models/smart_query_result.dart';
import '../../models/user_profile.dart';
import '../../services/property_service.dart';
import '../../services/ai_search_service.dart';
import '../../services/people_search_service.dart';
import '../../services/voice_search_service.dart';
import '../../voice_agent/services/intent_stash.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../profile/public_profile_role.dart';
import 'widgets/ai_confirmation_strip.dart';
import 'widgets/ai_understanding_indicator.dart';
import 'widgets/people_result_card.dart';

// ── Prototype dimensions without an existing token ───────────────────────────
// Phase 1 deliberately does NOT add to AppConstants; these live here until a
// second consumer needs them.

/// The Search Entry bar's corner radius. Its height (54) is already
/// `AppConstants.searchBarHeight`; 18 has no token.
const double _kEntryBarRadius = 18;

/// Gap between the bar's search icon, field and mic badge.
const double _kEntryBarGap = 10;

/// A recent-search row: 46 dp tall, 14 dp side padding, 10 dp icon gap.
const double _kRecentRowHeight = 46;
const double _kRecentRowPadding = 14;

/// How many people the dropdown previews.
///
/// `SearchModal.tsx:118` caps its People section at 5. The full, paginated list
/// lives behind the "See all people" row.
const int _kPeopleSuggestionLimit = 5;

/// One suggestion group in the autocomplete list.
///
/// `global_search` emits exactly four types — city, property, project and
/// builder. Only the two listed below are groupable here: this app has no
/// project-detail screen, so `project` still has nowhere to go, and
/// `_fetchSuggestions` drops it so a tap can never dead-end. Note the portal's
/// own TypeScript declares a `locality` type as well, but the deployed RPC never
/// returns one.
///
/// PEOPLE ARE NOT ONE OF THESE GROUPS, DELIBERATELY
/// ------------------------------------------------
/// The RPC's `builder` rows are still discarded. There is now a public profile
/// screen to open them on, but the RPC is the wrong source: its profiles branch
/// is `SECURITY DEFINER` with no `approval_status` or `is_blocked` predicate
/// (20260402111500_restore_coordinates.sql:141-156), so it returns pending,
/// rejected and blocked profiles; it covers only `builder | dealer | broker`;
/// and its `LIMIT 20` is shared with cities, properties and projects, so people
/// get crowded out. People come from `PeopleSearchService` instead, which applies
/// the `profiles_public` row filter — exactly how `SearchModal.tsx:112-119` runs
/// a dedicated profiles query for its own People section rather than reusing the
/// property one.
class _SuggestionGroup {
  final String type;
  final String label;
  final IconData icon;

  const _SuggestionGroup({
    required this.type,
    required this.label,
    required this.icon,
  });
}

/// Fixed order, mirroring the website's own city-before-property grouping.
const List<_SuggestionGroup> _kSuggestionGroups = [
  _SuggestionGroup(
    type: 'city',
    label: 'CITIES',
    icon: Icons.location_city,
  ),
  _SuggestionGroup(
    type: 'property',
    label: 'PROPERTIES',
    icon: Icons.home_work_outlined,
  ),
];

/// The gradient mic badge: 38 dp square at a 13 dp radius.
const double _kMicBadgeSize = 38;
const double _kMicBadgeRadius = 13;

/// Circular app-bar buttons. 36 dp is the size the redesign uses for the
/// back/action circles on its other screens (Messages, Manage Dashboard).
const double _kAppBarButtonSize = 36;

/// A "Search by property type" pill.
///
/// Apartment and Villa are both `category: residential` and are distinguished
/// only by subtype, so a pill has to carry the pair — `category` alone cannot
/// represent them. The subtype match terms are the same ones
/// [FiltersScreen] already uses, verified against the live
/// `residential_subtype` column rather than guessed from a label.
class _PropertyTypeOption {
  final String label;
  final String category;
  final String? subtype;

  const _PropertyTypeOption({
    required this.label,
    required this.category,
    this.subtype,
  });
}

const List<_PropertyTypeOption> _kPropertyTypes = [
  _PropertyTypeOption(
      label: 'Apartment', category: 'residential', subtype: 'Flat'),
  _PropertyTypeOption(
      label: 'Villa', category: 'residential', subtype: 'Villa'),
  _PropertyTypeOption(label: 'Plot', category: 'land'),
  _PropertyTypeOption(label: 'Commercial', category: 'commercial'),
];

class SearchScreen extends StatefulWidget {
  // Set when navigated here from a mic icon elsewhere in the app (e.g. the
  // Home screen's search-bar preview) so voice listening starts immediately
  // instead of requiring a second tap once this screen loads.
  final bool autoStartVoice;

  /// Injected by tests so the People group can be exercised without a database.
  /// Production always builds a real service.
  @visibleForTesting
  final PeopleSearchService? peopleSearchServiceOverride;

  const SearchScreen({
    super.key,
    this.autoStartVoice = false,
    this.peopleSearchServiceOverride,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with WidgetsBindingObserver {
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final PropertyService _propertyService = PropertyService();
  late final PeopleSearchService _peopleSearchService =
      widget.peopleSearchServiceOverride ?? PeopleSearchService();
  final AiSearchService _aiSearchService = AiSearchService();
  final VoiceSearchService _voiceSearchService = VoiceSearchService();

  Timer? _debounce;
  List<GlobalSearchSuggestion> _suggestions = [];

  /// The People preview in the dropdown. Fetched alongside the property/city
  /// suggestions, from its own service.
  List<UserProfile> _peopleSuggestions = [];

  bool _isLoadingSuggestions = false;

  // AI parsing of a submitted query. Runs for EVERY free-text search — there is
  // no longer an opt-in "Smart Search" toggle, matching both the website (which
  // always parses) and the redesign (which advertises AI search with no toggle).
  bool _isParsingSmartQuery = false;

  // Voice Search — on-device speech-to-text feeding the same search box.
  bool _isListening = false;

  /// True from a final transcript until the search it triggered has been
  /// dispatched, so the mic badge can show progress rather than snapping to idle
  /// while the AI parse is still running.
  bool _isProcessingVoice = false;

  /// Set when a dictation is abandoned — by the user tapping the mic off, or by
  /// the app being backgrounded. Guards against a queued result arriving after
  /// the fact and submitting a search the user walked away from.
  bool _voiceCancelled = false;

  @override
  void initState() {
    super.initState();
    // Observed so an in-flight dictation can be cancelled if the app is
    // backgrounded — see didChangeAppLifecycleState.
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    if (_isListening) {
      _voiceCancelled = true;
      _voiceSearchService.cancelListening();
    }
    super.dispose();
  }

  /// Empties both suggestion lists. Call inside `setState`.
  ///
  /// Every site that used to clear `_suggestions` alone now goes through here, so
  /// a stale People group cannot outlive the property suggestions it was fetched
  /// with.
  void _clearSuggestions() {
    _suggestions = [];
    _peopleSuggestions = [];
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 3) {
      setState(_clearSuggestions);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _fetchSuggestions(value),
    );
  }

  Future<void> _fetchSuggestions(String term) async {
    setState(() => _isLoadingSuggestions = true);

    // Concurrent and independently guarded, the way `SearchModal.tsx:78-125`
    // runs its property, project and people queries in one `Promise.all` with
    // per-promise error handling: a people failure must not blank the property
    // suggestions, and vice versa. Both handlers are attached before either
    // await, so neither rejection can go unobserved.
    final Future<List<GlobalSearchSuggestion>> placesFuture =
        _propertyService.globalSearch(term).catchError((Object e) {
      debugPrint('[SearchScreen] suggestions failed: $e');
      return const <GlobalSearchSuggestion>[];
    });

    final Future<List<UserProfile>> peopleFuture = _peopleSearchService
        .searchPeople(query: term, limit: _kPeopleSuggestionLimit)
        .then<List<UserProfile>>((page) => page.rows)
        .catchError((Object e) {
      debugPrint('[SearchScreen] people suggestions failed: $e');
      return const <UserProfile>[];
    });

    final places = await placesFuture;
    final people = await peopleFuture;

    if (!mounted) return;
    setState(() {
      // The project type points at a screen this app doesn't have, and the
      // builder type comes from an RPC that bypasses RLS — both dropped rather
      // than left to dead-end or to leak. See _kSuggestionGroups.
      _suggestions = places
          .where((s) => s.type == 'city' || s.type == 'property')
          .toList();
      _peopleSuggestions = people;
      _isLoadingSuggestions = false;
    });
  }

  /// Submits the current query. The text is first parsed by AI
  /// (AiSearchService, calling the website's existing openai-proxy edge
  /// function) into structured filters — city/bhk/category/listingType/budget —
  /// which are applied through the SAME FilterProvider pipeline as a manual
  /// filter selection, so AI search can never bypass or duplicate the search
  /// logic itself.
  ///
  /// Note this deliberately does NOT call `PropertyProvider.runSearch`:
  /// SearchResultsScreen already runs the search from its own `initState`, so
  /// calling it here as well would fire two identical queries per submit.
  Future<void> _submitSearch(String value) async {
    final trimmed = value.trim();
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    final recentSearches =
        Provider.of<RecentSearchesProvider>(context, listen: false);

    if (trimmed.isNotEmpty) {
      // Recorded BEFORE the AI parse, and as the RAW text the user typed — the
      // website saves at the same point, and storing the post-parse keywords
      // instead would show "villa" for a query submitted as
      // "3BHK villa under 1 crore in Dehradun". Not awaited: persistence is
      // best-effort and must never delay the search.
      recentSearches.add(trimmed);
      setState(() => _isParsingSmartQuery = true);
      final result = await _aiSearchService.parseQuery(trimmed);
      if (!mounted) return;
      setState(() => _isParsingSmartQuery = false);
      _applySmartQueryResult(result);
      // Hand the parse to the Results screen so it can show what was understood.
      // Only when something structured actually came back — a plain-text
      // fallback has nothing to confirm, and claiming otherwise would be noise.
      if (result.hasStructuredFilters) {
        IntentStash.set(kAiUnderstandingKey, result);
      } else {
        IntentStash.remove(kAiUnderstandingKey);
      }
    } else {
      filterProvider.setSearchText(trimmed);
    }

    if (!mounted) return;
    setState(_clearSuggestions);
    _searchFocusNode.unfocus();
    Navigator.pushNamed(context, AppConstants.searchResultsScreen);
  }

  void _applySmartQueryResult(SmartQueryResult result) {
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    filterProvider.setSearchText(result.keywords);
    // Null-guarded, matching how `city` and the budget range below were already
    // handled. Without these guards an AI parse that simply didn't mention a
    // facet would CLEAR one the user had just chosen: picking the "Villa" pill
    // and then submitting free text returned `category: null`, which wiped the
    // category while leaving the subtype set — querying a residential subtype
    // with no category filter behind it.
    if (result.category != null) filterProvider.setCategory(result.category);
    if (result.listingType != null) {
      filterProvider.setListingType(result.listingType);
    }
    if (result.bhk != null) filterProvider.setBhk(result.bhk);
    // Guarded like the rest. AiSearchService has already refused to return a
    // subtype the query did not literally name, so a value arriving here is
    // something the user actually said and should win over an earlier pill
    // choice; a null means the query was silent on style and must leave whatever
    // is set alone.
    if (result.subtype != null) filterProvider.setSubtype(result.subtype);
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

  Future<void> _toggleVoiceSearch() async {
    if (_isListening) {
      // cancel(), NOT stop(). `stop()` finalises the utterance, and the platform
      // recogniser can still deliver a final result for it — which would submit
      // whatever half-sentence had been captured. Tapping the mic off has to
      // abandon the attempt, not commit it.
      _voiceCancelled = true;
      await _voiceSearchService.cancelListening();
      if (mounted) setState(() => _isListening = false);
      return;
    }

    _voiceCancelled = false;
    // Timed out because `startListening` awaits a platform response that never
    // arrives on a device without a speech implementation — desktop and web have
    // none. Without this the await simply hangs: no listening state, no error,
    // no feedback, and a mic button that silently does nothing. A timeout turns
    // that into the same "unavailable" message a refusal produces.
    final bool started = await _voiceSearchService
        .startListening(
      onResult: (text, isFinal) {
        // A cancelled session can still flush a queued callback, so an abandoned
        // utterance is checked for here as well as at the cancel site.
        if (!mounted || _voiceCancelled) return;
        _searchController.text = text;
        _searchController.selection =
            TextSelection.collapsed(offset: text.length);
        _onQueryChanged(text);
        setState(() {});
        if (isFinal) {
          final bool hasText = text.trim().isNotEmpty;
          setState(() {
            _isListening = false;
            // The badge stays busy across the AI parse that follows, so the
            // control the user just used is the thing that reports progress.
            _isProcessingVoice = hasText;
          });
          if (hasText) {
            _submitSearch(text).whenComplete(() {
              if (mounted) setState(() => _isProcessingVoice = false);
            });
          }
        }
      },
    )
        .timeout(
          // Long enough not to race a first-run OS permission dialog — timing
          // out while the user is still deciding would report "unavailable" and
          // then start listening anyway. Short enough that a platform which will
          // never answer eventually says so instead of hanging forever.
          const Duration(seconds: 10),
          onTimeout: () => false,
        );

    if (!mounted) return;
    if (started) {
      // Confirms capture has begun, which matters most here: the user is about
      // to speak and cannot be watching the badge while they do.
      HapticFeedback.mediumImpact();
      setState(() => _isListening = true);
    } else {
      // A session that reported failure — or never reported at all — must not be
      // left running unattended, or a later result could submit a search the
      // user was told had not started.
      _voiceCancelled = true;
      _voiceSearchService.cancelListening();
      // `startListening` returns false for an unsupported device AND for a
      // denied microphone permission — VoiceSearchService does not distinguish
      // them — so the message has to cover both without guessing which happened.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Voice search needs microphone access, and is not available on '
            'every device.',
          ),
        ),
      );
    }
  }

  /// Cancels an in-flight dictation when the app leaves the foreground.
  ///
  /// Backgrounding tears down the platform recogniser without notifying the
  /// callback, so without this the badge would sit pulsing "listening" forever
  /// after the user came back. Cancel rather than stop, for the same reason the
  /// manual toggle does: a partial utterance must not be submitted on the way out.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed || !_isListening) return;
    _voiceCancelled = true;
    _voiceSearchService.cancelListening();
    if (mounted) setState(() => _isListening = false);
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
    // Picking a city IS a committed search, so it joins the recent list under
    // the city's own name — matching the website, which calls
    // saveRecentSearch(suggestion.label) on this same branch.
    Provider.of<RecentSearchesProvider>(context, listen: false)
        .add(suggestion.label);
    filterProvider.setSearchText('');
    filterProvider.setCities([suggestion.label]);
    setState(_clearSuggestions);
    _searchFocusNode.unfocus();
    Navigator.pushNamed(context, AppConstants.searchResultsScreen);
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    Provider.of<FilterProvider>(context, listen: false).setSearchText('');
    setState(_clearSuggestions);
  }

  /// Selecting a pill sets category + subtype together; tapping the selected
  /// pill again clears both, mirroring the redesign's own toggle behaviour.
  void _onPropertyTypeTap(_PropertyTypeOption option, bool isSelected) {
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);

    if (isSelected) {
      // Deselecting clears the facet and stays put. Tapping the active pill off
      // is the user narrowing their choice on this screen, not committing to a
      // search — navigating away would make the selection impossible to undo
      // without coming back and tapping it again.
      filterProvider.setCategory(null);
      filterProvider.setSubtype(null);
      return;
    }

    // `FilterProvider.searchText` outlives this screen, so a query from an
    // earlier search is still sitting in it. Selecting a property type with an
    // empty field means "show me this type", not "show me this type matching
    // whatever I typed ten minutes ago" — so the stale term goes before the
    // facet is applied.
    //
    // Guarded rather than unconditional even though the pill row only renders
    // while the field is empty (see the `isQueryNotEmpty` branch in build), so
    // that the rule still holds — and a half-typed query is still respected —
    // if the pills ever become visible during typing.
    if (_searchController.text.trim().isEmpty) {
      filterProvider.setSearchText('');
    }

    filterProvider.setCategory(option.category);
    filterProvider.setSubtype(option.subtype);
    // Selecting IS a committed search, so it ends the same way every other
    // committed search on this screen does — by pushing the results route.
    // SearchResultsScreen.initState stays the single place runSearch is called
    // from; this deliberately does not run the query itself.
    Navigator.pushNamed(context, AppConstants.searchResultsScreen);
  }

  @override
  Widget build(BuildContext context) {
    final bool isQueryNotEmpty = _searchController.text.isNotEmpty;

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
                    const SizedBox(height: AppConstants.spacingL),
                    _buildHeading(),
                    const SizedBox(height: 18),
                    _buildSearchBar(),
                    if (_isParsingSmartQuery) ...[
                      const SizedBox(height: AppConstants.spacingS),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppConstants.spacingXL),
                        child: AiUnderstandingIndicator(),
                      ),
                    ],
                    if (isQueryNotEmpty)
                      _buildSuggestions()
                    else ...[
                      const SizedBox(height: 22),
                      _buildPropertyTypeSection(),
                      const SizedBox(height: 26),
                      _buildRecentSearches(),
                    ],
                    const SizedBox(height: 100),
                  ],
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      duration: 400.ms,
                      curve: Curves.easeOut,
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

  /// Restyled to the redesign's header language — a 36 dp white circular back
  /// button, a 17/700 title, and 36 dp circular trailing actions with the
  /// primary one filled — while keeping every action and every navigation
  /// behaviour this screen already had. The former "Smart Search" toggle is
  /// gone because AI parsing is now unconditional (see [_submitSearch]); there
  /// is no longer anything for it to toggle.
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spacingXL,
        vertical: 14,
      ),
      child: Row(
        children: [
          _buildAppBarCircleButton(
            icon: Icons.arrow_back,
            iconColor: AppColors.textPrimary,
            background: AppColors.cardBackground,
            withShadow: true,
            semanticLabel: 'Back',
            onTap: () {
              if (Navigator.of(context).canPop()) {
                Navigator.pop(context);
              } else {
                Provider.of<NavigationProvider>(context, listen: false)
                    .setIndex(0);
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
          const SizedBox(width: AppConstants.spacingM),
          Expanded(
            child: Text(
              'Search',
              style: AppTextStyles.heading2.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _buildAppBarCircleButton(
            icon: Icons.map_outlined,
            iconColor: Colors.white,
            background: AppColors.primary,
            withShadow: false,
            semanticLabel: 'View results on map',
            onTap: () => Navigator.pushNamed(
              context,
              AppConstants.searchResultsScreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBarCircleButton({
    required IconData icon,
    required Color iconColor,
    required Color background,
    required bool withShadow,
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
          width: _kAppBarButtonSize,
          height: _kAppBarButtonSize,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppConstants.pillRadius),
            boxShadow: withShadow ? AppColors.surfaceCardShadow : null,
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildHeading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Search Properties',
            style: AppTextStyles.heading2.copyWith(
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Find your perfect home with AI-powered search',
            style: AppTextStyles.caption.copyWith(fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXL),
      child: SearchBarWidget(
        hint: _isListening
            ? 'Listening…'
            : 'Try "3BHK villa under 1 crore in Dehradun"',
        onTap: null,
        controller: _searchController,
        focusNode: _searchFocusNode,
        height: AppConstants.searchBarHeight,
        borderRadius: _kEntryBarRadius,
        boxShadow: AppColors.surfaceCardShadow,
        // Redesign spec for this bar: `padding: 0 8px 0 16px` with a 10 px gap
        // between the icon, the field and the mic badge.
        leadingPadding: AppConstants.spacingL,
        trailingPadding: AppConstants.spacingS,
        iconGap: _kEntryBarGap,
        trailingGap: _kEntryBarGap,
        onChanged: (val) {
          _onQueryChanged(val);
          setState(() {});
        },
        onSubmitted: _submitSearch,
        onClear: _clearSearch,
        trailing: _buildMicBadge(),
      ),
    );
  }

  /// The redesign's gradient mic badge, in its three states.
  ///
  /// idle — hollow mic glyph.
  /// listening — filled glyph, plus a slow scale pulse and the field's
  ///   "Listening…" hint, so it is obvious the app is still capturing.
  /// processing — a spinner in the same badge shape, held until the search the
  ///   dictation produced has been dispatched.
  ///
  /// The redesign only draws the idle badge; the other two reuse its exact shape,
  /// gradient and glow so the control never appears to change identity.
  Widget _buildMicBadge() {
    final Widget badge = Container(
      width: _kMicBadgeSize,
      height: _kMicBadgeSize,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(_kMicBadgeRadius),
        boxShadow: AppColors.primaryGlow,
      ),
      child: _isProcessingVoice
          ? const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          : Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
              size: 19,
            ),
    );

    return Semantics(
      label: _isProcessingVoice
          ? 'Processing voice search'
          : _isListening
              ? 'Stop voice search'
              : 'Start voice search',
      button: true,
      child: GestureDetector(
        // Inert while processing: the dictation is already committed, and a tap
        // here would start a second session on top of the search in flight.
        onTap: _isProcessingVoice ? null : _toggleVoiceSearch,
        behavior: HitTestBehavior.opaque,
        child: _isListening
            ? badge
                .animate(
                    onPlay: (controller) => controller.repeat(reverse: true))
                .scaleXY(
                  begin: 1,
                  end: 1.08,
                  duration: 800.ms,
                  curve: Curves.easeInOut,
                )
            : badge,
      ),
    );
  }

  Widget _buildPropertyTypeSection() {
    return Consumer<FilterProvider>(
      builder: (context, filterProvider, child) {
        return Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppConstants.spacingXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Search by property type',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: AppConstants.spacingS,
                runSpacing: AppConstants.spacingS,
                children: [
                  for (final option in _kPropertyTypes)
                    _buildPropertyTypePill(
                      option,
                      filterProvider.category == option.category &&
                          filterProvider.subtype == option.subtype,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropertyTypePill(_PropertyTypeOption option, bool isSelected) {
    return Semantics(
      label: option.label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => _onPropertyTypeTap(option, isSelected),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: AppConstants.filterChipHeight,
          padding:
              const EdgeInsets.symmetric(horizontal: AppConstants.spacingL),
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(AppConstants.pillRadius),
          ),
          child: Center(
            child: Text(
              option.label,
              style: AppTextStyles.chip.copyWith(
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Real, persisted recent searches. Tapping a row re-runs that search (which
  /// also lifts it back to the top of the list); the trailing button removes
  /// just that entry.
  Widget _buildRecentSearches() {
    return Consumer<RecentSearchesProvider>(
      builder: (context, recentSearches, child) {
        final queries = recentSearches.queries;

        return Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppConstants.spacingXL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('RECENT SEARCHES'),
              const SizedBox(height: 10),
              // Animates the collapse when a row is removed, so the rows below
              // slide up instead of jumping.
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: queries.isEmpty
                    ? Text(
                        'Your recent searches will appear here.',
                        style: AppTextStyles.caption.copyWith(fontSize: 12.5),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final query in queries)
                            _buildRecentSearchRow(query, recentSearches),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentSearchRow(
    String query,
    RecentSearchesProvider recentSearches,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingS),
      child: Semantics(
        label: query,
        button: true,
        child: GestureDetector(
          onTap: () => _onRecentSearchTap(query),
          behavior: HitTestBehavior.opaque,
          child: Container(
            height: _kRecentRowHeight,
            padding: const EdgeInsets.only(
              left: _kRecentRowPadding,
              right: AppConstants.spacingXS,
            ),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(AppConstants.buttonRadius),
              boxShadow: AppColors.surfaceCardShadow,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: _kEntryBarGap),
                Expanded(
                  child: Text(
                    query,
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Semantics(
                  label: 'Remove $query from recent searches',
                  button: true,
                  child: GestureDetector(
                    // Opaque so the row's own tap handler cannot swallow this.
                    behavior: HitTestBehavior.opaque,
                    onTap: () => recentSearches.remove(query),
                    child: const SizedBox(
                      width: 34,
                      height: _kRecentRowHeight,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Re-runs a stored search through the normal commit path, so it picks up AI
  /// parsing and the recent-list refresh exactly as a freshly typed query does.
  void _onRecentSearchTap(String query) {
    _searchController.text = query;
    _searchController.selection =
        TextSelection.collapsed(offset: query.length);
    _submitSearch(query);
  }

  /// The uppercase micro-label used for both the recent-searches and
  /// suggestion-group headings.
  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: AppColors.textHint,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _buildSuggestions() {
    if (_isLoadingSuggestions) {
      // Lightweight by design: autocomplete is a fast surface, and a full
      // skeleton or a large spinner would imply a heavier wait than this is.
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingXL,
          vertical: AppConstants.spacingL,
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: AppConstants.spacingS),
            Text(
              'Searching…',
              style: AppTextStyles.caption.copyWith(fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty && _peopleSuggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingXL,
          vertical: AppConstants.spacingXXL,
        ),
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
        for (final group in _kSuggestionGroups) ..._buildSuggestionGroup(group),
        // Last, under the property groups: this is a property-first app, and the
        // portal's own modal also renders its People section beneath properties
        // and projects (SearchModal.tsx:458).
        ..._buildPeopleGroup(),
      ],
    ).animate().fadeIn(duration: 180.ms);
  }

  /// The PEOPLE group: up to [_kPeopleSuggestionLimit] preview rows plus a row
  /// that opens the full paginated People Search.
  ///
  /// Nothing at all when this fetch matched no one — an empty heading would
  /// imply a category with no matches, the same reason
  /// [_buildSuggestionGroup] returns an empty list.
  List<Widget> _buildPeopleGroup() {
    if (_peopleSuggestions.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingXL,
          vertical: AppConstants.spacingS,
        ),
        child: _buildSectionLabel('PEOPLE'),
      ),
      for (final profile in _peopleSuggestions)
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppConstants.spacingXL),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: PeopleAvatar(
              avatarUrl: profile.avatarUrl,
              initials: profile.initials,
              size: 34,
            ),
            // display_name first, company second — a person's card leads with
            // the person (SearchModal.tsx:492-500). `displayTitle` would invert
            // that, since it prefers the company name.
            title: Text(
              profile.displayName ?? profile.companyName ?? 'PropCid Member',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              _peopleSubtitle(profile),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _openPersonProfile(profile),
          ),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingXL),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.groups_outlined, color: AppColors.primary),
          title: Text(
            'See all people matching "${_searchController.text.trim()}"',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
          onTap: _openPeopleSearch,
        ),
      ),
    ];
  }

  /// "Broker at Prestige Realty" — the portal's own subtitle composition
  /// (SearchModal.tsx:494-501), which prints the role and appends the company
  /// only when there is one.
  String _peopleSubtitle(UserProfile profile) {
    final role = roleLabel(profile.userType);
    final company = profile.companyName ?? profile.agencyName;
    if (company == null || company.trim().isEmpty) return role;
    return '$role at ${company.trim()}';
  }

  /// Opens a person's public profile straight from the dropdown, which is what
  /// every people card in the portal does (`navigate('/profile/:id')`).
  void _openPersonProfile(UserProfile profile) {
    _searchFocusNode.unfocus();
    Navigator.pushNamed(
      context,
      AppConstants.publicProfileScreen,
      arguments: {'userId': profile.userId},
    );
  }

  /// Opens the full People Search, seeded with the current query.
  void _openPeopleSearch() {
    _searchFocusNode.unfocus();
    Navigator.pushNamed(
      context,
      AppConstants.peopleSearchScreen,
      arguments: {'query': _searchController.text.trim()},
    );
  }

  /// Renders one type's heading and rows, or nothing at all when this fetch
  /// returned no results of that type — an empty heading would otherwise imply
  /// a category that simply has no matches.
  List<Widget> _buildSuggestionGroup(_SuggestionGroup group) {
    final matches = _suggestions.where((s) => s.type == group.type).toList();
    if (matches.isEmpty) return const [];

    return [
      Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spacingXL,
          vertical: AppConstants.spacingS,
        ),
        child: _buildSectionLabel(group.label),
      ),
      for (final suggestion in matches)
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: AppConstants.spacingXL),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(group.icon, color: AppColors.primary),
            title: Text(suggestion.label),
            subtitle: suggestion.description != null
                ? Text(suggestion.description!)
                : null,
            onTap: () => _onSuggestionTap(suggestion),
          ),
        ),
    ];
  }
}
