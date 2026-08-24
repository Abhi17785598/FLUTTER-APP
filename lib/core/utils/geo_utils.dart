// core/utils/geo_utils.dart
//
// Haversine distance helper for the "near me" search flow only. This is a
// deliberate, separate copy from NearbyPlacesService's own private haversine
// (used for Google Places nearby-amenities) — that file already works
// correctly and is unrelated to property search, so it's left untouched.
import 'dart:math';

/// Great-circle distance between two lat/lng points, in kilometers.
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) *
          cos(_degToRad(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (pi / 180.0);
