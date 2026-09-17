import '../../../models/property_model.dart';

/// The one-line spec summary both search cards show beneath the title.
///
/// Mirrors the portal's own `property.category === 'residential'` branch in
/// `PropertyCard.tsx`: bed/bath/area only for residential, area alone for
/// every other category. Land has no bedroom concept at all (the
/// `properties_land` sub-table doesn't carry one). Commercial does carry a
/// number here, but `PropertyModel.beds`/`baths` are repurposed for it to
/// hold the washrooms count (see property_model.dart's `fromSupabase`), so
/// showing it labelled "Bed"/"Bath" is always wrong — the portal shows a
/// separately-labelled "Washrooms" badge for commercial instead.
/// Category-gated rather than zero-gated, so a residential listing that
/// genuinely has 0 saved bedrooms still shows it.
///
/// Shared between the row and grid cards so the two can never drift.
String propertyFactsLine(PropertyModel property) {
  final String area = property.sqft > 0 ? '${property.sqft} sqft' : '';

  if (property.category != 'residential') return area;

  final parts = <String>[
    '${property.beds} Bed',
    '${property.baths} Bath',
    if (area.isNotEmpty) area,
  ];
  return parts.join(' · ');
}

/// "2 days ago" / "Yesterday" / "Just now" — the same relative-age ladder
/// `AppNotification.relativeTime` already uses (app_notification.dart),
/// reproduced here rather than imported since that model lives in an
/// unrelated feature (notifications) and this only needs the formatting.
String propertyPostedAgo(DateTime? createdAt) {
  if (createdAt == null) return '';
  final delta = DateTime.now().difference(createdAt);
  if (delta.isNegative || delta.inMinutes < 1) return 'Just now';
  if (delta.inMinutes < 60) return '${delta.inMinutes} min ago';
  if (delta.inHours < 24) {
    return '${delta.inHours} hr${delta.inHours == 1 ? '' : 's'} ago';
  }
  if (delta.inDays == 1) return 'Yesterday';
  if (delta.inDays < 30) return '${delta.inDays} days ago';
  final months = (delta.inDays / 30).floor();
  if (months < 12) return '$months mo${months == 1 ? '' : 's'} ago';
  final years = (delta.inDays / 365).floor();
  return '$years yr${years == 1 ? '' : 's'} ago';
}
