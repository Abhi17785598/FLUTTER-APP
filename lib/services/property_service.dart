import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/available_location.dart';
import '../models/global_search_suggestion.dart';
import '../models/property_detail_bundle.dart';
import '../models/property_model.dart';
import '../models/search_query_params.dart';
import '../models/tagged_project.dart';
import '../providers/post_property_provider.dart';
import '../screens/post_property/listing_field_keys.dart';
import '../screens/post_property/listing_value_aliases.dart';

/// Raw data bundle returned by [PropertyService.fetchForEdit]. Contains the
/// unprocessed Supabase rows so the provider can restore every form field.
class PropertyEditBundle {
  final Map<String, dynamic> propertyRow;
  final Map<String, dynamic>? subtableRow;
  final Map<String, dynamic>? contactRow;

  const PropertyEditBundle({
    required this.propertyRow,
    this.subtableRow,
    this.contactRow,
  });
}

/// Free-text search stopwords — exact port of Search.tsx's list. Words
/// shorter than 2 characters are dropped regardless of this set.
const Set<String> _searchStopwords = {
  'in', 'at', 'for', 'the', 'properties', 'property', 'show', 'list',
  'find', 'search', 'a', 'an', 'of', 'with',
};

/// The 5 columns Search.tsx OR-ILIKE-matches every remaining search word
/// against.
const List<String> _searchColumns = [
  'title', 'search_text', 'location', 'area', 'upid',
];

/// `metadata.pgHouseRules` sub-key -> the `PropertyFormData` flag React reads
/// it from (PropertyWizard.tsx:1649). The names differ on both sides of the
/// colon, so this mapping is not derivable.
const Map<String, String> _kPgHouseRuleSources = {
  'visitorEntry': 'pgVisitorEntry',
  'nonVegFood': 'pgNonVegFood',
  'oppositeGender': 'pgOppositeGender',
  'smoking': 'pgSmoking',
  'drinking': 'pgDrinking',
  'loudMusic': 'pgLoudMusic',
  'party': 'pgParty',
};

/// Fields the wizard collects but React never persists — the value exists only
/// to drive the UI for the current session.
///
/// `ratePerAreaUnit` labels the rate-per-area input (PricingStep.tsx:132) and
/// appears in no fillMetadata list, no column and no direct assignment.
const Set<String> _kUiOnlyFields = {'ratePerAreaUnit'};

class PropertyService {
  final _supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getProperties() async {
    final data = await _supabase
        .from('properties')
      .select('*,properties_residential(*),properties_commercial(*),properties_land(*)')
        .eq('status', 'active')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  /// Mirrors the React SellerWall query (SellerWall.tsx:221–226):
  ///   SELECT * FROM properties WHERE user_id = uid ORDER BY created_at DESC
  /// No status filter — all of the user's listings are returned regardless of
  /// status so the dashboard can show active/inactive/sold badges. No
  /// sub-table joins — the dashboard card does not need beds/baths/parking.
  Future<List<PropertyModel>> getPropertiesByUser(String userId) async {
    final rows = await _supabase
        .from('properties')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(rows)
        .map((r) => PropertyModel.fromSupabase(r))
        .toList();
  }

  /// Ports Search.tsx's buildSupabaseQuery/performSearch exactly — same
  /// table, same conditional embedded-selects, same filters, same sort
  /// options. Budget is deliberately NEVER sent as a DB filter here (see
  /// the plan's Risk B): price_min/price_max are sparsely populated, so the
  /// website compares budget against the parsed free-text `price` column
  /// client-side instead — PropertyProvider does that step, not this method.
  ///
  /// [includeRange] controls whether `.range()` pagination is applied
  /// (normal list-mode paging) or a single safety-capped `.limit()` fetch is
  /// used instead (near-me / map modes, which need the whole matching set
  /// at once — see the plan's "Deliberate deviations").
  Future<PropertySearchPage> searchProperties({
    required SearchQueryParams params,
    required int offset,
    required int limit,
    bool includeRange = true,
  }) async {
    final bool postedByActive = params.postedBy != null;
    final bool bhkActive = params.bhk != null;

    final selectFields = <String>[
      '*',
      postedByActive
          ? 'user_profile:user_id!inner(display_name,user_type,company_name,avatar_url)'
          : 'user_profile:user_id(display_name,user_type,company_name,avatar_url)',
      bhkActive
          ? 'residentialDetails:properties_residential!properties_residential_property_id_fkey!inner(bedrooms,bathrooms,furnished,floor_number,total_floors)'
          : 'residentialDetails:properties_residential!properties_residential_property_id_fkey(bedrooms,bathrooms,furnished,floor_number,total_floors)',
    ];

    PostgrestFilterBuilder<PostgrestList> query = _supabase
        .from('properties')
        .select(selectFields.join(','))
        .inFilter('status', ['active', 'sold'])
        .eq('approval_status', 'approved');

    if (params.cities.length == 1) {
      query = query.ilike('location', '%${params.cities.first}%');
    } else if (params.cities.length > 1) {
      query = query.or(
        params.cities.map((c) => 'location.ilike.%$c%').join(','),
      );
    }

    if (params.category != null) {
      query = query.eq('category', params.category!);
    }
    if (params.listingType != null) {
      query = query.eq('property_type', params.listingType!);
    }
    if (params.hashtag != null && params.hashtag!.isNotEmpty) {
      query = query.contains('hashtags', [params.hashtag!]);
    }

    final searchText = params.searchText.trim();
    if (searchText.isNotEmpty) {
      final sanitized = searchText.replaceAll(RegExp(r'[,()\\]'), '');
      final words = sanitized
          .split(RegExp(r'\s+'))
          .where((w) => w.length >= 2 && !_searchStopwords.contains(w.toLowerCase()));
      final clauses = <String>[
        for (final word in words)
          for (final col in _searchColumns) '$col.ilike.%$word%',
      ];
      if (clauses.isNotEmpty) {
        query = query.or(clauses.join(','));
      }
    }

    if (params.bhk != null) {
      if (params.bhk! >= 5) {
        query = query.gte('residentialDetails.bedrooms', 5);
      } else {
        query = query.eq('residentialDetails.bedrooms', params.bhk!);
      }
    }

    if (params.subtype != null && params.subtype!.isNotEmpty) {
      query = query.ilike('residential_subtype', '%${params.subtype}%');
    }

    if (params.postedBy != null) {
      final userTypes = switch (params.postedBy) {
        'Owner' => ['individual', 'seller'],
        'Agent' => ['broker', 'dealer', 'agent'],
        'Builder' => ['builder'],
        _ => null,
      };
      if (userTypes != null) {
        query = query.inFilter('user_profile.user_type', userTypes);
      }
    }

    // .order() returns PostgrestTransformBuilder (the parent class), not
    // PostgrestFilterBuilder — all filtering above must happen before this
    // point, since nothing after can be assigned back into `query`.
    final PostgrestTransformBuilder<PostgrestList> sortedQuery = query
        .order(params.sort.column, ascending: params.sort.ascending)
        // Deterministic tiebreaker — only needed because this method paginates
        // and the website doesn't; without it, `.range()` paging across rows
        // with duplicate sort-column values could skip or repeat results.
        .order('id', ascending: true);

    final PostgrestResponse<PostgrestList> response = includeRange
        ? await sortedQuery.range(offset, offset + limit - 1).count(CountOption.exact)
        : await sortedQuery.limit(limit).count(CountOption.exact);

    return PropertySearchPage(
      rows: List<Map<String, dynamic>>.from(response.data),
      totalCount: response.count,
    );
  }

  /// Ports PropertyDetails.tsx's exact 3-query shape: the property row, its
  /// owner's profile (auth-aware column list — phone only when signed in),
  /// then exactly one of properties_land/_residential/_commercial branched
  /// on category. Reshapes into the same map shape the bulk query already
  /// produces so PropertyModel.fromSupabase is the single, shared parser for
  /// both fetch paths.
  Future<PropertyDetailBundle> getPropertyDetail(String propertyId) async {
    final Map<String, dynamic> propertyRow = await _supabase
        .from('properties')
        .select('*')
        .eq('id', propertyId)
        .single();

    final String? ownerUserId = propertyRow['user_id']?.toString();
    Map<String, dynamic>? profileRow;
    if (ownerUserId != null) {
      final bool isSignedIn = _supabase.auth.currentUser != null;
      final String profileColumns = isSignedIn
          ? 'display_name, avatar_url, user_type, phone, social_media'
          : 'display_name, avatar_url, user_type, social_media';
      profileRow = await _supabase
          .from('profiles')
          .select(profileColumns)
          .eq('user_id', ownerUserId)
          .maybeSingle();
    }

    final String? category = propertyRow['category']?.toString();
    final String? subtypeTable = switch (category) {
      'land' => 'properties_land',
      'residential' || 'pg_coliving' => 'properties_residential',
      'commercial' => 'properties_commercial',
      _ => null,
    };

    final Map<String, dynamic> mergedRow = {...propertyRow};
    if (subtypeTable != null) {
      final subtypeRow = await _supabase
          .from(subtypeTable)
          .select('*')
          .eq('property_id', propertyRow['id'])
          .maybeSingle();
      mergedRow[subtypeTable] = subtypeRow;
    }

    return PropertyDetailBundle(
      property: PropertyModel.fromSupabase(mergedRow),
      ownerProfile:
          profileRow != null ? PropertyOwnerProfile.fromSupabase(profileRow) : null,
    );
  }

  /// Ports RelatedPropertyCards.tsx's two-tier query: narrow-select same
  /// type+category+approved+city-substring match, falling back to a
  /// broader query (dropping the city filter) only if fewer than 4 rows
  /// came back, then de-duping and capping to 6 in that fallback branch
  /// only.
  Future<List<PropertyModel>> getRelatedProperties({
    required String propertyId,
    required String propertyType,
    required String category,
    required String location,
  }) async {
    const columns =
        'id, title, location, price, media_urls, category, property_type, area, area_unit, status, metadata';
    final cityToken = location.split(',').first.trim().toLowerCase();

    final primaryRows = List<Map<String, dynamic>>.from(await _supabase
        .from('properties')
        .select(columns)
        .eq('approval_status', 'approved')
        .eq('property_type', propertyType)
        .eq('category', category)
        .neq('id', propertyId)
        .ilike('location', '%$cityToken%')
        .limit(10));

    List<Map<String, dynamic>> rows = primaryRows;

    if (rows.length < 4) {
      final fallbackRows = List<Map<String, dynamic>>.from(await _supabase
          .from('properties')
          .select(columns)
          .eq('approval_status', 'approved')
          .eq('property_type', propertyType)
          .eq('category', category)
          .neq('id', propertyId)
          .limit(10));

      final seenIds = {for (final r in rows) r['id'].toString()};
      for (final r in fallbackRows) {
        final id = r['id']?.toString();
        if (id != null && seenIds.add(id)) {
          rows.add(r);
        }
      }
      rows = rows.where((r) => (r['title'] as String? ?? '').isNotEmpty).toList();
      if (rows.length > 6) {
        rows = rows.sublist(0, 6);
      }
    }

    return rows.map((r) => PropertyModel.fromSupabase(r)).toList();
  }

  /// Calls the `track_property_view` RPC exactly as the website does — same
  /// param names, same server-side 30-minute dedupe semantics.
  Future<bool> trackPropertyView({
    required String propertyId,
    String? viewerUserId,
    required String viewerSessionId,
    required int viewDurationSeconds,
    required int viewPercentage,
  }) async {
    final result = await _supabase.rpc('track_property_view', params: {
      'property_uuid': propertyId,
      'viewer_user_id': viewerUserId,
      'viewer_session_id': viewerSessionId,
      'view_duration': viewDurationSeconds,
      'view_percentage': viewPercentage,
    });
    return result as bool? ?? false;
  }

  Future<List<AvailableLocation>> getAvailableLocations() async {
    final rows = await _supabase
        .from('available_locations')
        .select('id,city,state,country,latitude,longitude')
        .eq('is_active', true)
        .order('display_order');

    return List<Map<String, dynamic>>.from(rows)
        .map((r) => AvailableLocation.fromSupabase(r))
        .toList();
  }

  /// Calls the `global_search` RPC used for the debounced autocomplete
  /// dropdown. See GlobalSearchSuggestion.fromSupabase for why the id field
  /// is read defensively.
  Future<List<GlobalSearchSuggestion>> globalSearch(String term) async {
    final result = await _supabase.rpc('global_search', params: {
      'search_term': term,
    });
    return List<Map<String, dynamic>>.from(result as List<dynamic>)
        .map((r) => GlobalSearchSuggestion.fromSupabase(r))
        .toList();
  }

  /// Fetches raw property, sub-table, and contact rows for pre-filling the
  /// edit wizard. Mirrors SellerWall.tsx lines 372–411.
  Future<PropertyEditBundle> fetchForEdit(String propertyId) async {
    final propertyRow = await _supabase
        .from('properties')
        .select('*')
        .eq('id', propertyId)
        .single();

    final String? category = propertyRow['category']?.toString();
    final String? subtableTable = switch (category) {
      'residential' || 'pg_coliving' => 'properties_residential',
      'commercial' => 'properties_commercial',
      'land' => 'properties_land',
      _ => null,
    };

    final Map<String, dynamic>? subtableRow = subtableTable != null
        ? await _supabase
            .from(subtableTable)
            .select('*')
            .eq('property_id', propertyId)
            .maybeSingle()
        : null;

    final Map<String, dynamic>? contactRow = await _supabase
        .from('property_contact_details')
        .select('*')
        .eq('property_id', propertyId)
        .maybeSingle();

    return PropertyEditBundle(
      propertyRow: Map<String, dynamic>.from(propertyRow),
      subtableRow: subtableRow != null
          ? Map<String, dynamic>.from(subtableRow)
          : null,
      contactRow: contactRow != null
          ? Map<String, dynamic>.from(contactRow)
          : null,
    );
  }

  /// Deletes a property row by ID. Sub-tables rely on ON DELETE CASCADE or are
  /// left orphaned (same behavior as the React dashboard delete flow).
  Future<void> deleteProperty(String propertyId) async {
    await _supabase.from('properties').delete().eq('id', propertyId);
  }

  /// Flips one listing's `status`, the way the dashboard's inline picker does on
  /// the website (BrokerContentManager.tsx:85-112: a bare
  /// `update({ status }).eq('id', …)`, nothing else in the payload).
  ///
  /// Appended rather than folded into [updateProperty] on purpose. That method
  /// documents "does NOT touch status" and rebuilds the whole row from a
  /// [PostPropertyProvider]; a status flip has no provider and must not disturb
  /// media, metadata or the sub-tables. No existing method, signature or caller
  /// changes as a result of this one.
  ///
  /// [status] is deliberately not validated here: the caller picks from
  /// [propertyStatusOptions], and the column's own CHECK is the real authority.
  /// The `updated_at` trigger fires on its own — the website does not set it
  /// either.
  ///
  /// RLS restricts the UPDATE to `auth.uid() = user_id`, so a non-owner's call
  /// matches no row and completes silently, exactly as it does on the website.
  Future<void> setPropertyStatus(String propertyId, String status) async {
    await _supabase
        .from('properties')
        .update({'status': status})
        .eq('id', propertyId);
  }

  /// Updates an existing property listing. Mirrors the React PropertyWizard
  /// edit-submission path (PropertyWizard.tsx lines 1741–1909).
  /// - Uploads any newly-added media items and combines with existing URLs.
  /// - Does NOT touch [status], [user_id], or [amenities] — preserves existing.
  Future<void> updateProperty(
    String propertyId,
    PostPropertyProvider provider,
    String userId,
  ) async {
    final List<String> newUrls = await _uploadMedia(provider, userId);
    final List<String> allUrls = [...provider.existingMediaUrls, ...newUrls];

    // Non-destructive update: merge onto the row's existing metadata instead
    // of replacing the column, mirroring React's
    // `const metadata = { ...editingProperty.metadata }`
    // (PropertyWizard.tsx:1561).
    //
    // Without this, any key the Flutter form does not currently collect —
    // nested objects like `buildingInventory`, the PG block, land legal
    // flags — was silently dropped the first time a listing was edited in
    // the app. Nested objects are deliberately preserved here rather than
    // hydrated into the provider; full editing support for them lands with
    // the category parity phases.
    final Map<String, dynamic> existingMetadata =
        await _fetchExistingMetadata(propertyId);
    final Map<String, dynamic> metadata = _fillTypedEmpties(
      _applyProjectTag(<String, dynamic>{
        ...existingMetadata,
        ..._buildMetadata(provider),
      }, provider),
    );

    await _supabase.from('properties').update({
      'title': provider.title,
      'description': provider.description,
      'location': provider.location,
      'latitude': provider.latitude,
      'longitude': provider.longitude,
      'price': _headlinePrice(provider),
      'area': provider.area.isEmpty ? '0' : provider.area,
      'area_unit': provider.areaUnit.isEmpty
          ? 'sq_ft'
          : canonicalAreaUnit(provider.areaUnit),
      'rate_per_area': double.tryParse(provider.ratePerArea),
      'available_from': _availableFrom(provider),
      'hashtags': _parseHashtags(provider.hashtags),
      'amenities': provider.listVal('amenities'),
      'media_urls': allUrls,
      'main_display_media_url': _mainDisplayUrl(provider, allUrls),
      'property_type': (provider.listingIntent ??
              (throw StateError('Listing intent must be selected.')))
          .name,
      'category': _categoryToDb(provider.category ??
          (throw StateError('Property category must be selected.'))),
      // React writes this key unconditionally, using '' for every non-
      // residential category (PropertyWizard.tsx:1784). Omitting it left the
      // nullable column NULL, which breaks the dbSafe rule that nothing
      // reaches Postgres as NULL except dates and FKs — and any web reader
      // doing `.trim()` on it would throw.
      'residential_subtype': provider.category == PropertyCategory.residential
          ? canonicalResidentialSubtype(provider.residentialSubType ?? '')
          : '',
      // null, never '' — the column is a uuid FK to builder_projects, so a
      // placeholder would fail the constraint (React uses dbUuid for this).
      'project_id': provider.projectId.isEmpty ? null : provider.projectId,
      'metadata': metadata,
    }).eq('id', propertyId);

    await _upsertCategoryData(propertyId, provider);
    await _upsertContactDetails(propertyId, provider);
  }

  // ── Builder project tag (T5) ──────────────────────────────────────────
  //
  // Tag only: searching and attaching an existing project. Creating projects
  // and the inventory subsystem stay React-only by decision.

  /// Attaches the builder/company name to each project.
  ///
  /// `builder_projects` has no FK to `profiles`, so React resolves the names in
  /// a second query rather than embedding them
  /// (ProjectTagSelector.tsx:35). Company name wins over display name.
  Future<List<TaggedProject>> _withBuilderNames(
    List<TaggedProject> projects,
  ) async {
    final ids = projects.map((p) => p.builderId).where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return projects;

    final rows = await _supabase
        .from('profiles_public')
        .select('user_id, display_name, company_name')
        .inFilter('user_id', ids.toList());

    final nameById = <String, String>{
      for (final r in List<Map<String, dynamic>>.from(rows))
        r['user_id'].toString(): (r['company_name']?.toString().isNotEmpty ?? false)
            ? r['company_name'].toString()
            : (r['display_name']?.toString() ?? ''),
    };

    return projects
        .map((p) => p.copyWith(builderName: nameById[p.builderId]))
        .toList();
  }

  /// Projects a listing may be tagged to.
  ///
  /// Mirrors ProjectTagSelector.tsx:130 exactly: active + approved only; a
  /// search term of 2+ characters matches title or location, otherwise the
  /// listing's city is used to suggest nearby projects; newest first, capped
  /// at 12.
  ///
  /// Note this is NOT restricted to the signed-in user's own projects — the
  /// migration specification says otherwise (PHASE 4), but React is the
  /// authority and the feature exists so a broker can tag a *developer's*
  /// project.
  Future<List<TaggedProject>> searchBuilderProjects({
    String term = '',
    String city = '',
  }) async {
    var request = _supabase
        .from('builder_projects')
        .select(TaggedProject.columns)
        .eq('status', 'active')
        .eq('approval_status', 'approved');

    final trimmed = term.trim();
    if (trimmed.length >= 2) {
      final escaped = trimmed.replaceAll(RegExp(r'[%,]'), ' ');
      request = request.or('title.ilike.%$escaped%,location.ilike.%$escaped%');
    } else if (city.isNotEmpty) {
      request = request.ilike('location', '%$city%');
    }

    final rows =
        await request.order('created_at', ascending: false).limit(12);

    return _withBuilderNames(
      List<Map<String, dynamic>>.from(rows)
          .map(TaggedProject.fromSupabase)
          .toList(),
    );
  }

  /// Loads a single tagged project, for showing the chip when editing an
  /// already-tagged listing. Mirrors `fetchTaggedProject`.
  Future<TaggedProject?> fetchTaggedProject(String projectId) async {
    if (projectId.isEmpty) return null;
    final row = await _supabase
        .from('builder_projects')
        .select(TaggedProject.columns)
        .eq('id', projectId)
        .maybeSingle();
    if (row == null) return null;

    final resolved = await _withBuilderNames([TaggedProject.fromSupabase(row)]);
    return resolved.first;
  }

  /// The value written to the `price` column.
  ///
  /// PG / co-living never fills the single price box — PricingStep asks for
  /// per-bed / per-room rent, or a total sale price. React mirrors whichever
  /// applies into `price` so cards, search filters and sorting see a real
  /// amount (PropertyWizard.tsx:1746); without it every app-created PG listing
  /// renders as "Price on Request" and sorts as though it were free.
  ///
  /// `properties.price` is `text NOT NULL`, so this never returns null and
  /// falls back to '0' exactly as React's `dbText(headlinePrice || price, '0')`
  /// does.
  static String _headlinePrice(PostPropertyProvider provider) {
    String result = provider.price;

    if (provider.category == PropertyCategory.pg) {
      switch (provider.listingIntent) {
        case ListingIntent.sell:
          result = provider.text('totalSalePrice');
        case ListingIntent.rent:
          final perBed = provider.text('monthlyRentPerBed');
          result = perBed.isNotEmpty
              ? perBed
              : provider.text('monthlyRentPerRoom');
        case ListingIntent.lease:
        case null:
          result = provider.price;
      }
    }

    if (result.trim().isEmpty) result = provider.price;
    return result.trim().isEmpty ? '0' : result;
  }

  /// `available_from` as React stores it: the literal 'Immediately', or a
  /// plain `YYYY-MM-DD` date — never a full ISO-8601 timestamp.
  ///
  /// The column is text and React's input is `<input type="date">`, so writing
  /// `toIso8601String()` put `2026-07-31T00:00:00.000` where the web expects
  /// `2026-07-31`. React defaults the column to 'Immediately' when unset.
  static String _availableFrom(PostPropertyProvider provider) {
    final DateTime? d = provider.availableFrom;
    if (d == null) return 'Immediately';
    final String mm = d.month.toString().padLeft(2, '0');
    final String dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  /// The listing's main image: the photo the user starred, or the first one.
  ///
  /// Mirrors `dbText(formData.mainDisplayMediaUrl, allMediaUrls[0] ?? '')`
  /// (PropertyWizard.tsx:1773) — never null, empty only when there are no
  /// photos at all. The starred URL is ignored if it is no longer among the
  /// listing's media, which happens when the user removes the starred photo
  /// and saves without picking another.
  static String _mainDisplayUrl(
    PostPropertyProvider provider,
    List<String> allUrls,
  ) {
    final String starred = provider.mainDisplayMediaUrl;
    if (starred.isNotEmpty && allUrls.contains(starred)) return starred;
    return allUrls.isNotEmpty ? allUrls.first : '';
  }

  /// Reads the current `metadata` blob for [propertyId] so an edit can merge
  /// onto it rather than replace it. Returns an empty map if the row is gone
  /// or the column is null/not an object — the caller then behaves exactly as
  /// it did before, so a read failure can never make the update *more*
  /// destructive than it already was.
  Future<Map<String, dynamic>> _fetchExistingMetadata(String propertyId) async {
    final row = await _supabase
        .from('properties')
        .select('metadata')
        .eq('id', propertyId)
        .maybeSingle();

    final dynamic meta = row?['metadata'];
    return meta is Map ? Map<String, dynamic>.from(meta) : <String, dynamic>{};
  }

  /// Creates a property listing on Supabase, mirroring the React
  /// PropertyWizard submission flow exactly. Returns the new property's UUID.
  Future<String> createProperty(
    PostPropertyProvider provider,
    String userId,
  ) async {
    await _checkApproval(userId);
    final List<String> uploadedUrls = await _uploadMedia(provider, userId);
    final Map<String, dynamic> metadata = _fillTypedEmpties(
      _applyProjectTag(_buildMetadata(provider), provider),
    );
    final String propertyId =
        await _insertProperty(provider, userId, uploadedUrls, metadata);
    await _insertCategoryData(propertyId, provider);
    await _insertContactDetails(propertyId, provider);
    return propertyId;
  }

  /// Inserts the main `properties` row and returns its UUID.
  Future<String> _insertProperty(
    PostPropertyProvider provider,
    String userId,
    List<String> uploadedUrls,
    Map<String, dynamic> metadata,
  ) async {
    final row = <String, dynamic>{
      'user_id': userId,
      'title': provider.title,
      'description': provider.description,
      'location': provider.location,
      'latitude': provider.latitude,
      'longitude': provider.longitude,
      'price': _headlinePrice(provider),
      'area': provider.area.isEmpty ? '0' : provider.area,
      'area_unit': provider.areaUnit.isEmpty
          ? 'sq_ft'
          : canonicalAreaUnit(provider.areaUnit),
      'rate_per_area': double.tryParse(provider.ratePerArea),
      'available_from': _availableFrom(provider),
      // React: dbArray<string>(formData.amenities) — the residential society /
      // flat / parking pickers all toggle into this one array, and it backs the
      // web's amenity filters. Flutter previously hard-coded an empty list, so
      // no app-created listing was ever findable by amenity.
      'amenities': provider.listVal('amenities'),
      'hashtags': _parseHashtags(provider.hashtags),
      'media_urls': uploadedUrls,
      'main_display_media_url': _mainDisplayUrl(provider, uploadedUrls),
      'property_type': (provider.listingIntent ??
              (throw StateError('Listing intent must be selected before publishing.')))
          .name,
      'category': _categoryToDb(provider.category ??
          (throw StateError('Property category must be selected before publishing.'))),
      // React writes this key unconditionally, using '' for every non-
      // residential category (PropertyWizard.tsx:1784). Omitting it left the
      // nullable column NULL, which breaks the dbSafe rule that nothing
      // reaches Postgres as NULL except dates and FKs — and any web reader
      // doing `.trim()` on it would throw.
      'residential_subtype': provider.category == PropertyCategory.residential
          ? canonicalResidentialSubtype(provider.residentialSubType ?? '')
          : '',
      'project_id': provider.projectId.isEmpty ? null : provider.projectId,
      'metadata': metadata,
      'status': 'active',
    };

    final result = await _supabase
        .from('properties')
        .insert(row)
        .select('id')
        .single();

    return result['id'] as String;
  }

  /// Dispatches to the correct category sub-table INSERT based on [provider.category].
  /// Other (and null) categories have no sub-table; the call is a no-op.
  Future<void> _insertCategoryData(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    switch (provider.category) {
      case PropertyCategory.residential:
      case PropertyCategory.pg:
        await _insertResidential(propertyId, provider);
      case PropertyCategory.commercial:
        await _insertCommercial(propertyId, provider);
      case PropertyCategory.land:
        await _insertLand(propertyId, provider);
      default:
        break;
    }
  }

  /// INSERT into `properties_residential`.
  /// Used for both residential and pg categories (React does the same).
  Future<void> _insertResidential(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    await _supabase.from('properties_residential').insert({
      'property_id': propertyId,
      'bedrooms': int.tryParse(provider.bedrooms),
      'bathrooms': int.tryParse(provider.bathrooms),
      'built_up_area_sqft': double.tryParse(provider.area),
      'carpet_area_sqft': double.tryParse(provider.carpetArea),
      'balconies': int.tryParse(provider.balconies),
      'furnished': provider.furnishingType == 'Furnished' ||
          provider.furnishingType == 'Semi-Furnished',
      'parking_spaces': int.tryParse(provider.coveredParking),
      'floor_number': int.tryParse(provider.floorNo),
      'total_floors': int.tryParse(provider.totalFloors),
      'age_of_property': null,    // no provider field; React also sends null
      'facing_direction': provider.facing,
    });
  }

  /// INSERT into `properties_commercial`.
  Future<void> _insertCommercial(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    await _supabase.from('properties_commercial').insert({
      'property_id': propertyId,
      'built_up_area_sqft': double.tryParse(provider.area),
      'carpet_area_sqft': double.tryParse(provider.carpetArea),
      // 'washrooms' key confirmed in amenities_step.dart
      'washrooms': int.tryParse(provider.text('washrooms')),
      // Commercial uses the 'totalParking' bag field, not the typed coveredParking
      'parking_spaces': int.tryParse(provider.text('totalParking')),
      // Commercial dimensions use dedicated bag keys, not the typed floorNo/totalFloors
      'floor_number': int.tryParse(provider.text('floorNumber')),
      'total_floors': int.tryParse(provider.text('totalFloorsCommercial')),
      'furnished': provider.furnishingType == 'Furnished' ||
          provider.furnishingType == 'Semi-Furnished',
      // React maps guardRoom → cafeteria; defaults to false if not set in commercial UI
      'cafeteria': provider.guardRoom,
      'power_load_kw': double.tryParse(provider.text('powerLoad')) ?? 0,
      // React maps numberOfCabins → conference_rooms (a non-obvious mapping
      // called out in the architecture review, Q8).
      'conference_rooms': int.tryParse(provider.text('numberOfCabins')) ?? 0,
    });
  }

  /// INSERT into `properties_land`.
  /// `properties_land` payload, mirroring React's `landData`
  /// (PropertyWizard.tsx:1896).
  ///
  /// Every column is written on every save, never conditionally: React's
  /// dbNum/dbBool/dbText coercers exist precisely so this table never carries
  /// a NULL. Flutter previously wrote only `area_sqft` and a conditional
  /// `soil_type`, leaving four columns NULL.
  ///
  /// `boundary`, `waterSource` and `roadWidth` have no input in React either —
  /// they are persisted but never collected — so they resolve to the same
  /// typed-empty values the web writes rather than being invented here.
  static Map<String, dynamic> _landRow(
    String propertyId,
    PostPropertyProvider provider,
  ) {
    return {
      'property_id': propertyId,
      'area_sqft': double.tryParse(provider.area) ?? 0,
      'boundary_wall': provider.boolVal('boundary'),
      'water_source': provider.text('waterSource'),
      'road_width_ft': double.tryParse(provider.text('roadWidth')) ?? 0,
      'soil_type': provider.text('soilType'),
      // Not collected by either wizard; 0 keeps the column populated.
      'slope_percentage': 0,
    };
  }

  Future<void> _insertLand(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    await _supabase.from('properties_land').insert(_landRow(propertyId, provider));
  }

  /// INSERT into `property_contact_details`.
  /// Mirrors React lines 1881-1910: only inserts when at least one contact
  /// field is present. If both are empty, the call is skipped entirely.
  Future<void> _insertContactDetails(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    final phone = provider.contactPhone.trim();
    final email = provider.contactEmail.trim();
    if (phone.isEmpty && email.isEmpty) return;

    await _supabase.from('property_contact_details').insert({
      'property_id': propertyId,
      'contact_phone': phone.isNotEmpty ? phone : null,
      'contact_email': email.isNotEmpty ? email : null,
    });
  }

  /// Uploads every MediaItem in [provider] to the `property-media` bucket,
  /// mirroring the React upload loop (PropertyWizard.tsx lines 1471-1511).
  /// Path pattern: `{userId}/{timestamp}-{index}.{ext}`
  /// Returns the list of public URLs in the same order as the media items.
  Future<List<String>> _uploadMedia(
    PostPropertyProvider provider,
    String userId,
  ) async {
    final List<String> urls = [];
    for (int i = 0; i < provider.mediaItems.length; i++) {
      final item = provider.mediaItems[i];
      final bytes = await item.file.readAsBytes();
      final ext = item.file.name.split('.').last.toLowerCase();
      final contentType = item.file.mimeType ?? _mimeFromExt(ext);
      final path =
          '$userId/${DateTime.now().millisecondsSinceEpoch}-$i.$ext';
      await _supabase.storage
          .from('property-media')
          .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: contentType));
      final url =
          _supabase.storage.from('property-media').getPublicUrl(path);
      urls.add(url);
    }
    return urls;
  }

  static String _mimeFromExt(String ext) => switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png'           => 'image/png',
    'webp'          => 'image/webp',
    'heic'          => 'image/heic',
    'mp4'           => 'video/mp4',
    'mov'           => 'video/quicktime',
    _               => 'application/octet-stream',
  };

  /// Converts the Flutter [PropertyCategory] enum to the DB category string.
  /// The only non-trivial mapping is pg → pg_coliving.
  /// Maps the Flutter category enum onto the `property_category` Postgres enum.
  ///
  /// Both non-obvious cases are spelled out rather than derived from
  /// `c.name`: PG is `pg_coliving`, and Other is **`others`** (plural).
  /// `PropertyCategory.other.name` is `'other'`, which is NOT a member of the
  /// enum — the DB accepts only
  /// `residential, commercial, land, pg_coliving, others` — so relying on the
  /// enum name made every "Others" listing fail at insert.
  static String _categoryToDb(PropertyCategory c) => switch (c) {
    PropertyCategory.pg => 'pg_coliving',
    PropertyCategory.other => 'others',
    _ => c.name, // residential, commercial, land
  };

  /// Parses a raw hashtag string (e.g. "#city #luxury sale") into the array
  /// format stored in the properties.hashtags column.
  /// Mirrors the React sanitizedHashtags computation: splits on whitespace,
  /// keeps tokens that start with '#', strips the leading '#'.
  static List<String> _parseHashtags(String raw) {
    return raw
        .trim()
        .split(RegExp(r'\s+'))
        .where((t) => t.startsWith('#') && t.length > 1)
        .map((t) => t.substring(1))
        .toList();
  }

  /// Builds the metadata JSONB object mirroring the React PropertyWizard
  /// metadata construction (PropertyWizard.tsx lines 1502-1711).
  /// Only fields that have a matching provider getter are included.
  Map<String, dynamic> _buildMetadata(PostPropertyProvider provider) {
    final meta = <String, dynamic>{};

    // ── Category-specific long-tail bag fields ────────────────────────────
    // Commercial/Land/PG fields are stored in typed bags keyed by the same
    // React field names. Spread all three bags — JSONB accepts them all.
    //
    // Flushed FIRST, before the named writes below, so that on a key
    // collision the named field wins. This ordering matters now that edit
    // mode hydrates the metadata blob back into the bag
    // (`PostPropertyProvider.initFromRawData`): a stale bag entry carrying
    // the value loaded from the DB must not overwrite the fresh value the
    // user just typed into the field that owns that key.
    meta.addAll(provider.allTextFields);
    meta.addAll(provider.allBoolFields);
    for (final entry in provider.allListFields.entries) {
      meta[entry.key] = entry.value;
    }
    // Session-only fields: React holds these in `PropertyFormData` and renders
    // them, but writes them to neither a column nor metadata, so persisting
    // them would give app-created rows a key web-created rows never carry.
    for (final key in _kUiOnlyFields) {
      meta.remove(key);
    }

    // ── Others ────────────────────────────────────────────────────────────
    // React stamps the original wizard category for 'others' listings
    // (PropertyWizard.tsx:1563). Note the VALUE is singular 'other' even
    // though the column enum member is plural 'others' — matched verbatim
    // rather than normalised, because web readers compare against this exact
    // string.
    if (provider.category == PropertyCategory.other) {
      meta['originalCategory'] = 'other';
    }

    // ── Location overflow (no dedicated columns in properties table) ───────
    if (provider.city.isNotEmpty) meta['city'] = provider.city;
    if (provider.state.isNotEmpty) meta['state'] = provider.state;
    if (provider.pincode.isNotEmpty) meta['pincode'] = provider.pincode;
    if (provider.landmark.isNotEmpty) meta['landmark'] = provider.landmark;

    // ── Step 4: Condition ─────────────────────────────────────────────────
    if (provider.propertyCondition != null) {
      meta['propertyCondition'] = provider.propertyCondition;
    }
    if (provider.constructionAge != null) {
      meta['constructionAge'] = provider.constructionAge;
    }
    if (provider.availabilityStatus != null) {
      meta['availabilityStatus'] = provider.availabilityStatus;
    }
    if (provider.availableItems.isNotEmpty) {
      meta['availableItems'] = provider.availableItems;
    }

    // ── Step 5: Amenities ─────────────────────────────────────────────────
    if (provider.electricityBackup != null) {
      meta['electricityBackup'] = provider.electricityBackup;
    }
    if (provider.waterAvailability != null) {
      meta['waterAvailability'] = provider.waterAvailability;
    }
    if (provider.numberOfLifts.isNotEmpty) {
      meta['numberOfLifts'] = provider.numberOfLifts;
    }
    if (provider.openParking.isNotEmpty) {
      meta['openParking'] = provider.openParking;
    }
    // Booleans always included (default false is meaningful)
    meta['gasPipeline'] = provider.gasPipeline;
    meta['internetAvailability'] = provider.internetAvailability;
    meta['solarPower'] = provider.solarPower;
    meta['guardRoom'] = provider.guardRoom;

    // ── Step 6: Legal ─────────────────────────────────────────────────────
    meta['reraRegistered'] = provider.reraRegistered;
    if (provider.reraNumber.isNotEmpty) meta['reraNumber'] = provider.reraNumber;
    meta['saleDeed'] = provider.saleDeed;
    meta['registryCopy'] = provider.registryCopy;
    meta['nocAvailable'] = provider.nocAvailable;
    meta['encumbranceFree'] = provider.encumbranceFree;
    meta['loanApproved'] = provider.loanApproved;
    meta['propertyApproved'] = provider.propertyApproved;
    if (provider.facing != null) meta['facing'] = provider.facing;
    if (provider.approvedByBanks.isNotEmpty) {
      meta['approvedByBanks'] = provider.approvedByBanks;
    }

    // ── Step 7: Pricing overflow ──────────────────────────────────────────
    if (provider.securityDeposit.isNotEmpty) {
      meta['securityDeposit'] = provider.securityDeposit;
    }
    // React's canonical key is 'maintenanceCharges' — it is the live input in
    // PricingStep.tsx (bound via handleInputChange('maintenanceCharges')).
    // React's 'maintenanceAmount' is a legacy carry-through field with no UI
    // input anywhere in the wizard; writing there made the web's Maintenance
    // Charges box read empty for Flutter-created listings.
    if (provider.maintenanceCharges.isNotEmpty) {
      meta['maintenanceCharges'] = provider.maintenanceCharges;
    }
    // 'tokenAmount' IS React's canonical key (live input in PricingStep.tsx);
    // only the Flutter-side field is named bookingAmount. Correct as-is.
    if (provider.bookingAmount.isNotEmpty) {
      meta['tokenAmount'] = provider.bookingAmount;
    }
    if (provider.lockInPeriod != null) meta['lockInPeriod'] = provider.lockInPeriod;
    meta['priceNegotiable'] = provider.priceNegotiable;
    // React's canonical key is 'allInclusivePriceToggle'. The previous
    // 'allInclusivePrice' appears nowhere in the React source (0 occurrences
    // repo-wide), so the web could never read it.
    meta['allInclusivePriceToggle'] = provider.allInclusivePriceToggle;
    meta['taxGovtChargesIncluded'] = provider.taxGovtChargesIncluded;
    meta['loanAvailability'] = provider.loanAvailability;
    if (provider.brokerage.isNotEmpty) meta['brokerage'] = provider.brokerage;

    // ── Step 8: Contact overflow ──────────────────────────────────────────
    if (provider.contactName.isNotEmpty) meta['contactName'] = provider.contactName;
    if (provider.whatsappNumber.isNotEmpty) {
      meta['whatsappNumber'] = provider.whatsappNumber;
    }
    if (provider.bestTimeToCall.isNotEmpty) {
      meta['bestTimeToCall'] = provider.bestTimeToCall;
    }

    // ── Category-specific typed fields ────────────────────────────────────
    if (provider.category == PropertyCategory.residential) {
      if (provider.bhkType != null) meta['bhkType'] = provider.bhkType;
    }
    if (provider.category == PropertyCategory.pg) {
      meta['isPg'] = true;
      // React always writes this nested object, with dbBool(...) coercing every
      // unset flag to false (PropertyWizard.tsx:1649), so downstream readers
      // can index into it unconditionally. None of the seven flags has an
      // input in either wizard — they are persisted but never collected — so
      // they resolve to false rather than being invented here.
      meta['pgHouseRules'] = <String, dynamic>{
        for (final entry in _kPgHouseRuleSources.entries)
          entry.key: provider.boolVal(entry.value),
      };
    }

    // ── Commercial building inventory ─────────────────────────────────────
    // React writes this on EVERY save as dbJson(...) — always an object, never
    // undefined, so downstream readers can index into it
    // (PropertyWizard.tsx:1733). Merged over whatever is already stored so the
    // floor-wise and company-wise blocks the app cannot edit survive intact.
    meta['buildingInventory'] = <String, dynamic>{
      ...provider.buildingInventory,
    };

    // ── Media categories ──────────────────────────────────────────────────
    // Parallel array to `media_urls`, so it must be assembled in the SAME
    // order: existing photos first, then newly uploaded ones. React builds it
    // as [...existingMediaUrls.category, ...mediaFiles.category]
    // (PropertyWizard.tsx:1725).
    //
    // Flutter previously wrote only the new items' categories, so editing a
    // listing with existing photos shifted every category by the number of
    // existing images — re-labelling the wrong pictures — and dropped the
    // trailing ones (final-architecture-review NEW-5).
    meta['mediaCategories'] = <String>[
      ...provider.existingMedia.map((m) => m.category),
      ...provider.mediaItems.map((m) => m.category),
    ];

    return meta;
  }

  /// Applies the builder-project tag to an already-merged metadata blob.
  ///
  /// Verbatim port of PropertyWizard.tsx:1597 — note it DELETES keys when the
  /// listing is untagged rather than blanking them.
  ///
  /// **Must run AFTER the merge with the existing blob, never inside
  /// [_buildMetadata].** Removing a key from the freshly built map accomplishes
  /// nothing: `{...existing, ...fresh}` copies `projectId` straight back out of
  /// the stored blob, so clearing a tag in the app would silently not stick.
  /// Same ordering hazard as [_fillTypedEmpties], for the same reason.
  static Map<String, dynamic> _applyProjectTag(
    Map<String, dynamic> meta,
    PostPropertyProvider provider,
  ) {
    if (provider.projectId.isNotEmpty) {
      meta['projectId'] = provider.projectId;
      if (provider.projectName.isNotEmpty) {
        meta['projectName'] = provider.projectName;
      }
      if (provider.builderName.isNotEmpty) {
        meta['builderName'] = provider.builderName;
      }
      if (provider.projectLocation.isNotEmpty) {
        meta['projectLocation'] = provider.projectLocation;
      }
    } else {
      meta.remove('projectId');
      meta.remove('projectLocation');
      if (provider.projectName.isNotEmpty) {
        meta['projectName'] = provider.projectName;
      } else {
        meta.remove('projectName');
      }
      if (provider.builderName.isNotEmpty) {
        meta['builderName'] = provider.builderName;
      } else {
        meta.remove('builderName');
      }
    }
    return meta;
  }

  /// Writes a typed-empty value for every allow-list key still absent, so the
  /// key always exists in the blob (final-architecture-review NEW-4).
  ///
  /// React's `fillMetadata` writes each listed key unconditionally, so a
  /// web-created row has `metadata.someField = ''`. Flutter previously omitted
  /// blanks entirely, so any web reader doing `metadata.foo.trim()` rather than
  /// `metadata.foo?.trim()` would throw on an app-created listing.
  ///
  /// `''` is the right default rather than `false`/`[]`: React's
  /// `getInitialFormData()` returns roughly twenty fields, leaving every other
  /// `PropertyFormData` key `undefined`, and `fillMetadata` sends anything that
  /// is not a bool/array/object through `dbText`, which yields `''`.
  ///
  /// **Call this LAST — after the merge with any existing blob, never inside
  /// [_buildMetadata].** `putIfAbsent` then physically cannot overwrite a value
  /// that is already there. Filling before the merge would blank every key the
  /// provider does not carry, and the provider deliberately does not carry
  /// non-scalar values: nested objects (`buildingInventory`, `pgHouseRules`)
  /// and arrays of objects (`floorWiseRoomDetails`) are excluded from the bag
  /// so they round-trip intact. Blanking those and merging would re-create the
  /// exact data destruction Phase 0 fixed.
  ///
  /// Ordering it this way also means no hand-maintained list of non-scalar keys
  /// has to stay in sync — a list that would silently rot as React adds fields.
  Map<String, dynamic> _fillTypedEmpties(Map<String, dynamic> meta) {
    for (final String key in kAllReactMetadataKeys) {
      // Nested objects are still skipped outright: React writes them via
      // dbJson (an object), so '' would be the wrong type, and Flutter has no
      // value to offer for them until the category parity phases.
      if (kNestedObjectMetadataKeys.contains(key)) continue;
      // React DELETES the builder-project keys when a listing is untagged
      // (PropertyWizard.tsx:1603) instead of writing a blank, so filling them
      // here would resurrect a tag the user just cleared.
      if (kProjectTagMetadataKeys.contains(key)) continue;
      meta.putIfAbsent(key, () => '');
    }
    return meta;
  }

  /// Dispatches to the correct category sub-table UPSERT for edit mode.
  Future<void> _upsertCategoryData(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    switch (provider.category) {
      case PropertyCategory.residential:
      case PropertyCategory.pg:
        await _upsertResidential(propertyId, provider);
      case PropertyCategory.commercial:
        await _upsertCommercial(propertyId, provider);
      case PropertyCategory.land:
        await _upsertLand(propertyId, provider);
      default:
        break;
    }
  }

  Future<void> _upsertResidential(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    await _supabase.from('properties_residential').upsert({
      'property_id': propertyId,
      'bedrooms': int.tryParse(provider.bedrooms),
      'bathrooms': int.tryParse(provider.bathrooms),
      'built_up_area_sqft': double.tryParse(provider.area),
      'carpet_area_sqft': double.tryParse(provider.carpetArea),
      'balconies': int.tryParse(provider.balconies),
      'furnished': provider.furnishingType == 'Furnished' ||
          provider.furnishingType == 'Semi-Furnished',
      'parking_spaces': int.tryParse(provider.coveredParking),
      'floor_number': int.tryParse(provider.floorNo),
      'total_floors': int.tryParse(provider.totalFloors),
      'age_of_property': null,
      'facing_direction': provider.facing,
    }, onConflict: 'property_id');
  }

  Future<void> _upsertCommercial(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    await _supabase.from('properties_commercial').upsert({
      'property_id': propertyId,
      'built_up_area_sqft': double.tryParse(provider.area),
      'carpet_area_sqft': double.tryParse(provider.carpetArea),
      'washrooms': int.tryParse(provider.text('washrooms')),
      'parking_spaces': int.tryParse(provider.text('totalParking')),
      'floor_number': int.tryParse(provider.text('floorNumber')),
      'total_floors': int.tryParse(provider.text('totalFloorsCommercial')),
      'furnished': provider.furnishingType == 'Furnished' ||
          provider.furnishingType == 'Semi-Furnished',
      'cafeteria': provider.guardRoom,
    }, onConflict: 'property_id');
  }

  Future<void> _upsertLand(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    await _supabase
        .from('properties_land')
        .upsert(_landRow(propertyId, provider), onConflict: 'property_id');
  }

  /// UPSERT into `property_contact_details`. Used in edit mode.
  Future<void> _upsertContactDetails(
    String propertyId,
    PostPropertyProvider provider,
  ) async {
    final phone = provider.contactPhone.trim();
    final email = provider.contactEmail.trim();
    if (phone.isEmpty && email.isEmpty) return;

    await _supabase.from('property_contact_details').upsert({
      'property_id': propertyId,
      'contact_phone': phone.isNotEmpty ? phone : null,
      'contact_email': email.isNotEmpty ? email : null,
    }, onConflict: 'property_id');
  }

  /// Mirrors the React PropertyWizard approval check (lines 1431-1466).
  /// Throws a human-readable String if the user is blocked or not yet approved.
  Future<void> _checkApproval(String userId) async {
    final profile = await _supabase
        .from('profiles')
        .select('approval_status, is_blocked, user_role')
        .eq('user_id', userId)
        .single();

    if (profile['is_blocked'] == true) {
      throw 'Your account has been blocked. Please contact support.';
    }

    final bool isAdmin = profile['user_role'] == 'admin';
    if (profile['approval_status'] != 'approved' && !isAdmin) {
      throw 'Your account needs to be approved before publishing properties. '
          'Current status: ${profile['approval_status'] ?? 'pending'}';
    }
  }
}
