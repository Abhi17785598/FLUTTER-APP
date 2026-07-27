import 'package:flutter/material.dart';

/// Single source of truth for the "PropCID Pro" launch-offer copy.
///
/// Both [PremiumLaunchBanner] (home screen) and [PremiumLaunchBottomSheet]
/// (session prompt) read from here so the offer's price/benefits/copy never
/// drift out of sync between the two surfaces.
class LaunchOfferContent {
  LaunchOfferContent._();

  static const String badgeLabel = 'Launch Offer';
  static const String title = 'PropCID Pro for Builders & Brokers';
  static const String priceLabel = '₹299/month';

  /// Raw amount handed to [PaymentMethodScreen] as `amountLabel`.
  static const String amountLabel = '₹299';

  static const String tagline = 'Limited Time Early Access';
  static const String valueProposition =
      'Get discovered faster and close more deals with PropCID Pro.';

  static const List<LaunchOfferBenefit> benefits = [
    LaunchOfferBenefit('Unlimited Property Listings', Icons.all_inclusive_rounded),
    LaunchOfferBenefit('Verified Business Badge', Icons.verified_rounded),
    LaunchOfferBenefit('Priority Search Visibility', Icons.trending_up_rounded),
    LaunchOfferBenefit('Featured Listings', Icons.star_rounded),
    LaunchOfferBenefit('AI Listing Insights (Coming Soon)', Icons.auto_awesome_rounded),
    LaunchOfferBenefit('Early Access to New Features', Icons.rocket_launch_rounded),
    LaunchOfferBenefit('Premium Customer Support', Icons.support_agent_rounded),
  ];
}

class LaunchOfferBenefit {
  final String label;
  final IconData icon;

  const LaunchOfferBenefit(this.label, this.icon);
}
