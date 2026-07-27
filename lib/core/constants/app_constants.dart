class AppConstants {
  AppConstants._();

  // Border Radius
  static const double cardRadius = 16.0;
  static const double chipRadius = 8.0;
  static const double buttonRadius = 12.0;
  static const double searchBarRadius = 14.0;
  static const double imageThumbnailRadius = 12.0;

  // Heights
  static const double bottomNavHeight = 64.0;
  static const double searchBarHeight = 54.0;
  static const double heroBannerHeight = 180.0;
  static const double categoryIconSize = 52.0;
  static const double propertyCardWidth = 220.0;
  static const double propertyCardImageHeight = 140.0;
  static const double propertyCardHeight = 280.0;
  static const double filterChipHeight = 36.0;
  static const double propertyListItemImageSize = 160.0;
  static const double promoBannerHeight = 72.0;
  static const double bottomActionBarHeight = 60.0;
  static const double propertyTypeChipWidth = 88.0;
  static const double propertyTypeChipHeight = 90.0;
  static const double selectableChipWidth = 72.0;
  static const double selectableChipHeight = 38.0;
  static const double showResultsButtonHeight = 52.0;
  static const double propertyCompactImageWidth = 130.0;
  static const double propertyCompactImageHeight = 95.0;
  static const double propertyDetailHeroHeight = 260.0;
  static const double stickyBottomBarHeight = 64.0;

  // Icon Sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 28.0;
  static const double categoryIconInnerSize = 24.0;
  static const double amenityIconSize = 44.0;
  static const double nearbyIconSize = 40.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;

  // Animation Durations
  static const int animationDurationMs = 300;
  static const int carouselAutoScrollDurationMs = 3000;
  static const int heartAnimationDurationMs = 150;
  static const int staggerDelayMs = 50;
  static const int splashDurationMs = 2600;
  static const int staggerListItemDelayMs = 60;
  static const int pageTransitionMs = 350;
  static const int microInteractionMs = 120;

  // Screen Names — EXISTING
  static const String homeScreen = '/home';
  static const String searchScreen = '/search';
  static const String searchResultsScreen = '/search-results';
  static const String shortlistScreen = '/shortlist';
  static const String filtersScreen = '/filters';
  static const String propertyDetailScreen = '/property-detail';
  static const String profileScreen = '/profile';
  static const String visitsScreen = '/visits';
  static const String reelsScreen = '/reels';
  static const String postPropertyScreen = '/post-property';

  // ── NEW SCREEN ROUTES ──────────────────────
  static const String notificationsScreen = '/notifications';
  static const String emiCalculatorScreen = '/emi-calculator';
  static const String comparePropertiesScreen = '/compare-properties';
  static const String paymentMethodScreen = '/payment-method';
  // ──────────────────────────────────────────

  // Image Placeholders
  static const String defaultImageUrl =
      'https://picsum.photos/seed/property/400/300';
  static const String avatarUrl = 'https://picsum.photos/seed/avatar/100/100';

  // Budget filter bounds (rupees) — matches Search.tsx's PriceRangeSlider
  // exactly, replacing the old arbitrary 20-500 "lakhs-ish" scale.
  static const double priceMin = 0;
  static const double priceMax = 500000000; // ₹50 Cr
  static const double priceStep = 1000000; // ₹10 L
  // Sent as the effective max whenever the slider is dragged to its ceiling.
  static const double priceUnbounded = 5000000000; // ₹500 Cr

  // Near-me radius search — hardcoded on the website (Search.tsx), ported
  // verbatim rather than made user-configurable, for parity.
  static const double nearMeRadiusKm = 15;
  static const int nearMeResultCap = 100;

  // Pagination — additive vs. the website (which fetches everything in one
  // shot); see the plan's "Deliberate deviations" section.
  static const int searchPageSize = 20;
  static const int mapResultsSafetyCap = 300;
}