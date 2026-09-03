// widgets/location_picker_map.dart
//
// Mirrors `GoogleLocationPicker.tsx` with `hideSearch={true}` — the mode
// every registration wizard actually uses (BuilderRegistration.tsx:1617,
// BrokerRegistration.tsx and InfluencerRegistration.tsx pass the same prop).
// Tapping the map drops a pin and reverse-geocodes it via
// [GeocodingService], exactly like the portal's `performGeocode` +
// `updateMarker`. The search bar the portal shows when `hideSearch` is false
// is not built here, since no caller needs it.
import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/geocoding_service.dart';

class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    this.initialLat,
    this.initialLng,
    required this.onLocationSelected,
  });

  final double? initialLat;
  final double? initialLng;

  /// Fires on every tap/drag, even when reverse geocoding fails — [address]
  /// is null in that case, matching the portal's `onLocationSelect(lat, lng)`
  /// fallback call when `performGeocode` catches an error.
  final void Function(double lat, double lng, GeocodedAddress? address)
  onLocationSelected;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final _geocodingService = GeocodingService();
  GoogleMapController? _controller;
  LatLng? _selected;
  bool _geocoding = false;

  // GoogleLocationPicker.tsx:134 — Delhi, the same fallback centre when no
  // initial coordinates are supplied.
  static const LatLng _defaultCenter = LatLng(28.7041, 77.1025);

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _selected = LatLng(widget.initialLat!, widget.initialLng!);
    }
  }

  Future<void> _handleTap(LatLng point) async {
    setState(() {
      _selected = point;
      _geocoding = true;
    });

    final address = await _geocodingService.reverseGeocode(
      point.latitude,
      point.longitude,
    );

    if (!mounted) return;
    setState(() => _geocoding = false);
    widget.onLocationSelected(point.latitude, point.longitude, address);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final center = _selected ?? _defaultCenter;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 220,
        child: Stack(
          children: [
            GoogleMap(
              // Both listing wizards render this inside a
              // SingleChildScrollView, whose own vertical PanGestureRecognizer
              // otherwise wins the gesture arena against the map's — a drag
              // that should pan the map instead scrolls the page, and pinch
              // zoom doesn't register either. EagerGestureRecognizer claims
              // the gesture for the map immediately so panning/zooming work
              // as expected; tapping to drop a pin was never affected by this
              // (arena resolution for pans/scale, not taps).
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: _selected != null ? 15 : 6,
              ),
              onMapCreated: (controller) => _controller = controller,
              onTap: _handleTap,
              markers: _selected == null
                  ? const {}
                  : {
                      Marker(
                        markerId: const MarkerId('picked-location'),
                        position: _selected!,
                        draggable: true,
                        onDragEnd: _handleTap,
                      ),
                    },
              zoomControlsEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.surface.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_geocoding)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(Icons.location_on, size: 14, color: scheme.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _geocoding
                            ? 'Locating...'
                            : 'Tap on the map to select location',
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
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
}
