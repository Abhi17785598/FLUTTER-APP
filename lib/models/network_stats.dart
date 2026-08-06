/// The four KPIs the Network hub shows above its navigation cards.
///
/// Mirrors `NetworkStats` in `features/network/NetworkDashboard.tsx` field for
/// field, including [totalReferrals] — React hardcodes that to `0` with the
/// comment "Temporarily disable this query to fix TS error", so a real referral
/// count has no backend implementation on either platform yet. Reporting the
/// same `0` keeps the two portals consistent instead of inventing a number.
class NetworkStats {
  final int totalNetworks;
  final int activeLeads;
  final int totalReferrals;
  final double monthlyCommissions;

  const NetworkStats({
    this.totalNetworks = 0,
    this.activeLeads = 0,
    this.totalReferrals = 0,
    this.monthlyCommissions = 0,
  });

  /// The zeroed state the provider starts in, so the hub can lay out its grid
  /// before the first query returns.
  static const NetworkStats empty = NetworkStats();

  /// `₹24,500` — Indian digit grouping (last three, then pairs), matching how
  /// the rest of the app renders rupee amounts.
  ///
  /// Not reusing `PropertyModel.formatIndianPrice`: that one abbreviates to
  /// `Cr`/`L` for listing prices and drops the separators below a lakh, which
  /// would render a commission of 24500 as `₹24500`.
  String get monthlyCommissionsDisplay {
    final whole = monthlyCommissions.round().abs();
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

    final sign = monthlyCommissions < 0 ? '-' : '';
    return '$sign₹$grouped';
  }
}
