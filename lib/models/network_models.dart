/// Read-only models for the Network leaf screens.
///
/// Column names come from the live `builder_networks`, `network_leads`,
/// `network_referrals`, `network_commissions`, `network_channels` and
/// `network_performance` tables, verified against `information_schema`.
///
/// Money note: unlike the billing and social-ads tables, every amount here is
/// `numeric` in **rupees**, not an integer in minor units. React sums
/// `network_commissions.amount` directly with no division, so these models do
/// the same. Getting this backwards would misstate every figure by 100×.
library;

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.tryParse('$value');

double _double(dynamic value) =>
    value == null ? 0 : (double.tryParse('$value') ?? 0);

double? _doubleOrNull(dynamic value) =>
    value == null ? null : double.tryParse('$value');

int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;

/// `24500` → `₹24,500` — Indian digit grouping, whole rupees.
String formatRupeeAmount(num amount) {
  final whole = amount.round().abs();
  final digits = whole.toString();

  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final lastThree = digits.substring(digits.length - 3);
    var rest = digits.substring(0, digits.length - 3);
    final pairs = <String>[];
    while (rest.length > 2) {
      pairs.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) pairs.insert(0, rest);
    grouped = '${pairs.join(',')},$lastThree';
  }

  return '${amount < 0 ? '-' : ''}₹$grouped';
}

/// One `builder_networks` row — a connection between a builder and a member.
///
/// The caller may be either side, which is why React selects with
/// `.or(member_id.eq.X, builder_id.eq.X)`; [isBuilderSide] records which.
class NetworkMembership {
  final String id;
  final String builderId;
  final String memberId;
  final String memberType;
  final String status;
  final bool verified;
  final double? commissionRate;
  final bool autoConvertLeads;
  final DateTime? createdAt;

  /// True when the caller owns the network rather than belonging to it.
  final bool isBuilderSide;

  const NetworkMembership({
    required this.id,
    required this.builderId,
    required this.memberId,
    required this.memberType,
    required this.status,
    this.verified = false,
    this.commissionRate,
    this.autoConvertLeads = false,
    this.createdAt,
    this.isBuilderSide = false,
  });

  factory NetworkMembership.fromJson(
    Map<String, dynamic> json, {
    required String viewerId,
  }) {
    final builderId = '${json['builder_id'] ?? ''}';
    return NetworkMembership(
      id: '${json['id'] ?? ''}',
      builderId: builderId,
      memberId: '${json['member_id'] ?? ''}',
      memberType: '${json['member_type'] ?? ''}',
      // Nullable in the schema; React treats a null status as pending.
      status: '${json['status'] ?? 'pending'}',
      verified: json['verified'] == true,
      commissionRate: _doubleOrNull(json['commission_rate']),
      autoConvertLeads: json['auto_convert_leads'] == true,
      createdAt: _date(json['created_at']),
      isBuilderSide: builderId == viewerId,
    );
  }

  bool get isAccepted => status == 'accepted';

  /// "Broker" / "Influencer" — the stored value is a lowercase token.
  String get memberTypeLabel => memberType.isEmpty
      ? 'Member'
      : memberType[0].toUpperCase() + memberType.substring(1).toLowerCase();

  /// `2.5` → `2.5%`. Null when the connection carries no rate.
  String? get commissionRateLabel {
    final rate = commissionRate;
    if (rate == null) return null;
    final trimmed = rate == rate.roundToDouble()
        ? rate.round().toString()
        : rate.toStringAsFixed(1);
    return '$trimmed%';
  }
}

/// One `network_leads` row.
class NetworkLead {
  final String id;
  final String leadType;
  final String priority;
  final String status;
  final String assignmentMethod;
  final String? assignedMemberId;
  final bool autoAssigned;
  final String? notes;
  final DateTime? assignedAt;
  final DateTime? createdAt;

  const NetworkLead({
    required this.id,
    required this.leadType,
    required this.priority,
    required this.status,
    required this.assignmentMethod,
    this.assignedMemberId,
    this.autoAssigned = false,
    this.notes,
    this.assignedAt,
    this.createdAt,
  });

  factory NetworkLead.fromJson(Map<String, dynamic> json) {
    return NetworkLead(
      id: '${json['id'] ?? ''}',
      leadType: '${json['lead_type'] ?? ''}',
      priority: '${json['priority'] ?? ''}',
      status: '${json['status'] ?? ''}',
      assignmentMethod: '${json['assignment_method'] ?? ''}',
      assignedMemberId: json['assigned_member_id'] as String?,
      autoAssigned: json['auto_assigned'] == true,
      notes: json['notes'] as String?,
      assignedAt: _date(json['assigned_at']),
      createdAt: _date(json['created_at']),
    );
  }
}

/// The four status counts on the My Leads screen.
///
/// The design shows Pending / Assigned / Contacted / Converted, which are the
/// `network_leads.status` values React filters on.
class LeadStatusCounts {
  final int pending;
  final int assigned;
  final int contacted;
  final int converted;

  const LeadStatusCounts({
    this.pending = 0,
    this.assigned = 0,
    this.contacted = 0,
    this.converted = 0,
  });

  static const LeadStatusCounts empty = LeadStatusCounts();

  factory LeadStatusCounts.fromLeads(List<NetworkLead> leads) {
    int count(String status) => leads.where((l) => l.status == status).length;
    return LeadStatusCounts(
      pending: count('pending'),
      assigned: count('assigned'),
      contacted: count('contacted'),
      converted: count('converted'),
    );
  }

  int get total => pending + assigned + contacted + converted;
}

/// One `network_referrals` row.
class NetworkReferral {
  final String id;
  final String referralType;
  final String status;
  final String commissionStatus;
  final double? commissionAmount;
  final double? commissionRate;
  final double? conversionValue;
  final DateTime? conversionDate;
  final DateTime? createdAt;

  const NetworkReferral({
    required this.id,
    required this.referralType,
    required this.status,
    required this.commissionStatus,
    this.commissionAmount,
    this.commissionRate,
    this.conversionValue,
    this.conversionDate,
    this.createdAt,
  });

  factory NetworkReferral.fromJson(Map<String, dynamic> json) {
    return NetworkReferral(
      id: '${json['id'] ?? ''}',
      referralType: '${json['referral_type'] ?? ''}',
      status: '${json['status'] ?? ''}',
      commissionStatus: '${json['commission_status'] ?? ''}',
      commissionAmount: _doubleOrNull(json['commission_amount']),
      commissionRate: _doubleOrNull(json['commission_rate']),
      conversionValue: _doubleOrNull(json['conversion_value']),
      conversionDate: _date(json['conversion_date']),
      createdAt: _date(json['created_at']),
    );
  }

  bool get isConverted => status == 'converted';
}

/// One `network_commissions` row.
class NetworkCommission {
  final String id;
  final String commissionType;
  final double amount;
  final String status;
  final String? description;
  final DateTime? paymentDate;
  final DateTime? createdAt;

  const NetworkCommission({
    required this.id,
    required this.commissionType,
    required this.amount,
    required this.status,
    this.description,
    this.paymentDate,
    this.createdAt,
  });

  factory NetworkCommission.fromJson(Map<String, dynamic> json) {
    return NetworkCommission(
      id: '${json['id'] ?? ''}',
      commissionType: '${json['commission_type'] ?? ''}',
      amount: _double(json['amount']),
      status: '${json['status'] ?? ''}',
      description: json['description'] as String?,
      paymentDate: _date(json['payment_date']),
      createdAt: _date(json['created_at']),
    );
  }

  /// A commission counts as paid out once it has been marked paid.
  bool get isPaid => status == 'paid';

  String get amountDisplay => formatRupeeAmount(amount);
}

/// The four KPIs on the Referrals ▸ Overview sub-tab.
///
/// The design labels them Total Referrals / Converted / Total Commissions /
/// Paid Out — all derivable from the two lists, so nothing here is invented.
class ReferralSummary {
  final int totalReferrals;
  final int converted;
  final double totalCommissions;
  final double paidOut;

  const ReferralSummary({
    this.totalReferrals = 0,
    this.converted = 0,
    this.totalCommissions = 0,
    this.paidOut = 0,
  });

  static const ReferralSummary empty = ReferralSummary();

  factory ReferralSummary.from({
    required List<NetworkReferral> referrals,
    required List<NetworkCommission> commissions,
  }) {
    return ReferralSummary(
      totalReferrals: referrals.length,
      converted: referrals.where((r) => r.isConverted).length,
      totalCommissions:
          commissions.fold<double>(0, (sum, c) => sum + c.amount),
      paidOut: commissions
          .where((c) => c.isPaid)
          .fold<double>(0, (sum, c) => sum + c.amount),
    );
  }

  String get totalCommissionsDisplay => formatRupeeAmount(totalCommissions);
  String get paidOutDisplay => formatRupeeAmount(paidOut);
}

/// One `network_performance` row — a scored period per member.
class NetworkPerformance {
  final String id;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final int leadsReceived;
  final int leadsConverted;
  final int referralsMade;
  final int referralsConverted;
  final double? conversionRate;
  final double? performanceScore;

  const NetworkPerformance({
    required this.id,
    this.periodStart,
    this.periodEnd,
    this.leadsReceived = 0,
    this.leadsConverted = 0,
    this.referralsMade = 0,
    this.referralsConverted = 0,
    this.conversionRate,
    this.performanceScore,
  });

  factory NetworkPerformance.fromJson(Map<String, dynamic> json) {
    return NetworkPerformance(
      id: '${json['id'] ?? ''}',
      periodStart: _date(json['period_start']),
      periodEnd: _date(json['period_end']),
      leadsReceived: _int(json['leads_received']),
      leadsConverted: _int(json['leads_converted']),
      referralsMade: _int(json['referrals_made']),
      referralsConverted: _int(json['referrals_converted']),
      conversionRate: _doubleOrNull(json['conversion_rate']),
      performanceScore: _doubleOrNull(json['performance_score']),
    );
  }
}

/// One `network_channels` row.
class NetworkChannel {
  final String id;
  final String channelId;
  final String channelPurpose;
  final bool isAutoJoin;
  final List<String> memberTypes;
  final DateTime? createdAt;

  const NetworkChannel({
    required this.id,
    required this.channelId,
    required this.channelPurpose,
    this.isAutoJoin = false,
    this.memberTypes = const [],
    this.createdAt,
  });

  factory NetworkChannel.fromJson(Map<String, dynamic> json) {
    final types = json['member_types'];
    return NetworkChannel(
      id: '${json['id'] ?? ''}',
      channelId: '${json['channel_id'] ?? ''}',
      channelPurpose: '${json['channel_purpose'] ?? ''}',
      isAutoJoin: json['is_auto_join'] == true,
      memberTypes: types is List ? types.map((e) => '$e').toList() : const [],
      createdAt: _date(json['created_at']),
    );
  }

  /// `lead_distribution` → `Lead distribution`.
  String get purposeLabel {
    if (channelPurpose.isEmpty) return 'Channel';
    final spaced = channelPurpose.replaceAll('_', ' ');
    return spaced[0].toUpperCase() + spaced.substring(1);
  }
}

/// The Referrals bundle, so one section can feed all four sub-tabs.
class ReferralBundle {
  final List<NetworkReferral> referrals;
  final List<NetworkCommission> commissions;
  final List<NetworkPerformance> performance;

  const ReferralBundle({
    this.referrals = const [],
    this.commissions = const [],
    this.performance = const [],
  });

  static const ReferralBundle empty = ReferralBundle();

  ReferralSummary get summary =>
      ReferralSummary.from(referrals: referrals, commissions: commissions);
}
