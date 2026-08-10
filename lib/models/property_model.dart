// models/property_model.dart
import 'amenity_model.dart';

class PropertyModel {
  final String id;
  final String title;
  final String locality;
  final String city;
  final double price;
  final String priceDisplay;
  final String pricePerSqft;
  final int beds;
  final int baths;
  final int sqft;
  final int parking;
  final bool isVerified;
  final bool isFeatured;
  final bool isShortlisted;
  final int photoCount;
  final List<String> statusTags;
  final List<AmenityModel> amenities;
  final List<NearbyPlaceModel> nearbyPlaces;
  final String description;
  final String imageUrl;
  final List<String> imageUrls;
  final String builderName;
  final String? propertyType;
  final String? possessionStatus;
  final double? rating;
  final int? reviewCount;
  final bool isTrending;
  final String? floorPlanUrl;
  final String? videoUrl;
  final double? latitude;
  final double? longitude;

  // NEW: parsed straight off the `properties` row (already arrives over the
  // wire via select('*') today — this only adds client-side parsing for it).
  final String? category;
  // Sorting-only fields — never used for budget filtering. Budget filtering
  // stays a client-side comparison against the free-text `price` column,
  // mirroring the website exactly (see PropertyProvider.runSearch).
  final double? priceMin;
  final double? priceMax;
  final double? pricePerUnit;
  final String? currency;
  final bool? isNegotiable;
  final DateTime? availableFrom;
  final int? leaseDurationMonths;
  final int? interestCount;
  final int? likes;
  final String? approvalStatus;
  final String? userId;
  final String? residentialSubtype;
  final String? status;
  final int? views;
  final DateTime? createdAt;

  PropertyModel({
    required this.id,
    required this.title,
    required this.locality,
    required this.city,
    required this.price,
    required this.priceDisplay,
    required this.pricePerSqft,
    required this.beds,
    required this.baths,
    required this.sqft,
    required this.parking,
    required this.isVerified,
    required this.isFeatured,
    required this.isShortlisted,
    required this.photoCount,
    required this.statusTags,
    required this.amenities,
    required this.nearbyPlaces,
    required this.description,
    required this.imageUrl,
    // NEW: optional, defaults to empty so every existing call site
    // (direct constructions, fromJson payloads without the field, etc.)
    // keeps compiling untouched.
    this.imageUrls = const [],
    required this.builderName,
    this.propertyType,
    this.possessionStatus,
    this.rating,
    this.reviewCount,
    this.isTrending = false,
    this.floorPlanUrl,
    this.videoUrl,
    this.latitude,
    this.longitude,
    this.category,
    this.priceMin,
    this.priceMax,
    this.pricePerUnit,
    this.currency,
    this.isNegotiable,
    this.availableFrom,
    this.leaseDurationMonths,
    this.interestCount,
    this.likes,
    this.approvalStatus,
    this.userId,
    this.residentialSubtype,
    this.status,
    this.views,
    this.createdAt,
  });

  /// Parses a `properties.media_urls` (text[]) value into usable URLs.
  ///
  /// Null-safe and empty-string-filtering, because the column is nullable and
  /// older rows carry `''` entries. Exposed as a static so anything else
  /// reading a joined `properties` row parses it the same way this model does
  /// — [ReelModel] uses it for the reel card's cover image, in the same spirit
  /// as [parseAmenities].
  static List<String> parseMediaUrls(dynamic value) =>
      List<String>.from(value ?? const [])
          .where((url) => url.trim().isNotEmpty)
          .toList();

  /// NEW: the list the UI should actually iterate over.
  /// Falls back to the single [imageUrl] when [imageUrls] wasn't
  /// populated (older cached data, hand-built models, tests, etc.),
  /// so nothing downstream has to special-case an empty list itself.
  List<String> get resolvedImageUrls {
    if (imageUrls.isNotEmpty) return imageUrls;
    return imageUrl.isNotEmpty ? [imageUrl] : const [];
  }

  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    final String singleImage = json['imageUrl'] as String? ?? '';
    return PropertyModel(
      id: json['id'] as String,
      title: json['title'] as String,
      locality: json['locality'] as String,
      city: json['city'] as String,
      price: (json['price'] as num).toDouble(),
      priceDisplay: json['priceDisplay'] as String,
      pricePerSqft: json['pricePerSqft'] as String,
      beds: json['beds'] as int,
      baths: json['baths'] as int,
      sqft: json['sqft'] as int,
      parking: json['parking'] as int,
      isVerified: json['isVerified'] as bool,
      isFeatured: json['isFeatured'] as bool,
      isShortlisted: json['isShortlisted'] as bool,
      photoCount: json['photoCount'] as int,
      statusTags: (json['statusTags'] as List<dynamic>).cast<String>(),
      amenities: (json['amenities'] as List<dynamic>)
          .map((e) => AmenityModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      nearbyPlaces: (json['nearbyPlaces'] as List<dynamic>)
          .map((e) => NearbyPlaceModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      description: json['description'] as String,
      imageUrl: singleImage,
      // Accept an explicit 'imageUrls' array if present; otherwise fall
      // back to wrapping the single 'imageUrl' so old JSON blobs still work.
      imageUrls: (json['imageUrls'] as List<dynamic>?)?.cast<String>() ??
          (singleImage.isNotEmpty ? [singleImage] : const []),
      builderName: json['builderName'] as String,
      propertyType: json['propertyType'] as String?,
      possessionStatus: json['possessionStatus'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      reviewCount: json['reviewCount'] as int?,
      isTrending: json['isTrending'] as bool? ?? false,
      floorPlanUrl: json['floorPlanUrl'] as String?,
      videoUrl: json['videoUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: json['category'] as String?,
      priceMin: (json['priceMin'] as num?)?.toDouble(),
      priceMax: (json['priceMax'] as num?)?.toDouble(),
      pricePerUnit: (json['pricePerUnit'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      isNegotiable: json['isNegotiable'] as bool?,
      availableFrom: json['availableFrom'] != null
          ? DateTime.tryParse(json['availableFrom'].toString())
          : null,
      leaseDurationMonths: json['leaseDurationMonths'] as int?,
      interestCount: json['interestCount'] as int?,
      likes: json['likes'] as int?,
      approvalStatus: json['approvalStatus'] as String?,
      userId: json['userId'] as String?,
      residentialSubtype: json['residentialSubtype'] as String?,
    );
  }

  factory PropertyModel.fromSupabase(Map<String, dynamic> json) {
    // Extract residential/commercial/land data if available
    final residential = json['properties_residential'] as Map<String, dynamic>?;
    final commercial = json['properties_commercial'] as Map<String, dynamic>?;
    final land = json['properties_land'] as Map<String, dynamic>?;

    // Media lives in properties.media_urls (text[]). This is now the
    // single source of truth for both the gallery and the legacy
    // single-image field below.
    final mediaUrls = parseMediaUrls(json['media_urls']);

    // Extract beds, baths, parking from residential or commercial data
    int beds = 0;
    int baths = 0;
    int parking = 0;

    if (residential != null) {
      beds    = residential['bedrooms']       as int? ?? 0;
      baths   = residential['bathrooms']      as int? ?? 0;
      parking = residential['parking_spaces'] as int? ?? 0;
    } else if (commercial != null) {
      beds    = commercial['washrooms']       as int? ?? 0;
      baths   = commercial['washrooms']       as int? ?? 0;
      parking = commercial['parking_spaces']  as int? ?? 0;
    } else if (land != null) {
      // Land listings have no bedroom/bathroom/parking concept —
      // properties_land only tracks area_sqft/boundary_wall/water_source/
      // road_width_ft/soil_type/slope_percentage, none of which map to a
      // PropertyModel field yet. Left at 0 intentionally, not an oversight;
      // a fuller land-specific field set is a follow-on, not this phase.
    }

    // Extract metadata
    final metadata = json['metadata'] as Map<String, dynamic>? ?? {};

    final isFeatured = (json['views'] as int? ?? 0) >= 1;
    final isTrending = (json['views'] as int? ?? 0) >= 20;

    return PropertyModel(
      id:              json['id']?.toString() ?? '',
      title:           json['title'] ?? '',
      locality:        json['location'] ?? '',
      city:            metadata['city']?.toString() ?? json['city']?.toString() ?? '',
      price:           double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      priceDisplay:    formatIndianPrice(json['price']),
      pricePerSqft:    metadata['pricePerSqFt']?.toString() ?? '',
      beds:            beds,
      baths:           baths,
      sqft:            int.tryParse(json['area']?.toString() ?? '0') ?? 0,
      parking:         parking,
      // NEW: `properties` has no `is_verified` column at all — the key is
      // always absent, so this must not silently default to true.
      isVerified:      json['is_verified'] as bool? ?? false,
      isFeatured:      isFeatured,
      isShortlisted:   false,
      photoCount:      mediaUrls.length,
      statusTags:      List<String>.from(json['hashtags'] ?? []),
      amenities: parseAmenities(json['amenities']),
      nearbyPlaces:    [],
      description:     json['description'] ?? '',
      imageUrl:        mediaUrls.isNotEmpty ? mediaUrls.first : '',
      // NEW: full gallery, straight off the DB array.
      imageUrls:       mediaUrls,
      // NEW: `properties` has no `builder_name` column — do not fall back
      // to `category`, that mislabels every property's category as its
      // builder name.
      builderName:     json['builder_name']?.toString() ?? '',
      propertyType: json['property_type']?.toString(),
      possessionStatus: metadata['propertyCondition']?.toString() ??
          json['possession_status']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isTrending: isTrending,
      category: json['category']?.toString(),
      priceMin: (json['price_min'] as num?)?.toDouble(),
      priceMax: (json['price_max'] as num?)?.toDouble(),
      pricePerUnit: (json['price_per_unit'] as num?)?.toDouble(),
      currency: json['currency']?.toString(),
      isNegotiable: json['is_negotiable'] as bool?,
      availableFrom: json['available_from'] != null
          ? DateTime.tryParse(json['available_from'].toString())
          : null,
      leaseDurationMonths: json['lease_duration_months'] as int?,
      interestCount: json['interest_count'] as int?,
      likes: json['likes'] as int?,
      approvalStatus: json['approval_status']?.toString(),
      userId: json['user_id']?.toString(),
      residentialSubtype: json['residential_subtype']?.toString(),
      status: json['status']?.toString(),
      views: json['views'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  static String formatIndianPrice(dynamic value) {
    final price = double.tryParse(value.toString()) ?? 0;

    if (price >= 10000000) {
      return '₹${(price / 10000000).toStringAsFixed(1)} Cr';
    }

    if (price >= 100000) {
      return '₹${(price / 100000).toStringAsFixed(1)} L';
    }

    return '₹${price.toInt()}';
  }

  static List<AmenityModel> parseAmenities(dynamic amenities) {
    if (amenities == null) return [];

    final List<String> items = List<String>.from(amenities);

    const Map<String, Map<String, String>> amenityData = {
      "Swimming Pool": {"icon": "pool", "color": "#2196F3"},
      "Gymnasium": {"icon": "fitness_center", "color": "#F44336"},
      "Clubhouse": {"icon": "home", "color": "#9C27B0"},
      "Children Play Area": {"icon": "child_care", "color": "#FF9800"},
      "Jogging Track": {"icon": "directions_run", "color": "#4CAF50"},
      "Sports Complex": {"icon": "sports_soccer", "color": "#009688"},
      "Shopping Complex": {"icon": "shopping_bag", "color": "#795548"},
      "School": {"icon": "school", "color": "#3F51B5"},
      "Community Hall": {"icon": "groups", "color": "#607D8B"},
      "Security": {"icon": "security", "color": "#4CAF50"},
      "24/7 Power Backup": {"icon": "bolt", "color": "#FFC107"},
      "Elevator": {"icon": "elevator", "color": "#9E9E9E"},
      "Parking": {"icon": "local_parking", "color": "#2196F3"},
    };

    return items.map((name) {
      final data = amenityData[name];

      return AmenityModel(
        id: name,
        name: name,
        icon: data?["icon"] ?? "check_circle",
        color: data?["color"] ?? "#3F51B5",
      );
    }).toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'locality': locality,
      'city': city,
      'price': price,
      'priceDisplay': priceDisplay,
      'pricePerSqft': pricePerSqft,
      'beds': beds,
      'baths': baths,
      'sqft': sqft,
      'parking': parking,
      'isVerified': isVerified,
      'isFeatured': isFeatured,
      'isShortlisted': isShortlisted,
      'photoCount': photoCount,
      'statusTags': statusTags,
      'amenities': amenities.map((e) => e.toJson()).toList(),
      'nearbyPlaces': nearbyPlaces.map((e) => e.toJson()).toList(),
      'description': description,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'builderName': builderName,
      'propertyType': propertyType,
      'possessionStatus': possessionStatus,
      'rating': rating,
      'reviewCount': reviewCount,
      'isTrending': isTrending,
      'floorPlanUrl': floorPlanUrl,
      'videoUrl': videoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'priceMin': priceMin,
      'priceMax': priceMax,
      'pricePerUnit': pricePerUnit,
      'currency': currency,
      'isNegotiable': isNegotiable,
      'availableFrom': availableFrom?.toIso8601String(),
      'leaseDurationMonths': leaseDurationMonths,
      'interestCount': interestCount,
      'likes': likes,
      'approvalStatus': approvalStatus,
      'userId': userId,
      'residentialSubtype': residentialSubtype,
      'status': status,
      'views': views,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  PropertyModel copyWith({
    String? id,
    String? title,
    String? locality,
    String? city,
    double? price,
    String? priceDisplay,
    String? pricePerSqft,
    int? beds,
    int? baths,
    int? sqft,
    int? parking,
    bool? isVerified,
    bool? isFeatured,
    bool? isShortlisted,
    int? photoCount,
    List<String>? statusTags,
    List<AmenityModel>? amenities,
    List<NearbyPlaceModel>? nearbyPlaces,
    String? description,
    String? imageUrl,
    List<String>? imageUrls,
    String? builderName,
    String? propertyType,
    String? possessionStatus,
    double? rating,
    int? reviewCount,
    bool? isTrending,
    String? floorPlanUrl,
    String? videoUrl,
    double? latitude,
    double? longitude,
    String? category,
    double? priceMin,
    double? priceMax,
    double? pricePerUnit,
    String? currency,
    bool? isNegotiable,
    DateTime? availableFrom,
    int? leaseDurationMonths,
    int? interestCount,
    int? likes,
    String? approvalStatus,
    String? userId,
    String? residentialSubtype,
    String? status,
    int? views,
    DateTime? createdAt,
  }) {
    return PropertyModel(
      id: id ?? this.id,
      title: title ?? this.title,
      locality: locality ?? this.locality,
      city: city ?? this.city,
      price: price ?? this.price,
      priceDisplay: priceDisplay ?? this.priceDisplay,
      pricePerSqft: pricePerSqft ?? this.pricePerSqft,
      beds: beds ?? this.beds,
      baths: baths ?? this.baths,
      sqft: sqft ?? this.sqft,
      parking: parking ?? this.parking,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      isShortlisted: isShortlisted ?? this.isShortlisted,
      photoCount: photoCount ?? this.photoCount,
      statusTags: statusTags ?? this.statusTags,
      amenities: amenities ?? this.amenities,
      nearbyPlaces: nearbyPlaces ?? this.nearbyPlaces,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      builderName: builderName ?? this.builderName,
      propertyType: propertyType ?? this.propertyType,
      possessionStatus: possessionStatus ?? this.possessionStatus,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isTrending: isTrending ?? this.isTrending,
      floorPlanUrl: floorPlanUrl ?? this.floorPlanUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      currency: currency ?? this.currency,
      isNegotiable: isNegotiable ?? this.isNegotiable,
      availableFrom: availableFrom ?? this.availableFrom,
      leaseDurationMonths: leaseDurationMonths ?? this.leaseDurationMonths,
      interestCount: interestCount ?? this.interestCount,
      likes: likes ?? this.likes,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      userId: userId ?? this.userId,
      residentialSubtype: residentialSubtype ?? this.residentialSubtype,
      status: status ?? this.status,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get location => '$locality, $city';
}
