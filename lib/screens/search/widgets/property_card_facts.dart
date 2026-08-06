import '../../../models/property_model.dart';

/// The one-line spec summary both search cards show beneath the title.
///
/// Mirrors the redesign's own `facts` expression: bed/bath/area when the listing
/// has bedrooms, and area alone when it does not. That fallback matters — for
/// land and plots `PropertyModel.beds`/`baths` are 0 (the `properties_land`
/// sub-table has no bedroom concept), so a naive "0 Bed · 0 Bath" would render
/// on every plot.
///
/// Shared between the row and grid cards so the two can never drift.
String propertyFactsLine(PropertyModel property) {
  final String area = property.sqft > 0 ? '${property.sqft} sqft' : '';

  if (property.beds <= 0) return area;

  final parts = <String>[
    '${property.beds} Bed',
    '${property.baths} Bath',
    if (area.isNotEmpty) area,
  ];
  return parts.join(' · ');
}
