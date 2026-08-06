/// Read-only models for the Social module.
///
/// Field names mirror `src/services/social/types.ts`; column names come from
/// the live `social_*` tables and the `social_accounts_safe` view, verified
/// against `information_schema` rather than inferred.
///
/// Money: ad spend and budgets are stored as integers in the currency's minor
/// unit (paise for INR), the same convention the billing tables use. The
/// `*Display` getters convert once, mirroring React's `formatMinor`.
library;

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse('$value');

int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

int? _intOrNull(dynamic value) =>
    value == null ? null : (value is int ? value : int.tryParse('$value'));

List<String> _stringList(dynamic value) => value is List
    ? value.map((e) => '$e').where((e) => e.isNotEmpty).toList()
    : const [];

/// `123456` → `₹1,234.56`; `null` → `—`.
///
/// Ports `formatMinor`. Dart has no `Intl.NumberFormat` without adding the
/// `intl` dependency, so the grouping is done directly — and React's rule of
/// dropping the decimals above 100 major units is preserved.
String formatMinorAmount(int? minor, {String? currency}) {
  if (minor == null) return '—';

  final major = minor / 100;
  final symbol = switch ((currency ?? 'INR').toUpperCase()) {
    'INR' => '₹',
    'USD' => r'$',
    'EUR' => '€',
    'GBP' => '£',
    final other => '$other ',
  };

  final text = major.abs() >= 100
      ? _groupIndian(major.abs().round().toString())
      : major.abs().toStringAsFixed(2);

  return '${major < 0 ? '-' : ''}$symbol$text';
}

/// Indian digit grouping: last three, then pairs.
String _groupIndian(String digits) {
  if (digits.length <= 3) return digits;
  final lastThree = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final pairs = <String>[];
  while (rest.length > 2) {
    pairs.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) pairs.insert(0, rest);
  return '${pairs.join(',')},$lastThree';
}

/// The caller's Meta connection, read from `social_accounts_safe`.
///
/// That view is the `social_accounts` table minus every token column
/// (`encrypted_access_token`, `token_iv`, `encrypted_page_token`,
/// `page_token_iv`, `encrypted_refresh_token`, `refresh_iv`). React reads the
/// view for exactly that reason and so does this — OAuth tokens must never
/// reach a client.
class SocialAccount {
  final bool connected;
  final String? pageName;
  final String? instagramUsername;
  final String? profilePictureUrl;
  final DateTime? tokenExpiry;
  final DateTime? connectedSince;
  final DateTime? lastSyncAt;
  final String? lastError;
  final bool autoRefresh;

  final bool adsCapable;
  final String? adAccountName;
  final String? adAccountCurrency;

  final int? fbFollowersCount;
  final int? igFollowersCount;
  final int? igMediaCount;

  const SocialAccount({
    this.connected = false,
    this.pageName,
    this.instagramUsername,
    this.profilePictureUrl,
    this.tokenExpiry,
    this.connectedSince,
    this.lastSyncAt,
    this.lastError,
    this.autoRefresh = false,
    this.adsCapable = false,
    this.adAccountName,
    this.adAccountCurrency,
    this.fbFollowersCount,
    this.igFollowersCount,
    this.igMediaCount,
  });

  factory SocialAccount.fromJson(Map<String, dynamic> json) {
    return SocialAccount(
      connected: json['connected'] == true,
      pageName: json['page_name'] as String?,
      instagramUsername: json['instagram_username'] as String?,
      profilePictureUrl: json['profile_picture_url'] as String?,
      tokenExpiry: _date(json['token_expiry']),
      connectedSince: _date(json['connected_since']),
      lastSyncAt: _date(json['last_sync_at']),
      lastError: json['last_error'] as String?,
      autoRefresh: json['auto_refresh'] == true,
      adsCapable: json['ads_capable'] == true,
      adAccountName: json['ad_account_name'] as String?,
      adAccountCurrency: json['ad_account_currency'] as String?,
      fbFollowersCount: _intOrNull(json['fb_followers_count']),
      igFollowersCount: _intOrNull(json['ig_followers_count']),
      igMediaCount: _intOrNull(json['ig_media_count']),
    );
  }

  /// A Facebook Page is linked.
  bool get hasFacebookPage => connected && (pageName?.isNotEmpty ?? false);

  /// Instagram publishing goes through the Business account linked to the Page.
  bool get hasInstagram =>
      connected && (instagramUsername?.isNotEmpty ?? false);

  /// Ports `daysUntilExpiry`. Null when there is no token expiry to report.
  int? get daysUntilExpiry {
    final expiry = tokenExpiry;
    if (expiry == null) return null;
    return expiry.difference(DateTime.now()).inDays;
  }
}

/// The caller's `social_share_preferences` row.
class SocialPreferences {
  final bool autoShareProperty;
  final bool autoShareProjects;
  final bool autoShareVideos;
  final bool autoShareReels;
  final bool autoShareBlogs;
  final bool autoSharePromotions;
  final bool autoShareOpenHouses;

  final bool fbEnabled;
  final bool igEnabled;
  final bool igFeed;
  final bool igReel;
  final bool fbStory;
  final bool igStory;

  final String? defaultCaptionTemplate;
  final List<String> defaultHashtags;
  final String? defaultCta;
  final String autoShareRule;

  const SocialPreferences({
    this.autoShareProperty = false,
    this.autoShareProjects = false,
    this.autoShareVideos = false,
    this.autoShareReels = false,
    this.autoShareBlogs = false,
    this.autoSharePromotions = false,
    this.autoShareOpenHouses = false,
    this.fbEnabled = true,
    this.igEnabled = true,
    this.igFeed = true,
    this.igReel = false,
    this.fbStory = false,
    this.igStory = false,
    this.defaultCaptionTemplate,
    this.defaultHashtags = const [],
    this.defaultCta,
    this.autoShareRule = 'all',
  });

  /// `DEFAULT_PREFERENCES` — what React returns when no row exists.
  static const SocialPreferences defaults = SocialPreferences();

  factory SocialPreferences.fromJson(Map<String, dynamic> json) {
    return SocialPreferences(
      autoShareProperty: json['auto_share_property'] == true,
      autoShareProjects: json['auto_share_projects'] == true,
      autoShareVideos: json['auto_share_videos'] == true,
      autoShareReels: json['auto_share_reels'] == true,
      autoShareBlogs: json['auto_share_blogs'] == true,
      autoSharePromotions: json['auto_share_promotions'] == true,
      autoShareOpenHouses: json['auto_share_open_houses'] == true,
      fbEnabled: json['fb_enabled'] == true,
      igEnabled: json['ig_enabled'] == true,
      igFeed: json['ig_feed'] == true,
      igReel: json['ig_reel'] == true,
      fbStory: json['fb_story'] == true,
      igStory: json['ig_story'] == true,
      defaultCaptionTemplate: json['default_caption_template'] as String?,
      defaultHashtags: _stringList(json['default_hashtags']),
      defaultCta: json['default_cta'] as String?,
      autoShareRule: '${json['auto_share_rule'] ?? 'all'}',
    );
  }

  /// The design's "Auto-share rule" row shows prose, not the stored token.
  String get autoShareRuleLabel => switch (autoShareRule) {
        'all' => 'Every item',
        'manual' => 'Only when I choose',
        final other => other,
      };
}

/// One row of `social_share_logs`.
class ShareLog {
  final String id;
  final String contentType;
  final String? contentId;
  final String platform;
  final String status;
  final String? permalink;
  final String? caption;
  final String? error;
  final DateTime? createdAt;
  final DateTime? sharedAt;

  const ShareLog({
    required this.id,
    required this.contentType,
    required this.platform,
    required this.status,
    this.contentId,
    this.permalink,
    this.caption,
    this.error,
    this.createdAt,
    this.sharedAt,
  });

  factory ShareLog.fromJson(Map<String, dynamic> json) {
    return ShareLog(
      id: '${json['id'] ?? ''}',
      contentType: '${json['content_type'] ?? ''}',
      contentId: json['content_id'] as String?,
      platform: '${json['platform'] ?? ''}',
      status: '${json['status'] ?? ''}',
      permalink: json['permalink'] as String?,
      caption: json['caption'] as String?,
      error: json['error'] as String?,
      createdAt: _date(json['created_at']),
      sharedAt: _date(json['shared_at']),
    );
  }

  bool get succeeded => status == 'success';
}

/// One row of `social_ad_campaigns`.
class AdCampaign {
  final String id;
  final String name;
  final String status;
  final String? effectiveStatus;
  final String objective;
  final int? dailyBudgetMinor;
  final String? currency;
  final int spendMinor;
  final int impressions;
  final int clicks;
  final int leadsCount;
  final int? cplMinor;
  final DateTime? createdAt;

  const AdCampaign({
    required this.id,
    required this.name,
    required this.status,
    required this.objective,
    this.effectiveStatus,
    this.dailyBudgetMinor,
    this.currency,
    this.spendMinor = 0,
    this.impressions = 0,
    this.clicks = 0,
    this.leadsCount = 0,
    this.cplMinor,
    this.createdAt,
  });

  factory AdCampaign.fromJson(Map<String, dynamic> json) {
    return AdCampaign(
      id: '${json['id'] ?? ''}',
      name: '${json['name'] ?? ''}',
      status: '${json['status'] ?? ''}',
      effectiveStatus: json['effective_status'] as String?,
      objective: '${json['objective'] ?? ''}',
      dailyBudgetMinor: _intOrNull(json['daily_budget_minor']),
      currency: json['currency'] as String?,
      spendMinor: _int(json['spend_minor']),
      impressions: _int(json['impressions']),
      clicks: _int(json['clicks']),
      leadsCount: _int(json['leads_count']),
      cplMinor: _intOrNull(json['cpl_minor']),
      createdAt: _date(json['created_at']),
    );
  }

  String get spendDisplay => formatMinorAmount(spendMinor, currency: currency);

  String get dailyBudgetDisplay =>
      formatMinorAmount(dailyBudgetMinor, currency: currency);

  /// Meta's own view of the campaign wins when present, matching React.
  String get displayStatus => effectiveStatus ?? status;
}

/// One row of `social_ad_leads`.
///
/// Carries the submitter's contact details. RLS scopes the table to the owning
/// user, and this is the surface whose whole purpose is showing them their own
/// leads — but nothing here is ever logged or sent anywhere else.
class AdLead {
  final String id;
  final String? campaignId;
  final String? fullName;
  final String? email;
  final String? phone;
  final String status;
  final DateTime? createdAt;

  const AdLead({
    required this.id,
    required this.status,
    this.campaignId,
    this.fullName,
    this.email,
    this.phone,
    this.createdAt,
  });

  factory AdLead.fromJson(Map<String, dynamic> json) {
    return AdLead(
      id: '${json['id'] ?? ''}',
      campaignId: json['campaign_id'] as String?,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      status: '${json['status'] ?? 'new'}',
      createdAt: _date(json['meta_created_time'] ?? json['created_at']),
    );
  }

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return email ?? phone ?? 'Unnamed lead';
  }

  /// True when [query] matches the name, email or phone — the design's search.
  bool matches(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return (fullName ?? '').toLowerCase().contains(q) ||
        (email ?? '').toLowerCase().contains(q) ||
        (phone ?? '').toLowerCase().contains(q);
  }
}

/// The Analytics tab's aggregate, computed exactly as `getAnalytics` does.
class SocialAnalytics {
  final int totalShares;
  final int today;
  final int week;
  final int month;
  final int failed;
  final int pending;
  final int facebook;
  final int instagram;
  final List<ShareLog> recent;
  final List<TopSharedContent> topContent;

  const SocialAnalytics({
    this.totalShares = 0,
    this.today = 0,
    this.week = 0,
    this.month = 0,
    this.failed = 0,
    this.pending = 0,
    this.facebook = 0,
    this.instagram = 0,
    this.recent = const [],
    this.topContent = const [],
  });

  static const SocialAnalytics empty = SocialAnalytics();

  /// Derives the aggregate from the caller's share logs.
  ///
  /// A direct port: successes drive the totals and the windows, failures are
  /// counted across all rows, and `pending` comes from the queue rather than
  /// the logs, so it is passed in.
  factory SocialAnalytics.fromLogs(List<ShareLog> logs, {required int pending}) {
    final successRows = logs.where((l) => l.succeeded).toList();
    final now = DateTime.now();

    bool within(ShareLog log, int days) {
      final created = log.createdAt;
      if (created == null) return false;
      return now.difference(created).inDays <= days;
    }

    final counts = <String, TopSharedContent>{};
    for (final row in successRows) {
      final key = '${row.contentType}:${row.contentId}';
      final existing = counts[key];
      counts[key] = TopSharedContent(
        contentType: row.contentType,
        contentId: row.contentId,
        count: (existing?.count ?? 0) + 1,
      );
    }

    final top = counts.values.toList()
      ..sort((a, b) => b.count.compareTo(a.count));

    return SocialAnalytics(
      totalShares: successRows.length,
      today: successRows.where((l) => within(l, 1)).length,
      week: successRows.where((l) => within(l, 7)).length,
      month: successRows.where((l) => within(l, 30)).length,
      failed: logs.where((l) => l.status == 'failed').length,
      pending: pending,
      facebook: successRows.where((l) => l.platform == 'facebook').length,
      instagram: successRows.where((l) => l.platform == 'instagram').length,
      recent: logs.take(20).toList(),
      topContent: top.take(5).toList(),
    );
  }

  bool get hasPublished => totalShares > 0;
}

class TopSharedContent {
  final String contentType;
  final String? contentId;
  final int count;

  const TopSharedContent({
    required this.contentType,
    required this.count,
    this.contentId,
  });
}
