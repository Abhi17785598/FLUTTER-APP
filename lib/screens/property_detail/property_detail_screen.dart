// screens/property_detail/property_detail_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/property_provider.dart';
import '../../providers/shortlist_provider.dart';
import '../../widgets/verified_badge.dart';
import '../../widgets/amenity_icon_tile.dart';
import '../../widgets/nearby_place_row.dart';
import '../../widgets/property_map_widget.dart';
import '../../widgets/property_card_horizontal.dart';
import '../../widgets/emi_calculator_widget.dart';
import '../gallery/gallery_viewer_screen.dart';
import '../../services/nearby_places_service.dart';
import '../../services/property_service.dart';
import '../../services/session_service.dart';
import '../../models/nearby_place.dart';
import '../../models/property_model.dart';
import '../../models/property_detail_bundle.dart';

// =============================================================================
// PropertyDetailScreen
// Displays full details of a single property: hero image carousel, highlights,
// property information grid, expandable description, amenities, location
// map, nearby places, related properties, an inline EMI calculator (for
// sell-type properties), and action buttons for scheduling visits/enquiries.
//
// Fetches its property via a dedicated PropertyService.getPropertyDetail
// call (the website's exact 3-query shape) rather than an in-memory lookup,
// so deep-linked or paginated-away properties still resolve correctly. Also
// tracks a view (track_property_view RPC) after a 3s watch-time, matching
// the website's own view-tracking behavior.
// =============================================================================
class PropertyDetailScreen extends StatefulWidget {
  final String propertyId;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
  });

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isDescriptionExpanded = false;

  late final AnimationController _entranceController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Drives the hero image carousel and its counter chip.
  late final PageController _imagePageController;
  int _currentImageIndex = 0;

  // Live "Nearby Places" state, fetched from Places API (New) via
  // NearbyPlacesService — unrelated to Supabase, left exactly as-is.
  final NearbyPlacesService _nearbyPlacesService = NearbyPlacesService();
  List<NearbyPlace> _nearbyPlaces = <NearbyPlace>[];
  bool _isLoadingNearbyPlaces = true;

  // Dedicated single-property fetch (properties/profiles/subtype tables),
  // matching PropertyDetails.tsx's exact 3-query shape.
  final PropertyService _propertyService = PropertyService();
  PropertyModel? _property;
  bool _isLoadingProperty = true;
  String? _loadError;

  List<PropertyModel> _relatedProperties = <PropertyModel>[];
  bool _isLoadingRelated = true;

  Timer? _viewTrackingTimer;

  @override
  void initState() {
    super.initState();
    _imagePageController = PageController();

    // Subtle one-shot entrance animation for the content card beneath the
    // hero image. Kept intentionally light per the "no heavy animations" rule.
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));
    _entranceController.forward();

    _loadProperty();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _imagePageController.dispose();
    _viewTrackingTimer?.cancel();
    super.dispose();
  }

  /// Instant-paints from whatever's already loaded in memory (if anything),
  /// then always resolves the authoritative dedicated fetch in the
  /// background and swaps it in — this is what lets a deep-linked or
  /// paginated-away property still load correctly, unlike the old pure
  /// in-memory `getPropertyById` lookup.
  Future<void> _loadProperty() async {
    final PropertyProvider propertyProvider =
        Provider.of<PropertyProvider>(context, listen: false);
    final cached = propertyProvider.findCached(widget.propertyId);
    if (cached != null && mounted) {
      setState(() => _property = cached);
    }

    try {
      final PropertyDetailBundle bundle =
          await _propertyService.getPropertyDetail(widget.propertyId);
      if (!mounted) return;
      setState(() {
        _property = bundle.property;
        _isLoadingProperty = false;
      });
      _loadNearbyPlaces();
      _loadRelatedProperties();
      _startViewTracking();
    } catch (e) {
      debugPrint('[PropertyDetail] getPropertyDetail failed: $e');
      if (!mounted) return;
      setState(() {
        _isLoadingProperty = false;
        if (_property == null) {
          _loadError = 'Property not found';
        }
      });
    }
  }

  /// Loads real nearby places for this property's coordinates. Never throws
  /// into the widget tree — any failure just leaves the list empty so the
  /// UI shows the "No nearby places found" state instead of crashing.
  Future<void> _loadNearbyPlaces() async {
    final property = _property;
    if (property == null) {
      if (mounted) setState(() => _isLoadingNearbyPlaces = false);
      return;
    }

    try {
      final List<NearbyPlace> results =
          await _nearbyPlacesService.fetchNearbyPlaces(
        latitude: property.latitude,
        longitude: property.longitude,
      );
      if (!mounted) return;
      setState(() {
        _nearbyPlaces = results;
        _isLoadingNearbyPlaces = false;
      });
    } on NearbyPlacesException catch (e) {
      debugPrint('[PropertyDetail] Nearby places unavailable: $e');
      if (!mounted) return;
      setState(() {
        _nearbyPlaces = <NearbyPlace>[];
        _isLoadingNearbyPlaces = false;
      });
    } catch (e) {
      debugPrint('[PropertyDetail] Nearby places fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _nearbyPlaces = <NearbyPlace>[];
        _isLoadingNearbyPlaces = false;
      });
    }
  }

  /// Ports RelatedPropertyCards.tsx: same property_type + category, similar
  /// city, approved, excluding self.
  Future<void> _loadRelatedProperties() async {
    final property = _property;
    if (property == null || property.propertyType == null || property.category == null) {
      if (mounted) setState(() => _isLoadingRelated = false);
      return;
    }

    try {
      final related = await _propertyService.getRelatedProperties(
        propertyId: property.id,
        propertyType: property.propertyType!,
        category: property.category!,
        location: property.location,
      );
      if (!mounted) return;
      setState(() {
        _relatedProperties = related;
        _isLoadingRelated = false;
      });
    } catch (e) {
      debugPrint('[PropertyDetail] Related properties fetch failed: $e');
      if (!mounted) return;
      setState(() {
        _relatedProperties = <PropertyModel>[];
        _isLoadingRelated = false;
      });
    }
  }

  /// Tracks a view via the track_property_view RPC after a 3s watch-time —
  /// matches the website's useViewTracking hook exactly (a quick bounce
  /// before the timer fires doesn't count; the RPC itself enforces a
  /// 30-minute per-user/session dedupe window server-side).
  void _startViewTracking() {
    final property = _property;
    if (property == null) return;

    _viewTrackingTimer?.cancel();
    _viewTrackingTimer = Timer(const Duration(seconds: 3), () async {
      try {
        final sessionId = await SessionService.getSessionId();
        if (!mounted) return;
        await _propertyService.trackPropertyView(
          propertyId: property.id,
          viewerUserId: Supabase.instance.client.auth.currentUser?.id,
          viewerSessionId: sessionId,
          viewDurationSeconds: 3,
          viewPercentage: 100,
        );
      } catch (e) {
        debugPrint('[PropertyDetail] View tracking failed: $e');
      }
    });
  }

  /// Resolves the full gallery for a property, always falling back
  /// to the single legacy `imageUrl` when `imageUrls` is empty, so older
  /// cached/mocked PropertyModel instances keep working unchanged.
  List<String> _resolveImages(dynamic property) {
    final List<String> urls =
        (property.resolvedImageUrls as List<String>?) ?? const [];
    if (urls.isNotEmpty) return urls;
    final String single = property.imageUrl as String? ?? '';
    return single.isNotEmpty ? [single] : const [];
  }

  @override
  Widget build(BuildContext context) {
    if (_property == null) {
      if (_isLoadingProperty) {
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }
      return Scaffold(
        body: Center(
          child: Text(_loadError ?? 'Property not found'),
        ),
      );
    }

    final property = _property!;
    final PropertyProvider propertyProvider =
        Provider.of<PropertyProvider>(context);
    final ShortlistProvider shortlistProvider =
        Provider.of<ShortlistProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // -----------------------------------------------------------------
          // Hero SliverAppBar with image carousel, back button, actions, chips
          // -----------------------------------------------------------------
          SliverAppBar(
            expandedHeight: AppConstants.propertyDetailHeroHeight,
            pinned: true,
            // Disable Flutter's automatic back button to avoid double arrows
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  _buildHeroImageCarousel(context, property),
                  _buildGradientOverlay(),
                  _buildTopActions(context, property, shortlistProvider),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: _buildPhotoCountChip(property),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: _buildVirtualTourChip(context, property),
                  ),
                ],
              ),
            ),
          ),

          // -----------------------------------------------------------------
          // Scrollable content card beneath the hero image
          // -----------------------------------------------------------------
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.textHint,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (property.isVerified)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: VerifiedBadge(),
                              ),

                            // Title + Price row
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    property.title,
                                    style: AppTextStyles.heading2
                                        .copyWith(fontSize: 18),
                                  ),
                                ),
                                Text(
                                  property.priceDisplay,
                                  style: AppTextStyles.price,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Location row
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    property.location,
                                    style: AppTextStyles.caption,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              property.pricePerSqft,
                              style: AppTextStyles.caption,
                            ),

                            // Property Highlights
                            _buildHighlightsRow(property),

                            const SizedBox(height: 20),

                            // Property Information grid
                            _buildPropertyInformationGrid(context, property),

                            const SizedBox(height: 20),

                            // Expandable description
                            _buildExpandableDescription(property),

                            const SizedBox(height: 20),

                            // Property Location map card
                            _buildLocationSection(context, property),

                            const SizedBox(height: 20),

                            // Amenities
                            _buildAmenitiesSection(property),

                            const SizedBox(height: 20),

                            // Nearby places
                            _buildNearbyPlacesSection(property),

                            // EMI calculator — embedded inline for sell-type
                            // properties only, self-contained/no pre-filled
                            // amount, matching the website exactly.
                            if (property.propertyType == 'sell') ...[
                              const SizedBox(height: 20),
                              Text('EMI Calculator',
                                  style: AppTextStyles.heading3),
                              const SizedBox(height: 12),
                              const EmiCalculatorWidget(),
                            ],

                            const SizedBox(height: 20),

                            // Related properties
                            _buildRelatedPropertiesSection(context),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar:
          _buildBottomBar(context, property, propertyProvider),
    );
  }

  // ===========================================================================
  // HERO IMAGE CAROUSEL
  // Swipeable PageView over resolvedImageUrls. Each page carries its own
  // Hero tag ('property_hero_<id>_<index>') so tapping a page flies it into
  // the matching page of GalleryViewerScreen.
  // ===========================================================================

  Widget _buildHeroImageCarousel(BuildContext context, dynamic property) {
    final images = _resolveImages(property);

    if (images.isEmpty) {
      return Container(
        color: AppColors.textHint.withOpacity(0.1),
        child: const Center(
          child: Icon(Icons.broken_image,
              color: AppColors.textSecondary, size: 48),
        ),
      );
    }

    return PageView.builder(
      controller: _imagePageController,
      itemCount: images.length,
      onPageChanged: (index) {
        setState(() => _currentImageIndex = index);
      },
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _openGallery(context, property, index),
          child: Hero(
            tag: 'property_hero_${property.id}_$index',
            child: CachedNetworkImage(
              imageUrl: images[index],
              fit: BoxFit.cover,
              placeholder: (BuildContext ctx, String url) => Container(
                color: AppColors.textHint.withOpacity(0.1),
              ),
              errorWidget: (BuildContext ctx, String url, Object error) {
                debugPrint(
                    '[PropertyDetail] Image load error for ${property.id} '
                    '(index $index): $error');
                return Container(
                  color: AppColors.textHint.withOpacity(0.1),
                  child: const Center(
                    child: Icon(Icons.broken_image,
                        color: AppColors.textSecondary, size: 48),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientOverlay() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.3),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TOP ACTIONS (back · share · favourite)
  // Favourite icon is keyed off ShortlistProvider (id-based) rather than
  // PropertyProvider.toggleShortlist's in-memory-list-dependent mechanism,
  // since a deep-linked property may not be in that list.
  // ===========================================================================

  Widget _buildTopActions(
    BuildContext context,
    dynamic property,
    ShortlistProvider shortlistProvider,
  ) {
    final bool isShortlisted = shortlistProvider.isShortlisted(property.id as String);

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildCircleButton(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              onPressed: () {
                try {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  debugPrint('[PropertyDetail] Back navigation error: $e');
                }
              },
              padding: EdgeInsets.zero,
            ),
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(8),
          ),
          Row(
            children: [
              _buildCircleButton(
                backgroundColor: Colors.black.withOpacity(0.5),
                child: const Icon(
                  Icons.share,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => shortlistProvider.toggleShortlist(property.id as String),
                child: _buildCircleButton(
                  backgroundColor: Colors.white,
                  child: Icon(
                    isShortlisted ? Icons.favorite : Icons.favorite_border,
                    color: isShortlisted ? Colors.red : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required Color backgroundColor,
    required Widget child,
    BoxShape shape = BoxShape.circle,
    BorderRadius? borderRadius,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
      ),
      child: child,
    );
  }

  // ===========================================================================
  // BOTTOM CHIPS (photo counter · virtual tour)
  // ===========================================================================

  /// Shows the live "current/total" position in the carousel, doubling as
  /// the image counter.
  Widget _buildPhotoCountChip(dynamic property) {
    final images = _resolveImages(property);
    final total = images.length;
    if (total == 0) return const SizedBox.shrink();

    final current = (_currentImageIndex + 1).clamp(1, total);

    return _buildOverlayChip(
      children: [
        const Icon(Icons.camera_alt, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        Text(
          '$current/$total',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildVirtualTourChip(BuildContext context, dynamic property) {
    return GestureDetector(
      onTap: () => _handleVirtualTour(context, property),
      child: _buildOverlayChip(
        children: const [
          Icon(Icons.play_circle_outline, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text(
            'Virtual Tour',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayChip({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(children: children),
    );
  }

  // ===========================================================================
  // NAVIGATION HELPERS
  // ===========================================================================

  /// Pushes GalleryViewerScreen directly (instead of a named route) so it
  /// always receives the full multi-image list, the tapped index, and the
  /// Hero tag prefix needed for the fly-in animation.
  void _openGallery(BuildContext context, dynamic property, int initialIndex) {
    final images = _resolveImages(property);
    if (images.isEmpty) return;

    debugPrint('[PropertyDetail] Opening gallery for property '
        '${property.id} at index $initialIndex of ${images.length}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryViewerScreen(
          images: images,
          initialIndex: initialIndex,
          heroTagPrefix: 'property_hero_${property.id}',
        ),
      ),
    );
  }

  void _handleVirtualTour(BuildContext context, dynamic property) {
    debugPrint('[PropertyDetail] Virtual Tour tapped for property: '
        '${property.id}');

    final String? tourUrl = property.videoUrl;
    if (tourUrl != null && tourUrl.isNotEmpty) {
      try {
        Navigator.pushNamed(
          context,
          '/virtual-tour',
          arguments: {'url': tourUrl, 'title': property.title},
        );
      } catch (e) {
        debugPrint('[PropertyDetail] Virtual Tour navigation error: $e');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Virtual Tour Coming Soon'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // ===========================================================================
  // PROPERTY HIGHLIGHTS
  // ===========================================================================

  Widget _buildHighlightsRow(dynamic property) {
    final List<_Highlight> highlights = [];

    if (property.isVerified == true) {
      highlights.add(_Highlight('Verified', Icons.verified,
          AppColors.verifiedBadge));
    }
    if (property.isTrending == true) {
      highlights.add(_Highlight('Trending', Icons.trending_up,
          AppColors.warning));
    }
    final String? possession = property.possessionStatus as String?;
    if (possession != null && possession.toLowerCase().contains('ready')) {
      highlights.add(_Highlight('Ready To Move', Icons.home_work,
          AppColors.success));
    }
    if (property.isFeatured == true) {
      highlights.add(_Highlight('Featured', Icons.star, AppColors.primary));
    }

    if (highlights.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: highlights
            .map((h) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: h.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: h.color.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(h.icon, size: 14, color: h.color),
                      const SizedBox(width: 6),
                      Text(
                        h.label,
                        style: AppTextStyles.chip.copyWith(
                          color: h.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  // ===========================================================================
  // PROPERTY INFORMATION GRID
  // ===========================================================================

  Widget _buildPropertyInformationGrid(BuildContext context, dynamic property) {
    final double width = MediaQuery.of(context).size.width;
    final int crossAxisCount = width >= 900
        ? 4
        : width >= 600
            ? 3
            : 2;

    final List<_InfoItem> items = [
      _InfoItem(Icons.bed, 'Bedrooms', '${property.beds}'),
      _InfoItem(Icons.bathtub, 'Bathrooms', '${property.baths}'),
      _InfoItem(Icons.square_foot, 'Area', '${property.sqft} sqft'),
      _InfoItem(Icons.directions_car, 'Parking', '${property.parking}'),
    ];

    final String? propertyType = property.propertyType as String?;
    if (propertyType != null && propertyType.isNotEmpty) {
      items.add(_InfoItem(Icons.apartment, 'Property Type', propertyType));
    }
    final String? possession = property.possessionStatus as String?;
    if (possession != null && possession.isNotEmpty) {
      items.add(_InfoItem(Icons.event_available, 'Possession', possession));
    }
    final String pricePerSqft = property.pricePerSqft as String;
    if (pricePerSqft.isNotEmpty) {
      items.add(_InfoItem(Icons.currency_rupee, 'Price/SqFt', pricePerSqft));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Property Information', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
          ),
          itemBuilder: (BuildContext context, int index) {
            final item = items[index];
            return _buildInfoTile(item);
          },
        ),
      ],
    );
  }

  Widget _buildInfoTile(_InfoItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.textHint.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.value,
                  style: AppTextStyles.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.label,
                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EXPANDABLE DESCRIPTION ("About Property")
  // ===========================================================================

  Widget _buildExpandableDescription(dynamic property) {
    final String description = property.description as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textHint.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About Property',
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: Text(
              description,
              style: AppTextStyles.caption.copyWith(fontSize: 13),
              maxLines: _isDescriptionExpanded ? null : 3,
              overflow: _isDescriptionExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {
              setState(() {
                _isDescriptionExpanded = !_isDescriptionExpanded;
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _isDescriptionExpanded ? 'Read less ‹' : 'Read more ›',
                key: ValueKey<bool>(_isDescriptionExpanded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PROPERTY LOCATION (map card)
  // ===========================================================================

  Widget _buildLocationSection(BuildContext context, dynamic property) {
    final double? latitude = property.latitude as double?;
    final double? longitude = property.longitude as double?;

    if (latitude == null || longitude == null) {
      return const SizedBox.shrink();
    }

    final String builderName = property.builderName as String;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Property Location', style: AppTextStyles.heading3),
            ],
          ),
          const SizedBox(height: 4),
          if (builderName.isNotEmpty)
            Text(
              builderName,
              style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
            ),
          Text(
            property.location as String,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          PropertyMapWidget(
            latitude: latitude,
            longitude: longitude,
            title: property.title as String,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _openInGoogleMaps(context, latitude, longitude),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map_outlined, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Open in Google Maps',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _getDirections(context, latitude, longitude),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions, size: 16),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Get Directions',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openInGoogleMaps(
      BuildContext context, double latitude, double longitude) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await _launchMapsUri(context, uri, 'Could not open Google Maps');
  }

  Future<void> _getDirections(
      BuildContext context, double latitude, double longitude) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    await _launchMapsUri(context, uri, 'Could not start directions');
  }

  Future<void> _launchMapsUri(
      BuildContext context, Uri uri, String failureMessage) async {
    try {
      final bool launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    } catch (e) {
      debugPrint('[PropertyDetail] Maps launch error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
    }
  }

  // ===========================================================================
  // AMENITIES SECTION
  // ===========================================================================

  Widget _buildAmenitiesSection(dynamic property) {
    final List amenities = property.amenities as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Amenities', style: AppTextStyles.heading3),
            TextButton(
              onPressed: () {},
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemCount: amenities.length,
            itemBuilder: (BuildContext context, int index) {
              final amenity = amenities[index];
              final Color color = Color(
                int.parse(
                  (amenity.color as String).replaceAll('#', '0xFF'),
                ),
              );
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: Container(
                  width: 84,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.textHint.withOpacity(0.2),
                    ),
                  ),
                  child: AmenityIconTile(
                    icon: _getIconFromString(amenity.icon as String),
                    label: amenity.name as String,
                    color: color,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // NEARBY PLACES SECTION
  // ===========================================================================

  Widget _buildNearbyPlacesSection(dynamic property) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Nearby Places', style: AppTextStyles.heading3),
            TextButton(
              onPressed: () {},
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildNearbyPlacesContent(),
      ],
    );
  }

  /// Renders the loading / empty / loaded states for the live Nearby Places
  /// list fetched via NearbyPlacesService.
  Widget _buildNearbyPlacesContent() {
    if (_isLoadingNearbyPlaces) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_nearbyPlaces.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No nearby places found',
            style: AppTextStyles.caption,
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: _nearbyPlaces.length,
      itemBuilder: (BuildContext context, int index) {
        final NearbyPlace place = _nearbyPlaces[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.textHint.withOpacity(0.2),
            ),
          ),
          child: NearbyPlaceRow(
            name: place.name,
            type: NearbyPlacesService.labelForType(place.type),
            distance: place.distance,
            duration: place.duration,
            icon: NearbyPlacesService.iconForType(place.type),
            color: NearbyPlacesService.colorForType(place.type),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // RELATED PROPERTIES SECTION
  // ===========================================================================

  Widget _buildRelatedPropertiesSection(BuildContext context) {
    if (_isLoadingRelated) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (_relatedProperties.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Related Properties', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedProperties.length,
            itemBuilder: (context, index) {
              final related = _relatedProperties[index];
              return PropertyCardHorizontal(
                property: related,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    AppConstants.propertyDetailScreen,
                    arguments: {'propertyId': related.id},
                  );
                },
                onFavoriteToggle: () {
                  Provider.of<ShortlistProvider>(context, listen: false)
                      .toggleShortlist(related.id);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // BOTTOM ACTION BAR — unchanged
  // ===========================================================================

  Widget _buildBottomBar(
    BuildContext context,
    dynamic property,
    PropertyProvider propertyProvider,
  ) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.textHint, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () =>
                  _showScheduleBottomSheet(context, property, propertyProvider),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 18),
                  SizedBox(width: 8),
                  Text('Schedule Visit'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: () =>
                  _showEnquiryBottomSheet(context, property, propertyProvider),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.phone, size: 18),
                  SizedBox(width: 8),
                  Text('Enquire Now'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SCHEDULE VISIT BOTTOM SHEET — unchanged
  // ===========================================================================

  void _showScheduleBottomSheet(
    BuildContext context,
    dynamic property,
    PropertyProvider propertyProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        String selectedDate = 'Tomorrow';
        String selectedTime = '10:00 AM';

        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            final List<String> dates = [
              'Tomorrow',
              'May 21, 2026',
              'May 22, 2026',
              'May 23, 2026',
            ];
            final List<String> times = [
              '10:00 AM',
              '12:00 PM',
              '02:00 PM',
              '04:00 PM',
              '06:00 PM',
            ];

            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textHint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Schedule a Visit', style: AppTextStyles.heading2),
                  const SizedBox(height: 4),
                  Text(
                    property.title as String,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Date',
                    style: AppTextStyles.heading3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: dates.length,
                      itemBuilder: (BuildContext _, int index) {
                        final String date = dates[index];
                        final bool isSelected = date == selectedDate;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(date),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.cardBackground,
                            labelStyle: AppTextStyles.chip.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            onSelected: (bool selected) {
                              if (selected) {
                                setModalState(() => selectedDate = date);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Select Time Slot',
                    style: AppTextStyles.heading3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: times.length,
                      itemBuilder: (BuildContext _, int index) {
                        final String time = times[index];
                        final bool isSelected = time == selectedTime;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(time),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: AppColors.cardBackground,
                            labelStyle: AppTextStyles.chip.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            onSelected: (bool selected) {
                              if (selected) {
                                setModalState(() => selectedTime = time);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        propertyProvider.addVisit({
                          'propertyId': property.id,
                          'title': property.title,
                          'location': property.location,
                          'date': selectedDate,
                          'time': selectedTime,
                          'agentName': 'Rajesh Kumar',
                          'agentPhone': '+91 98765 43210',
                          'status': 'Confirmed',
                          'isUpcoming': true,
                        });
                        Navigator.pop(sheetContext);
                        _showSuccessDialog(context, selectedDate, selectedTime);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm Schedule',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, String date, String time) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Scheduled!'),
          ],
        ),
        content: Text(
            'Your visit is successfully scheduled for $date at $time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              try {
                if (Navigator.canPop(context)) {
                  Navigator.pushNamed(context, '/visits');
                }
              } catch (e) {
                debugPrint('[PropertyDetail] Navigate to visits error: $e');
              }
            },
            child: const Text('View Visits'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // ENQUIRY BOTTOM SHEET — unchanged
  // ===========================================================================

  void _showEnquiryBottomSheet(
    BuildContext context,
    dynamic property,
    PropertyProvider propertyProvider,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        final TextEditingController messageController = TextEditingController(
          text:
              'Hi, I am interested in "${property.title}". Please contact me with more details.',
        );
        bool shareContact = true;

        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textHint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Enquire About Property', style: AppTextStyles.heading2),
                  const SizedBox(height: 4),
                  Text(
                    property.title as String,
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                            color: AppColors.textHint.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: shareContact,
                        activeColor: AppColors.primary,
                        onChanged: (bool? val) {
                          setModalState(() => shareContact = val ?? true);
                        },
                      ),
                      Expanded(
                        child: Text(
                          'Share my phone number & email with agent',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        propertyProvider.incrementEnquiries();
                        Navigator.pop(sheetContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Enquiry sent successfully! The agent will contact you shortly.',
                            ),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Send Enquiry',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // ICON HELPER
  // ===========================================================================

  IconData _getIconFromString(String iconString) {
    final String key = iconString.startsWith('Icons.')
        ? iconString.substring('Icons.'.length)
        : iconString;

    switch (key) {
      case 'apartment':
        return Icons.apartment;
      case 'pool':
        return Icons.pool;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'child_care':
        return Icons.child_care;
      case 'security':
        return Icons.security;
      case 'shopping_bag':
        return Icons.shopping_bag;
      case 'local_hospital':
        return Icons.local_hospital;
      case 'school':
        return Icons.school;
      case 'train':
        return Icons.train;
      case 'business':
        return Icons.business;
      case 'hotel':
        return Icons.hotel;
      case 'movie':
        return Icons.movie;
      case 'directions_car':
        return Icons.directions_car;
      case 'home':
        return Icons.home;
      case 'directions_run':
        return Icons.directions_run;
      case 'sports_soccer':
        return Icons.sports_soccer;
      case 'groups':
        return Icons.groups;
      case 'bolt':
        return Icons.bolt;
      case 'elevator':
        return Icons.elevator;
      case 'local_parking':
        return Icons.local_parking;
      case 'check_circle':
        return Icons.check_circle;
      default:
        debugPrint('[PropertyDetail] Unknown icon string: $iconString');
        return Icons.circle;
    }
  }
}

// =============================================================================
// Small private value holders for the Property Information grid and
// Highlights row — kept file-local since they're only used here.
// =============================================================================

class _InfoItem {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem(this.icon, this.label, this.value);
}

class _Highlight {
  final String label;
  final IconData icon;
  final Color color;

  const _Highlight(this.label, this.icon, this.color);
}
