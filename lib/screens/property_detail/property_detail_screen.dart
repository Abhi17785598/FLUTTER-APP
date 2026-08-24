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
import '../../core/utils/compare_toggle_handler.dart';
import '../../providers/chat_thread_provider.dart';
import '../../providers/compare_provider.dart';
import '../../providers/property_provider.dart';
import '../../models/reel_comment.dart';
import '../../services/comment_service.dart';
import '../../services/messaging_service.dart';
import '../messaging/chat_thread_screen.dart';
import 'widgets/share_property_sheet.dart';
import '../../widgets/verified_badge.dart';
import '../../widgets/amenity_icon_tile.dart';
import '../../widgets/nearby_place_row.dart';
import '../../widgets/property_map_widget.dart';
import '../../widgets/property_card_horizontal.dart';
import '../../widgets/emi_calculator_widget.dart';
import '../gallery/gallery_viewer_screen.dart';
import '../../services/nearby_places_service.dart';
import '../../services/property_inquiry_service.dart';
import '../../services/property_service.dart';
import '../../services/session_service.dart';
import '../../services/visit_booking_service.dart';
import '../../providers/auth_provider.dart';
import 'booking_enquiry_validation.dart';
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

  /// Injectable for tests — default to real, Supabase-backed services when
  /// null.
  final VisitBookingService? visitBookingService;
  final PropertyInquiryService? inquiryService;

  const PropertyDetailScreen({
    super.key,
    required this.propertyId,
    this.visitBookingService,
    this.inquiryService,
  });

  @override
  State<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends State<PropertyDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isDescriptionExpanded = false;
  bool _showAllAmenities = false;
  bool _showAllNearby = false;

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
  PropertyOwnerProfile? _ownerProfile;
  bool _isLoadingProperty = true;
  String? _loadError;

  late final VisitBookingService _visitBookingService =
      widget.visitBookingService ?? VisitBookingService();
  late final PropertyInquiryService _inquiryService =
      widget.inquiryService ?? PropertyInquiryService();

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
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Curves.easeOutCubic,
          ),
        );
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
    final PropertyProvider propertyProvider = Provider.of<PropertyProvider>(
      context,
      listen: false,
    );
    final cached = propertyProvider.findCached(widget.propertyId);
    if (cached != null && mounted) {
      setState(() => _property = cached);
    }

    try {
      final PropertyDetailBundle bundle = await _propertyService
          .getPropertyDetail(widget.propertyId);
      if (!mounted) return;
      setState(() {
        _property = bundle.property;
        _ownerProfile = bundle.ownerProfile;
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
      final List<NearbyPlace> results = await _nearbyPlacesService
          .fetchNearbyPlaces(
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
    if (property == null ||
        property.propertyType == null ||
        property.category == null) {
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
        body: Center(child: Text(_loadError ?? 'Property not found')),
      );
    }

    final property = _property!;
    final PropertyProvider propertyProvider = Provider.of<PropertyProvider>(
      context,
    );

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
                  _buildTopActions(context, property, propertyProvider),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    property.title,
                                    style: AppTextStyles.heading2.copyWith(
                                      fontSize: 18,
                                    ),
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

                            // Additional details — the long-tail wizard
                            // fields (RERA, facing, legal approvals,
                            // utilities, pricing overflow, contact prefs)
                            // stored in `properties.metadata`. Mirrors the
                            // portal's renderAdditionalDetails/
                            // renderExtendedDetails grouping.
                            _buildAdditionalDetailsSection(property),

                            // Posted by (owner/broker) — mirrors the
                            // portal's "Contact Seller" block. Hidden
                            // entirely when no owner profile resolved.
                            if (_ownerProfile != null) ...[
                              _buildOwnerSection(context),
                              const SizedBox(height: 20),
                            ],

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
                              Text(
                                'EMI Calculator',
                                style: AppTextStyles.heading3,
                              ),
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

      bottomNavigationBar: _buildBottomBar(context, property, propertyProvider),
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
          child: Icon(
            Icons.broken_image,
            color: AppColors.textSecondary,
            size: 48,
          ),
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
              placeholder: (BuildContext ctx, String url) =>
                  Container(color: AppColors.textHint.withOpacity(0.1)),
              errorWidget: (BuildContext ctx, String url, Object error) {
                debugPrint(
                  '[PropertyDetail] Image load error for ${property.id} '
                  '(index $index): $error',
                );
                return Container(
                  color: AppColors.textHint.withOpacity(0.1),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: AppColors.textSecondary,
                      size: 48,
                    ),
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
            colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TOP ACTIONS (back · share · favourite)
  // Favourite icon is keyed off PropertyProvider.isShortlisted (id-based,
  // backed by the persisted `saved_properties` table) rather than requiring
  // the property to already be in one of PropertyProvider's cached lists —
  // so a deep-linked property still shows/toggles the correct saved state.
  // ===========================================================================

  Widget _buildTopActions(
    BuildContext context,
    dynamic property,
    PropertyProvider propertyProvider,
  ) {
    final String propertyId = property.id as String;
    final bool isShortlisted = propertyProvider.isShortlisted(propertyId);
    final bool isLiked = propertyProvider.isLiked(propertyId);
    final bool isInCompare = context.watch<CompareProvider>().isSelected(
      propertyId,
    );

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
              // Like — a real, separate action from Save/Shortlist below;
              // the reference backs it with `user_likes`, not
              // `saved_properties`. Heart icon, matching the reference's own
              // Like icon exactly (PropertyDetails.tsx / CombinedFeed.tsx use
              // `Heart` for Like and `Bookmark` for Save — never two hearts).
              GestureDetector(
                onTap: () => propertyProvider.toggleLike(propertyId),
                child: _buildCircleButton(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showPropertyComments(property),
                child: _buildCircleButton(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: const Icon(
                    Icons.mode_comment_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _shareProperty(property),
                child: _buildCircleButton(
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: const Icon(Icons.share, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              // Save/Shortlist — switched from a second heart to a bookmark
              // icon. Direct consequence of the Like fix above: the
              // reference never shows two heart icons side by side — Like is
              // Heart, Save is Bookmark (PropertyDetails.tsx/CombinedFeed.tsx).
              // Behavior/state/persistence here are unchanged.
              GestureDetector(
                onTap: () => propertyProvider.toggleShortlist(propertyId),
                child: _buildCircleButton(
                  backgroundColor: Colors.white,
                  child: Icon(
                    isShortlisted ? Icons.bookmark : Icons.bookmark_border,
                    color: isShortlisted
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => handleCompareToggle(context, property),
                child: _buildCircleButton(
                  backgroundColor: Colors.white,
                  child: Icon(
                    isInCompare
                        ? Icons.check_circle
                        : Icons.compare_arrows_rounded,
                    color: isInCompare
                        ? AppColors.primary
                        : AppColors.textSecondary,
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

  /// Opens the same visible-link / Copy Link / Share pattern already used
  /// for profile sharing, mirroring the portal's PropertyShareModal (a
  /// readable, copyable link plus the system share sheet).
  void _shareProperty(dynamic property) {
    showSharePropertySheet(
      context,
      propertyId: property.id as String,
      title: (property.title as String?) ?? '',
      location: property.location as String?,
      priceDisplay: property.priceDisplay as String?,
    );
  }

  /// Reuses the same `post_comments` infrastructure already built for reels
  /// (`CommentService`/`ReelComment` — generic despite the name, keyed by
  /// postId+postType, not reel-specific), just with `post_type: 'property'`
  /// instead of `'video'`. No new comment system, no schema change.
  void _showPropertyComments(dynamic property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _PropertyCommentsSheet(
        propertyId: property.id as String,
        commentsEnabled: _ownerProfile?.commentsEnabled ?? true,
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

    debugPrint(
      '[PropertyDetail] Opening gallery for property '
      '${property.id} at index $initialIndex of ${images.length}',
    );

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
    debugPrint(
      '[PropertyDetail] Virtual Tour tapped for property: '
      '${property.id}',
    );

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
      highlights.add(
        _Highlight('Verified', Icons.verified, AppColors.verifiedBadge),
      );
    }
    if (property.isTrending == true) {
      highlights.add(
        _Highlight('Trending', Icons.trending_up, AppColors.warning),
      );
    }
    final String? possession = property.possessionStatus as String?;
    if (possession != null && possession.toLowerCase().contains('ready')) {
      highlights.add(
        _Highlight('Ready To Move', Icons.home_work, AppColors.success),
      );
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
            .map(
              (h) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
              ),
            )
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

    // Land/Plot has no bedroom/bathroom concept (mirrors the portal's
    // `property.category === 'land'` branch in PropertyDetails.tsx, which
    // never pushes Bed/Bath overview items for that category) — same gate
    // already applied to the outer listing card.
    final bool isLand = property.category == 'land';

    final List<_InfoItem> items = [
      if (!isLand) ...[
        _InfoItem(Icons.bed, 'Bedrooms', '${property.beds}'),
        _InfoItem(Icons.bathtub, 'Bathrooms', '${property.baths}'),
      ],
      _InfoItem(Icons.square_foot, 'Area', '${property.sqft} sqft'),
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
    // Mirrors the portal's overview grid, which only pushes this item when
    // `property.available_from` is set (PropertyDetails.tsx renderPropertyOverview).
    final DateTime? availableFrom = property.availableFrom as DateTime?;
    if (availableFrom != null) {
      items.add(
        _InfoItem(
          Icons.event,
          'Available From',
          _formatShortDate(availableFrom),
        ),
      );
    }
    // Mirrors the portal's "Price Negotiable" chip (renderExtendedDetails'
    // Financial & Pricing group), which only appears when the flag is true.
    if (property.isNegotiable == true) {
      items.add(_InfoItem(Icons.handshake_outlined, 'Price', 'Negotiable'));
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

  static const List<String> _monthAbbreviations = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatShortDate(DateTime date) =>
      '${date.day} ${_monthAbbreviations[date.month - 1]} ${date.year}';

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
  // ADDITIONAL DETAILS (properties.metadata)
  // ===========================================================================

  /// Surfaces the long-tail wizard fields already written into
  /// `properties.metadata` (RERA, facing, legal approvals, utilities, pricing
  /// overflow, contact preferences) that have no dedicated PropertyModel
  /// column/field. Each group is omitted entirely when none of its fields are
  /// present — same "hide empty group" rule the portal's
  /// renderAdditionalDetails/renderExtendedDetails use.
  Widget _buildAdditionalDetailsSection(dynamic property) {
    final Map<String, dynamic> meta =
        (property.metadata as Map<String, dynamic>?) ?? const {};
    if (meta.isEmpty) return const SizedBox.shrink();

    String? str(String key) {
      final v = meta[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    bool isTrue(String key) => meta[key] == true;

    List<String> strList(String key) {
      final v = meta[key];
      if (v is List) {
        return v
            .map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList();
      }
      return const [];
    }

    final List<_DetailGroup> groups = [
      _DetailGroup('Condition & Availability', [
        if (str('propertyCondition') != null)
          _DetailRow('Condition', str('propertyCondition')!),
        if (str('constructionAge') != null)
          _DetailRow('Construction Age', str('constructionAge')!),
        if (str('availabilityStatus') != null)
          _DetailRow('Availability', str('availabilityStatus')!),
        if (str('facing') != null) _DetailRow('Facing', str('facing')!),
        if (strList('availableItems').isNotEmpty)
          _DetailRow('Available Items', strList('availableItems').join(', ')),
      ]),
      _DetailGroup('Utilities & Infrastructure', [
        if (str('electricityBackup') != null)
          _DetailRow('Electricity Backup', str('electricityBackup')!),
        if (str('waterAvailability') != null)
          _DetailRow('Water Availability', str('waterAvailability')!),
        if (str('numberOfLifts') != null)
          _DetailRow('Lifts', str('numberOfLifts')!),
        if (str('openParking') != null)
          _DetailRow('Open Parking', str('openParking')!),
        if (isTrue('gasPipeline')) _DetailRow('Gas Pipeline', 'Yes'),
        if (isTrue('internetAvailability')) _DetailRow('Internet', 'Available'),
        if (isTrue('solarBackup')) _DetailRow('Solar Backup', 'Yes'),
        if (isTrue('guardRoom')) _DetailRow('Guard Room', 'Yes'),
      ]),
      // Mirrors the portal's renderExtendedDetails "Legal & Society" group
      // (PropertyDetails.tsx) — every field is read straight off the same
      // `properties.metadata` blob the website reads, so listings created on
      // the website (which collects all of these) display correctly here
      // too, not just app-created ones.
      _DetailGroup('Legal & Society', [
        if (isTrue('reraRegistered'))
          _DetailRow('RERA Registered', str('reraNumber') ?? 'Yes'),
        if (isTrue('saleDeed')) _DetailRow('Sale Deed', 'Available'),
        if (isTrue('registryCopy')) _DetailRow('Registry Copy', 'Available'),
        if (isTrue('registeredAgreement'))
          _DetailRow('Registered Agreement', 'Yes'),
        if (isTrue('unregisteredAgreement'))
          _DetailRow('Unregistered Agreement', 'Yes'),
        if (isTrue('nocAvailable')) _DetailRow('NOC', 'Available'),
        if (isTrue('encumbranceFree')) _DetailRow('Encumbrance Free', 'Yes'),
        if (isTrue('propertyApproved')) _DetailRow('Property Approved', 'Yes'),
        if (isTrue('approvedByAuthority'))
          _DetailRow('Approved By Authority', 'Yes'),
        if (isTrue('khataAvailable')) _DetailRow('Khata Available', 'Yes'),
        if (isTrue('pattaAvailable')) _DetailRow('Patta Available', 'Yes'),
        if (isTrue('jamabandiAvailable'))
          _DetailRow('Jamabandi Available', 'Yes'),
        if (isTrue('mutationAvailable'))
          _DetailRow('Mutation Available', 'Yes'),
        if (isTrue('ocCertificate')) _DetailRow('Occupancy Certificate', 'Yes'),
        if (isTrue('completionCertificate'))
          _DetailRow('Completion Certificate', 'Yes'),
        if (isTrue('buildingApproval')) _DetailRow('Building Approval', 'Yes'),
        if (isTrue('taxReceipt')) _DetailRow('Tax Receipt', 'Available'),
        if (isTrue('propertyTaxPaid')) _DetailRow('Property Tax Paid', 'Yes'),
        if (isTrue('courtCasePending')) _DetailRow('Court Case Pending', 'Yes'),
        if (isTrue('loanApproved') || isTrue('bankLoanApproved'))
          _DetailRow('Bank Loan Approved', 'Yes'),
        if (strList('approvedByBanks').isNotEmpty)
          _DetailRow(
            'Approved By Banks',
            strList('approvedByBanks').join(', '),
          ),
        if (isTrue('fireLicense')) _DetailRow('Fire License', 'Yes'),
        if (isTrue('tradeLicense')) _DetailRow('Trade License', 'Yes'),
        if (isTrue('foodLicense')) _DetailRow('Food License', 'Yes'),
        if (isTrue('pollutionClearance'))
          _DetailRow('Pollution Clearance', 'Yes'),
        if (isTrue('industrialApproval'))
          _DetailRow('Industrial Approval', 'Yes'),
        if (isTrue('hostelLicense')) _DetailRow('Hostel License', 'Yes'),
        if (isTrue('dispute')) _DetailRow('Under Dispute', 'Yes'),
        if (str('registrationTitle') != null)
          _DetailRow('Registration Title', str('registrationTitle')!),
        if (str('mutation') != null) _DetailRow('Mutation', str('mutation')!),
        if (str('ownershipType') != null)
          _DetailRow('Ownership Type', str('ownershipType')!),
        if (str('ownerName') != null)
          _DetailRow('Owner Name', str('ownerName')!),
        if (isTrue('ownerLiveInSociety'))
          _DetailRow('Owner Lives In Society', 'Yes'),
        if (isTrue('registrationRequired'))
          _DetailRow('Registration Required', 'Yes'),
      ]),
      // Mirrors the portal's "Financial & Pricing" group.
      _DetailGroup('Financial & Pricing', [
        if (str('financeStatus') != null)
          _DetailRow('Finance Status', str('financeStatus')!),
        if (str('priceType') != null)
          _DetailRow('Price Type', str('priceType')!),
        if (isTrue('priceNegotiable')) _DetailRow('Price Negotiable', 'Yes'),
        if (str('propertyTax') != null)
          _DetailRow('Property Tax', str('propertyTax')!),
        if (str('waterTax') != null) _DetailRow('Water Tax', str('waterTax')!),
        if (str('otherTax') != null) _DetailRow('Other Tax', str('otherTax')!),
        if (str('societyMaintenance') != null)
          _DetailRow('Society Maintenance', str('societyMaintenance')!),
        if (str('maintenanceCharges') != null)
          _DetailRow('Maintenance Charges', str('maintenanceCharges')!),
        if (str('securityDeposit') != null)
          _DetailRow('Security Deposit', str('securityDeposit')!),
        if (str('bookingAmount') != null)
          _DetailRow('Booking Amount', str('bookingAmount')!),
        if (str('tokenAmount') != null)
          _DetailRow('Token Amount', str('tokenAmount')!),
        if (str('lockInPeriod') != null)
          _DetailRow('Lock-in Period', str('lockInPeriod')!),
        if (str('brokerage') != null)
          _DetailRow('Brokerage', str('brokerage')!),
        if (str('brokerageType') != null)
          _DetailRow('Brokerage Type', str('brokerageType')!),
        if (isTrue('taxGovtChargesIncluded'))
          _DetailRow('Tax/Govt Charges Included', 'Yes'),
        if (isTrue('allInclusivePriceToggle'))
          _DetailRow('All Inclusive Price', 'Yes'),
        if (str('loanAvailability') != null)
          _DetailRow('Loan Availability', str('loanAvailability')!),
        if (str('expectedAppreciation') != null)
          _DetailRow('Expected Appreciation', str('expectedAppreciation')!),
        if (str('rentalYield') != null)
          _DetailRow('Rental Yield', str('rentalYield')!),
        if (str('expectedPrice') != null)
          _DetailRow('Expected Price', str('expectedPrice')!),
        if (isTrue('gstApplicable')) _DetailRow('GST Applicable', 'Yes'),
      ]),
      // Mirrors the portal's "Construction & Land" group.
      _DetailGroup('Construction & Land', [
        if (str('projectStatus') != null)
          _DetailRow('Project Status', str('projectStatus')!),
        if (str('projectName') != null)
          _DetailRow('Project Name', str('projectName')!),
        if (str('builderName') != null)
          _DetailRow('Builder Name', str('builderName')!),
        if (str('totalFlats') != null)
          _DetailRow('Total Flats', str('totalFlats')!),
        if (str('plotArea') != null)
          _DetailRow(
            'Plot Area',
            [
              str('plotArea'),
              str('plotAreaUnit'),
            ].whereType<String>().join(' '),
          ),
        if (str('spaceDetails') != null)
          _DetailRow('Space Details', str('spaceDetails')!),
        if (str('areaPerFloor') != null)
          _DetailRow('Area Per Floor', str('areaPerFloor')!),
        if (str('landSize') != null)
          _DetailRow(
            'Land Size',
            [
              str('landSize'),
              str('landSizeUnit'),
            ].whereType<String>().join(' '),
          ),
        if (str('landType') != null) _DetailRow('Land Type', str('landType')!),
        if (str('boundary') != null) _DetailRow('Boundary', str('boundary')!),
      ]),
      _DetailGroup('Contact Preferences', [
        if (str('contactName') != null)
          _DetailRow('Contact Name', str('contactName')!),
        if (str('whatsappNumber') != null)
          _DetailRow('WhatsApp Number', str('whatsappNumber')!),
        if (str('bestTimeToCall') != null)
          _DetailRow('Best Time To Call', str('bestTimeToCall')!),
      ]),
    ].where((g) => g.rows.isNotEmpty).toList();

    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Additional Details', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        for (final group in groups) ...[
          Text(
            group.title,
            style: AppTextStyles.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.textHint.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < group.rows.length; i++) ...[
                  if (i > 0) const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(group.rows[i].label, style: AppTextStyles.caption),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          group.rows[i].value,
                          textAlign: TextAlign.right,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
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
          Text(property.location as String, style: AppTextStyles.caption),
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
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await _launchMapsUri(context, uri, 'Could not open Google Maps');
  }

  Future<void> _getDirections(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    await _launchMapsUri(context, uri, 'Could not start directions');
  }

  Future<void> _launchMapsUri(
    BuildContext context,
    Uri uri,
    String failureMessage,
  ) async {
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    } catch (e) {
      debugPrint('[PropertyDetail] Maps launch error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
      }
    }
  }

  // ===========================================================================
  // POSTED BY (owner/broker) SECTION
  // Mirrors PropertyDetails.tsx's "Contact Seller" block: display_name,
  // avatar_url, user_type and phone from `profiles`, fetched alongside the
  // property row by PropertyService.getPropertyDetail. Not rendered when no
  // owner profile resolved (see the `if (_ownerProfile != null)` call site),
  // matching the portal's own conditional rendering.
  // ===========================================================================

  Widget _buildOwnerSection(BuildContext context) {
    final owner = _ownerProfile;
    if (owner == null) return const SizedBox.shrink();

    final String name = (owner.companyName?.isNotEmpty ?? false)
        ? owner.companyName!
        : (owner.displayName?.isNotEmpty ?? false)
        ? owner.displayName!
        : 'Property Owner';
    final String role = (owner.userType?.isNotEmpty ?? false)
        ? owner.userType![0].toUpperCase() + owner.userType!.substring(1)
        : 'Contact for details';
    final String? phone = owner.phone;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Posted by', style: AppTextStyles.heading3),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.textHint.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _openOwnerProfile(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryLight,
                        backgroundImage: (owner.avatarUrl?.isNotEmpty ?? false)
                            ? CachedNetworkImageProvider(owner.avatarUrl!)
                            : null,
                        child: (owner.avatarUrl?.isNotEmpty ?? false)
                            ? null
                            : const Icon(
                                Icons.person,
                                color: AppColors.primary,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: AppTextStyles.heading3.copyWith(
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(role, style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_property?.userId !=
                  Supabase.instance.client.auth.currentUser?.id)
                IconButton(
                  onPressed: () => _messageOwner(context),
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.primary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    shape: const CircleBorder(),
                  ),
                ),
              if (phone != null && phone.isNotEmpty)
                IconButton(
                  onPressed: () => _callOwner(context, phone),
                  icon: const Icon(Icons.phone, color: AppColors.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    shape: const CircleBorder(),
                  ),
                ),
            ],
          ),
        ),
        ..._buildOwnerSocialLinks(owner.socialMedia),
      ],
    );
  }

  /// Real messaging with property context — `start_conversation(...,
  /// p_skip_request_gate: true)` (a shared-property context legitimately
  /// skips the message-request gate, matching the portal's
  /// `!!sharedPropertyId` rule), then shares this property into the thread
  /// before opening it, so it's already there on the first fetch. Deliberately
  /// separate from the "Enquire Now" button below, which is a pre-existing,
  /// unrelated lead-capture feature this messaging repair pass doesn't touch.
  Future<void> _messageOwner(BuildContext context) async {
    final property = _property;
    final ownerId = property?.userId;
    if (property == null || ownerId == null || ownerId.isEmpty) return;

    final owner = _ownerProfile;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final service = MessagingService();

    try {
      final conversationId = await service.startConversation(
        ownerId,
        skipRequestGate: true,
      );
      await service.sendPropertyShare(
        threadId: conversationId,
        senderId: Supabase.instance.client.auth.currentUser!.id,
        propertyId: property.id,
        content: 'Shared property: ${property.title}',
      );

      if (!context.mounted) return;
      await navigator.push(
        MaterialPageRoute(
          builder: (_) => ChatThreadScreen(
            kind: ChatThreadKind.conversation,
            threadId: conversationId,
            title: (owner?.companyName?.isNotEmpty ?? false)
                ? owner!.companyName!
                : (owner?.displayName?.isNotEmpty ?? false)
                ? owner!.displayName!
                : 'Property Owner',
            avatarUrl: owner?.avatarUrl,
            initials:
                ((owner?.displayName?.isNotEmpty ?? false)
                        ? owner!.displayName![0]
                        : 'P')
                    .toUpperCase(),
            participantUserId: ownerId,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[PropertyDetail] _messageOwner failed: $e');
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't start the conversation.")),
      );
    }
  }

  /// Mirrors PropertyDetails.tsx's owner-card social icon row (Facebook/
  /// Instagram/LinkedIn/YouTube/WhatsApp/Telegram), each shown only when its
  /// own field is present on the already-fetched `social_media` JSON.
  List<Widget> _buildOwnerSocialLinks(Map<String, dynamic>? socialMedia) {
    if (socialMedia == null || socialMedia.isEmpty) return const [];

    String? str(String key) {
      final v = socialMedia[key];
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    final links = <_SocialLink>[
      if (str('facebook') != null || str('facebook_page_link') != null)
        _SocialLink(
          Icons.facebook,
          str('facebook_page_link') ?? str('facebook')!,
        ),
      if (str('instagram') != null)
        _SocialLink(Icons.camera_alt, str('instagram')!),
      if (str('linkedin') != null)
        _SocialLink(Icons.business_center, str('linkedin')!),
      if (str('youtube') != null)
        _SocialLink(Icons.play_circle_fill, str('youtube')!),
      if (str('whatsapp') != null)
        _SocialLink(
          Icons.chat,
          'https://wa.me/${str('whatsapp')!.replaceAll(RegExp(r'[^0-9]'), '')}',
        ),
      if (str('telegram') != null)
        _SocialLink(
          Icons.send,
          str('telegram')!.startsWith('http')
              ? str('telegram')!
              : 'https://t.me/${str('telegram')}',
        ),
    ];

    if (links.isEmpty) return const [];

    return [
      const SizedBox(height: 10),
      Row(
        children: [
          for (final link in links) ...[
            GestureDetector(
              onTap: () => _openExternalLink(link.url),
              child: Container(
                width: 34,
                height: 34,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(link.icon, size: 16, color: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    ];
  }

  Future<void> _openExternalLink(String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[PropertyDetail] Failed to open social link: $e');
    }
  }

  /// Opens the property's actual owner/broker profile — `_property!.userId`,
  /// the same id `PropertyService.getPropertyDetail` used to fetch
  /// `_ownerProfile`, never the signed-in viewer's id.
  void _openOwnerProfile(BuildContext context) {
    final userId = _property?.userId;
    if (userId == null || userId.isEmpty) return;
    Navigator.pushNamed(
      context,
      AppConstants.publicProfileScreen,
      arguments: {'userId': userId},
    );
  }

  Future<void> _callOwner(BuildContext context, String phone) async {
    final Uri uri = Uri.parse('tel:$phone');
    try {
      final bool launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the call')),
        );
      }
    } catch (e) {
      debugPrint('[PropertyDetail] Call launch error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start the call')),
        );
      }
    }
  }

  // ===========================================================================
  // AMENITIES SECTION
  // ===========================================================================

  Widget _buildAmenitiesSection(dynamic property) {
    final List amenities = property.amenities as List;
    // Mirrors the reference's showAllAmenities/PREVIEW_COUNT toggle
    // (PropertyDetails.tsx:2276-2279) — a preview slice by count, since this
    // widget's flat icon row has no per-category grouping to slice by.
    const int previewCount = 6;
    final bool canExpand = amenities.length > previewCount;
    final List visibleAmenities = _showAllAmenities || !canExpand
        ? amenities
        : amenities.sublist(0, previewCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Amenities', style: AppTextStyles.heading3),
            if (canExpand)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllAmenities = !_showAllAmenities;
                  });
                },
                child: Text(_showAllAmenities ? 'Show less' : 'View all'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 0),
            itemCount: visibleAmenities.length,
            itemBuilder: (BuildContext context, int index) {
              final amenity = visibleAmenities[index];
              final Color color = Color(
                int.parse((amenity.color as String).replaceAll('#', '0xFF')),
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
    // Mirrors the reference's showAllNearby/PREVIEW_COUNT(4) toggle
    // (PropertyDetails.tsx:2194-2195, 2256).
    final bool canExpand = _nearbyPlaces.length > 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Nearby Places', style: AppTextStyles.heading3),
            if (canExpand)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllNearby = !_showAllNearby;
                  });
                },
                child: Text(_showAllNearby ? 'Show less' : 'View all'),
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
          child: Text('No nearby places found', style: AppTextStyles.caption),
        ),
      );
    }

    final List<NearbyPlace> visiblePlaces =
        _showAllNearby || _nearbyPlaces.length <= 4
        ? _nearbyPlaces
        : _nearbyPlaces.sublist(0, 4);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: visiblePlaces.length,
      itemBuilder: (BuildContext context, int index) {
        final NearbyPlace place = visiblePlaces[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.textHint.withOpacity(0.2)),
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
    final compareProvider = context.watch<CompareProvider>();
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
                  Provider.of<PropertyProvider>(
                    context,
                    listen: false,
                  ).toggleShortlist(related.id);
                },
                isInCompare: compareProvider.isSelected(related.id),
                onCompareToggle: () => handleCompareToggle(context, related),
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
    // Same pattern already used by the app's other persistent bottom bars
    // (e.g. ProfileStickyActionBar, EditProfile's _SaveBar): grow the total
    // height and bottom padding by the device's real bottom safe-area inset,
    // so the 72 dp button row itself is unchanged but no longer sits flush
    // against — and behind — the Android system nav/gesture area.
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 72 + bottomInset,
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.textHint, width: 0.5)),
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
  // SCHEDULE VISIT BOTTOM SHEET — real `property_visit_bookings` insert,
  // matching BookVisitModal.tsx's fields/validation (name/phone regex, date
  // not in the past, time slot list) and never reporting success before
  // Supabase confirms the write.
  // ===========================================================================

  void _showScheduleBottomSheet(
    BuildContext context,
    dynamic property,
    PropertyProvider propertyProvider,
  ) {
    final AuthProvider authProvider = Provider.of<AuthProvider>(
      context,
      listen: false,
    );
    final User? currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to book a visit.')),
      );
      return;
    }

    // Same 9-slot list `BookVisitModal.tsx:71-81` stores verbatim as
    // `preferred_time` — not 24-hour labels, so kept exactly as the portal
    // writes them rather than "corrected".
    const List<String> timeSlots = [
      '10:00',
      '11:00',
      '12:00',
      '01:00',
      '02:00',
      '03:00',
      '04:00',
      '05:00',
      '06:00',
    ];

    final TextEditingController nameController = TextEditingController(
      text: authProvider.userName.isNotEmpty
          ? authProvider.userName
          : (currentUser.userMetadata?['full_name']?.toString() ?? ''),
    );
    final TextEditingController phoneController = TextEditingController(
      text:
          currentUser.phone ??
          authProvider.profileRow?['phone']?.toString() ??
          '',
    );
    // `BookVisitModal.tsx`'s optional Message textarea — was missing here
    // entirely even though `VisitBookingService.createBooking` already
    // accepted it.
    final TextEditingController messageController = TextEditingController();

    DateTime? selectedDate;
    String? selectedTime;
    String? nameError;
    String? phoneError;
    String? dateError;
    String? timeError;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            bool isSlotDisabled(String time) {
              final DateTime? date = selectedDate;
              if (date == null) return false;
              return VisitFormValidation.isSlotDisabled(
                time,
                date,
                DateTime.now(),
              );
            }

            Future<void> pickDate() async {
              final DateTime now = DateTime.now();
              final DateTime today = DateTime(now.year, now.month, now.day);
              final DateTime? picked = await showDatePicker(
                context: ctx,
                initialDate: selectedDate ?? today,
                firstDate: today,
                lastDate: today.add(const Duration(days: 365)),
              );
              if (picked != null) {
                setModalState(() {
                  selectedDate = picked;
                  dateError = null;
                  if (selectedTime != null && isSlotDisabled(selectedTime!)) {
                    selectedTime = null;
                  }
                });
              }
            }

            Future<void> submit() async {
              if (isSubmitting) return; // guards against a double tap
              final String name = nameController.text.trim();
              final String phone = phoneController.text.trim();
              setModalState(() {
                nameError = VisitFormValidation.nameError(name);
                phoneError = VisitFormValidation.phoneError(phone);
                dateError = selectedDate == null ? 'Please select date' : null;
                timeError = selectedTime == null ? 'Please select time' : null;
              });
              if (nameError != null ||
                  phoneError != null ||
                  dateError != null ||
                  timeError != null) {
                return;
              }

              setModalState(() => isSubmitting = true);
              try {
                await _visitBookingService.createBooking(
                  propertyId: property.id as String,
                  visitorName: name,
                  visitorPhone: phone,
                  preferredDate: selectedDate!,
                  preferredTime: selectedTime!,
                  message: messageController.text,
                  ownerName: _ownerProfile?.displayName,
                  ownerPhone: _ownerProfile?.phone,
                );
                if (!mounted) return;
                Navigator.pop(sheetContext);
                _showSuccessDialog(context, selectedDate!, selectedTime!);
              } catch (e) {
                if (!mounted) return;
                setModalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_describeBookingError(e))),
                );
              }
            }

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
              child: SingleChildScrollView(
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
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Name *',
                        errorText: nameError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      decoration: InputDecoration(
                        labelText: 'Phone *',
                        errorText: phoneError,
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Select Date',
                      style: AppTextStyles.heading3.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: pickDate,
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        selectedDate == null
                            ? 'Pick a date'
                            : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                      ),
                    ),
                    if (dateError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          dateError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Select Time Slot',
                      style: AppTextStyles.heading3.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: timeSlots.map((String time) {
                        final bool isSelected = time == selectedTime;
                        final bool disabled = isSlotDisabled(time);
                        return ChoiceChip(
                          label: Text(time),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: disabled
                              ? AppColors.textHint.withOpacity(0.15)
                              : AppColors.cardBackground,
                          labelStyle: AppTextStyles.chip.copyWith(
                            color: isSelected
                                ? Colors.white
                                : (disabled
                                      ? AppColors.textHint
                                      : AppColors.textSecondary),
                          ),
                          onSelected: disabled
                              ? null
                              : (bool selected) {
                                  if (selected) {
                                    setModalState(() {
                                      selectedTime = time;
                                      timeError = null;
                                    });
                                  }
                                },
                        );
                      }).toList(),
                    ),
                    if (timeError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          timeError!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    Text(
                      'Message',
                      style: AppTextStyles.heading3.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: messageController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Any requirements...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting ? null : submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Confirm Schedule',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(BuildContext context, DateTime date, String time) {
    final String formattedDate = '${date.day}/${date.month}/${date.year}';
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Scheduled!'),
          ],
        ),
        content: Text(
          'Your visit is successfully scheduled for $formattedDate at $time.',
        ),
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

  String _describeBookingError(Object error) =>
      describeSubmitError(error, "Couldn't book this visit");

  // ===========================================================================
  // ENQUIRY BOTTOM SHEET — real `property_inquiries` insert. No client-side
  // notification or interest-count bump: both already happen via DB trigger
  // (see PropertyInquiryService's doc comment).
  // ===========================================================================

  void _showEnquiryBottomSheet(
    BuildContext context,
    dynamic property,
    PropertyProvider propertyProvider,
  ) {
    final User? currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to send an enquiry.')),
      );
      return;
    }

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
        bool isSubmitting = false;
        String? messageError;

        return StatefulBuilder(
          builder: (BuildContext ctx, StateSetter setModalState) {
            Future<void> submit() async {
              if (isSubmitting) return; // guards against a double tap
              final String message = messageController.text.trim();
              setModalState(() {
                messageError = message.isEmpty
                    ? 'Please enter a message'
                    : null;
              });
              if (messageError != null) return;

              setModalState(() => isSubmitting = true);
              try {
                await _inquiryService.submit(
                  propertyId: property.id as String,
                  message: message,
                  contactPhone: shareContact ? currentUser.phone : null,
                  contactEmail: shareContact ? currentUser.email : null,
                );
                if (!mounted) return;
                Navigator.pop(sheetContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Enquiry sent successfully! The owner will contact you shortly.',
                    ),
                    backgroundColor: AppColors.success,
                  ),
                );
              } on DuplicateInquiryException catch (e) {
                if (!mounted) return;
                setModalState(() => isSubmitting = false);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(e.toString())));
              } catch (e) {
                if (!mounted) return;
                setModalState(() => isSubmitting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_describeEnquiryError(e))),
                );
              }
            }

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
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: messageController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter your message...',
                      errorText: messageError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textHint.withOpacity(0.3),
                        ),
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
                          'Share my phone number & email with owner',
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
                      onPressed: isSubmitting ? null : submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Send Enquiry',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
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

  String _describeEnquiryError(Object error) =>
      describeSubmitError(error, "Couldn't send this enquiry");

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

class _SocialLink {
  final IconData icon;
  final String url;

  const _SocialLink(this.icon, this.url);
}

class _DetailRow {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);
}

class _DetailGroup {
  final String title;
  final List<_DetailRow> rows;

  const _DetailGroup(this.title, this.rows);
}

/// Property comments — reuses `CommentService`/`ReelComment` (already
/// generic: postId + postType, not reel-specific) with `post_type:
/// 'property'`, the same `post_comments` table the reference's
/// CommentsPanel reads for properties. No new comment system.
class _PropertyCommentsSheet extends StatefulWidget {
  const _PropertyCommentsSheet({
    required this.propertyId,
    required this.commentsEnabled,
  });

  final String propertyId;
  final bool commentsEnabled;

  @override
  State<_PropertyCommentsSheet> createState() => _PropertyCommentsSheetState();
}

class _PropertyCommentsSheetState extends State<_PropertyCommentsSheet> {
  static const String _kPostType = 'property';

  final CommentService _service = CommentService();
  final TextEditingController _input = TextEditingController();

  List<ReelComment>? _comments;
  bool _loadFailed = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final comments = await _service.fetchComments(
        widget.propertyId,
        _kPostType,
      );
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loadFailed = false;
      });
    } catch (e) {
      debugPrint('[PropertyDetail] fetchComments failed: $e');
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  Future<void> _submit() async {
    final content = _input.text.trim();
    if (content.isEmpty || _submitting) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to comment')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final comment = await _service.submitComment(
        postId: widget.propertyId,
        postType: _kPostType,
        userId: userId,
        content: content,
      );
      if (!mounted) return;
      setState(() {
        _comments = [comment, ...?_comments];
        _input.clear();
      });
    } catch (e) {
      debugPrint('[PropertyDetail] submitComment failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Couldn't post comment")));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.6,
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textHint,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text('Comments', style: AppTextStyles.heading3),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildBody()),
            if (widget.commentsEnabled)
              _buildInputBar()
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Comments are turned off for this listing',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text('Could not load comments', style: AppTextStyles.body),
            const SizedBox(height: 8),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final comments = _comments;
    if (comments == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }

    if (comments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mode_comment_outlined,
              size: 56,
              color: AppColors.textHint.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text('No comments yet', style: AppTextStyles.body),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: comments.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildCommentRow(comments[index]),
    );
  }

  Widget _buildCommentRow(ReelComment comment) {
    final name = (comment.authorName?.isNotEmpty ?? false)
        ? comment.authorName!
        : 'User';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primaryLight,
          backgroundImage: (comment.authorAvatarUrl?.isNotEmpty ?? false)
              ? NetworkImage(comment.authorAvatarUrl!)
              : null,
          child: (comment.authorAvatarUrl?.isNotEmpty ?? false)
              ? null
              : Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: AppTextStyles.body.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                comment.content,
                style: AppTextStyles.body.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
              ),
            ),
            IconButton(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Highlight {
  final String label;
  final IconData icon;
  final Color color;

  const _Highlight(this.label, this.icon, this.color);
}
