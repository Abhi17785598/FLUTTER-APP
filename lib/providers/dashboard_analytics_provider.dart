import 'package:flutter/foundation.dart';

import '../models/dashboard_analytics.dart';
import '../services/dashboard_analytics_service.dart';

/// Analytics + Audience state for the Manage Dashboard.
///
/// Additive: each role keeps its own existing dashboard provider for its own
/// business logic; this one only supplies the metrics the approved design shows
/// and which no Flutter service previously computed.
///
/// Follows the shape of the other feature providers (blueprint §1.2.1). The two
/// tabs load independently so a failure in one never blanks the other.
class DashboardAnalyticsProvider extends ChangeNotifier {
  DashboardAnalyticsProvider({
    required this.analyticsSource,
    required this.audienceSource,
    this.includeSavedProperties = false,
    this.growthFromContent = true,
    this.includeListingMetrics = false,
    this.includeWatchMetrics = false,
    this.includeLeadMetrics = false,
    DashboardAnalyticsService? service,
  }) : _service = service ?? DashboardAnalyticsService();

  /// Content table for the Analytics tab.
  ///
  /// Separate from [audienceSource] because React is not consistent: for the
  /// Individual role `IndividualAnalytics.tsx` reads `influencer_videos` while
  /// `IndividualAudienceInsights.tsx` reads `properties`.
  final AnalyticsContentSource analyticsSource;

  /// Content table for the Audience tab.
  final AnalyticsContentSource audienceSource;

  /// Only the Individual variant queries `saved_properties` in React.
  final bool includeSavedProperties;

  /// Broker hard-codes its growth figures to 0 in React.
  final bool growthFromContent;

  /// Broker only: the six listing metrics `BrokerAnalytics.tsx` computes and no
  /// other variant does — inquiries, active/sold counts, portfolio value and
  /// commission.
  ///
  /// Off by default, in the same shape as [includeSavedProperties], so every
  /// role that does not opt in issues exactly the queries it did before Spec C.
  final bool includeListingMetrics;

  /// Influencer only: `avgWatchTime` and `avgCompletionRate` from
  /// `influencer_video_views` (`InfluencerAnalytics.tsx:75-87`).
  final bool includeWatchMetrics;

  /// Broker only: the three lead metrics from `property_inquiries`
  /// (`BrokerAudienceInsights.tsx:88-101`). Audience tab.
  final bool includeLeadMetrics;

  final DashboardAnalyticsService _service;

  String? _userId;
  bool _disposed = false;

  DashboardAnalytics _analytics = DashboardAnalytics.empty;
  bool _analyticsLoading = true;
  bool _analyticsFailed = false;

  DashboardAudience _audience = DashboardAudience.empty;
  bool _audienceLoading = true;
  bool _audienceFailed = false;

  DashboardAnalytics get analytics => _analytics;
  bool get analyticsLoading => _analyticsLoading;
  bool get analyticsFailed => _analyticsFailed;

  DashboardAudience get audience => _audience;
  bool get audienceLoading => _audienceLoading;
  bool get audienceFailed => _audienceFailed;

  Future<void> load(String userId) async {
    _userId = userId;
    await Future.wait([_loadAnalytics(userId), _loadAudience(userId)]);
  }

  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null) return;
    await load(userId);
  }

  Future<void> _loadAnalytics(String userId) async {
    _analyticsLoading = true;
    _analyticsFailed = false;
    _safeNotify();

    try {
      _analytics = await _service.fetchAnalytics(
        userId: userId,
        source: analyticsSource,
        includeSavedProperties: includeSavedProperties,
        growthFromContent: growthFromContent,
        includeListingMetrics: includeListingMetrics,
        includeWatchMetrics: includeWatchMetrics,
      );
    } catch (e) {
      debugPrint('DashboardAnalyticsProvider._loadAnalytics failed: $e');
      _analyticsFailed = true;
      _analytics = DashboardAnalytics.empty;
    } finally {
      _analyticsLoading = false;
      _safeNotify();
    }
  }

  Future<void> _loadAudience(String userId) async {
    _audienceLoading = true;
    _audienceFailed = false;
    _safeNotify();

    try {
      _audience = await _service.fetchAudience(
        userId: userId,
        source: audienceSource,
        includeLeadMetrics: includeLeadMetrics,
      );
    } catch (e) {
      debugPrint('DashboardAnalyticsProvider._loadAudience failed: $e');
      _audienceFailed = true;
      _audience = DashboardAudience.empty;
    } finally {
      _audienceLoading = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
