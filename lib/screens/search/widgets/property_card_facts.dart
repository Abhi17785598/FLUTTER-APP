import '../../../models/property_model.dart';

/// The one-line spec summary both search cards show beneath the title.
///
/// Mirrors the portal's own `property.category === 'land'` branch in
/// `PropertyCard.tsx`: bed/bath/area for categories that have bedrooms, area
/// alone for land/plot, which has no bedroom concept (the `properties_land`
/// sub-table doesn't carry one, so `PropertyModel.beds`/`baths` are always 0
/// for that category). Category-gated rather than zero-gated, so a
/// residential listing that genuinely has 0 saved bedrooms still shows it.
///
/// Shared between the row and grid cards so the two can never drift.
String propertyFactsLine(PropertyModel property) {
  final String area = property.sqft > 0 ? '${property.sqft} sqft' : '';

  if (property.category == 'land') return area;

  final parts = <String>[
    '${property.beds} Bed',
    '${property.baths} Bath',
    if (area.isNotEmpty) area,
  ];
  return parts.join(' · ');
}
