// models/smart_query_result.dart
//
// Structured filters extracted from a natural-language search query by the
// AI Search feature (see AiSearchService).
class SmartQueryResult {
  final String? city;
  final int? bhk;
  final String? category;
  final String? listingType;
  final double? budgetMin;
  final double? budgetMax;
  final String keywords;

  const SmartQueryResult({
    this.city,
    this.bhk,
    this.category,
    this.listingType,
    this.budgetMin,
    this.budgetMax,
    this.keywords = '',
  });

  factory SmartQueryResult.fromJson(Map<String, dynamic> json) {
    return SmartQueryResult(
      city: json['city'] as String?,
      bhk: (json['bhk'] as num?)?.toInt(),
      category: json['category'] as String?,
      listingType: json['listingType'] as String?,
      budgetMin: (json['budgetMin'] as num?)?.toDouble(),
      budgetMax: (json['budgetMax'] as num?)?.toDouble(),
      keywords: json['keywords']?.toString() ?? '',
    );
  }

  /// True if the AI extracted at least one structured filter (as opposed to
  /// a plain-text fallback with only `keywords` set).
  bool get hasStructuredFilters =>
      city != null ||
      bhk != null ||
      category != null ||
      listingType != null ||
      budgetMin != null ||
      budgetMax != null;
}
