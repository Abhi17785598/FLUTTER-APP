import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

/// One feature bullet — a small icon medallion plus a 1-2 word label,
/// rendered either as a row (slide 1) or a column (slides 2/3) of three.
class _FeaturePoint {
  final IconData icon;
  final String label;
  const _FeaturePoint(this.icon, this.label);
}

/// Which stylised "app preview" floats over the photo, if any. `none` for
/// the first slide (which instead floats a property-card + checklist), a
/// simplified property-list screen for the second, and a simplified chat
/// screen for the third — a phone silhouette built from plain widgets, not
/// an attempt at a photorealistic device render.
enum _MockupKind { none, listing, chat }

class _OnboardingSlide {
  final String titleTop;
  final String titleAccent;
  final String subtitle;
  final String imageUrl;
  final List<_FeaturePoint> features;
  final Axis featuresAxis;
  final _MockupKind mockup;

  const _OnboardingSlide({
    required this.titleTop,
    required this.titleAccent,
    required this.subtitle,
    required this.imageUrl,
    required this.features,
    required this.featuresAxis,
    required this.mockup,
  });
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int currentIndex = 0;

  // Same three photos already vetted and in active use elsewhere in this app
  // (the Home hero carousel) — reused rather than introducing new remote
  // assets. Copy/icons match the reference design exactly.
  final List<_OnboardingSlide> slides = const [
    _OnboardingSlide(
      titleTop: 'FIND WITH',
      titleAccent: 'CONFIDENCE',
      subtitle: 'Discover properties with verified details.',
      imageUrl:
          'https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=900&q=80',
      features: [
        _FeaturePoint(Icons.shield_outlined, 'Verified\nListings'),
        _FeaturePoint(Icons.location_on_outlined, 'Accurate\nLocations'),
        _FeaturePoint(Icons.home_outlined, 'Trusted\nInformation'),
      ],
      featuresAxis: Axis.horizontal,
      mockup: _MockupKind.none,
    ),
    _OnboardingSlide(
      titleTop: 'LIST WITH',
      titleAccent: 'EASE',
      subtitle: 'Showcase your property to the right people.',
      imageUrl:
          'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=900&q=80',
      features: [
        _FeaturePoint(Icons.home_work_outlined, 'Easy Listing'),
        _FeaturePoint(Icons.campaign_outlined, 'Reach Serious Buyers'),
        _FeaturePoint(Icons.visibility_outlined, 'Get More Visibility'),
      ],
      featuresAxis: Axis.vertical,
      mockup: _MockupKind.listing,
    ),
    _OnboardingSlide(
      titleTop: 'CONNECT',
      titleAccent: 'DIRECTLY',
      subtitle: 'Connect with owners, buyers and sellers.',
      imageUrl:
          'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=900&q=80',
      features: [
        _FeaturePoint(Icons.chat_bubble_outline_rounded, 'Chat Directly'),
        _FeaturePoint(Icons.calendar_month_outlined, 'Schedule Site Visits'),
        _FeaturePoint(Icons.groups_outlined, 'Property Opportunities'),
      ],
      featuresAxis: Axis.vertical,
      mockup: _MockupKind.chat,
    ),
  ];

  bool get _isLastSlide => currentIndex == slides.length - 1;

  Future<void> finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);

    if (!mounted) return;

    context.read<AuthProvider>().enableNavigation();
  }

  void _onPrimaryPressed() {
    if (_isLastSlide) {
      finishOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: slides.length,
                  onPageChanged: (value) =>
                      setState(() => currentIndex = value),
                  itemBuilder: (context, index) =>
                      _OnboardingSlideVisual(slide: slides[index]),
                ),
                SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 10, 20, 0),
                      child: _SkipChip(onTap: finishOnboarding),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Fixed control strip — page indicator + primary CTA. Deliberately
          // outside the swiping PageView so only the photo/content swipes
          // while this stays put.
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(slides.length, (index) {
                final bool isActive = currentIndex == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: isActive ? 28 : 8,
                  decoration: BoxDecoration(
                    color: isActive ? AppColors.primary : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _onPrimaryPressed,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: AppColors.primaryGlow,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isLastSlide ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One slide's visual: a full-bleed photo with the headline/subtitle/feature
/// bullets overlaid directly on it (top-left, matching the reference), plus
/// whatever floating card(s)/mockup that slide carries.
class _OnboardingSlideVisual extends StatelessWidget {
  const _OnboardingSlideVisual({required this.slide});

  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _SlidePhoto(imageUrl: slide.imageUrl),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Container(width: 28, height: 4, color: AppColors.primary),
                const SizedBox(height: 10),
                Text(
                  slide.titleTop,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: 0.2,
                    color: Colors.black,
                  ),
                ),
                Text(
                  slide.titleAccent,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: 0.2,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  slide.subtitle,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                _FeatureRow(features: slide.features, axis: slide.featuresAxis),
              ],
            ),
          ),
        ),
        ..._floatingContentFor(slide),
      ],
    );
  }

  /// The extra floating card(s)/mockup, positioned by fraction of the
  /// slide's own size so the layout holds up across phone sizes.
  List<Widget> _floatingContentFor(_OnboardingSlide slide) {
    switch (slide.mockup) {
      case _MockupKind.none:
        return [
          const Positioned(
            left: 24,
            bottom: 108,
            child: _PropertyPreviewCard(),
          ),
          const Positioned(
            right: 20,
            bottom: 210,
            child: _TrustChecklistCard(),
          ),
        ];
      case _MockupKind.listing:
        return const [
          Positioned(
            right: 24,
            bottom: 96,
            child: _PhoneMockup(kind: _MockupKind.listing),
          ),
        ];
      case _MockupKind.chat:
        return const [
          Positioned(
            right: 20,
            bottom: 96,
            child: _PhoneMockup(kind: _MockupKind.chat),
          ),
          Positioned(left: 24, bottom: 110, child: _SiteVisitCard()),
        ];
    }
  }
}

/// Three feature bullets — a row of three (slide 1) or a stacked column
/// (slides 2/3), each a small orange-icon medallion plus a short label.
class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.features, required this.axis});

  final List<_FeaturePoint> features;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    if (axis == Axis.horizontal) {
      return Row(
        children: [
          for (final f in features) ...[
            Expanded(
              child: _FeatureBullet(feature: f, axis: axis),
            ),
          ],
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final f in features) ...[
          _FeatureBullet(feature: f, axis: axis),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.feature, required this.axis});

  final _FeaturePoint feature;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final medallion = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(feature.icon, size: 16, color: AppColors.primary),
    );

    if (axis == Axis.horizontal) {
      return Column(
        children: [
          medallion,
          const SizedBox(height: 6),
          Text(
            feature.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
              height: 1.25,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        medallion,
        const SizedBox(width: 10),
        Text(
          feature.label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

/// A small "floating card" chrome shared by every overlay widget below —
/// white, rounded, soft-shadowed, matching the reference's UI-preview cards.
BoxDecoration _floatCardDecoration({double radius = 14}) => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ],
);

/// Slide 1's floating property preview — "3 BHK Villa · Greater Noida ·
/// ₹1.25 Cr · Verified".
class _PropertyPreviewCard extends StatelessWidget {
  const _PropertyPreviewCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(10),
      decoration: _floatCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.home_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '3 BHK Villa',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 10,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        'Greater Noida',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Text(
                      '₹1.25 Cr',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.verified_rounded,
                      size: 12,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Verified',
                      style: TextStyle(fontSize: 9.5, color: AppColors.success),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slide 1's floating "trust checklist" — Verified Documents / Location
/// Confirmed / Genuine Owner, each with a green check.
class _TrustChecklistCard extends StatelessWidget {
  const _TrustChecklistCard();

  static const _items = [
    (Icons.description_outlined, 'Verified Documents'),
    (Icons.location_on_outlined, 'Location Confirmed'),
    (Icons.person_outline_rounded, 'Genuine Owner'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _floatCardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _items.length; i++) ...[
            if (i > 0) const SizedBox(height: 7),
            Row(
              children: [
                Icon(_items[i].$1, size: 13, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _items[i].$2,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: AppColors.success,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Slide 3's floating "Site Visit" card.
class _SiteVisitCard extends StatelessWidget {
  const _SiteVisitCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: _floatCardDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 15,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Site Visit',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
              Text(
                'Sat, 20 Sep · 11:00 AM',
                style: TextStyle(fontSize: 9.5, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A stylised phone silhouette showing a simplified in-app screen — never an
/// attempt at a photorealistic device render, just enough visual shorthand
/// ("this is what the app looks like") to match the reference's intent.
class _PhoneMockup extends StatelessWidget {
  const _PhoneMockup({required this.kind});

  final _MockupKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 148,
      height: 260,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          color: Colors.white,
          child: kind == _MockupKind.chat
              ? const _ChatMockupScreen()
              : const _ListingMockupScreen(),
        ),
      ),
    );
  }
}

class _ListingMockupScreen extends StatelessWidget {
  const _ListingMockupScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          color: AppColors.primaryLight,
          child: const Text(
            'Post Property',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _MockListingRow(status: 'For Sale'),
              SizedBox(height: 8),
              _MockListingRow(status: 'For Rent'),
              SizedBox(height: 8),
              _MockListingRow(status: 'New'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MockListingRow extends StatelessWidget {
  const _MockListingRow({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Icon(
              Icons.image_outlined,
              size: 12,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(height: 5, width: 46, color: Colors.grey.shade400),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status,
                    style: const TextStyle(
                      fontSize: 6.5,
                      color: AppColors.success,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMockupScreen extends StatelessWidget {
  const _ChatMockupScreen();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
          color: AppColors.primaryLight,
          child: Row(
            children: [
              const CircleAvatar(radius: 9, backgroundColor: AppColors.primary),
              const SizedBox(width: 6),
              Container(height: 6, width: 54, color: Colors.grey.shade400),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            physics: const NeverScrollableScrollPhysics(),
            children: const [
              _ChatBubble(isMine: false, width: 78),
              SizedBox(height: 6),
              _ChatBubble(isMine: false, width: 60),
              SizedBox(height: 6),
              _ChatBubble(isMine: true, width: 70),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.isMine, required this.width});
  final bool isMine;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: width,
        height: 16,
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : const Color(0xFFF0F0F2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

class _SlidePhoto extends StatelessWidget {
  const _SlidePhoto({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) =>
              const ColoredBox(color: AppColors.primaryLight),
          errorWidget: (context, url, error) =>
              const ColoredBox(color: AppColors.primaryLight),
        ),
        // A light wash near the top (so the headline reads clearly over any
        // part of the photo) fading to a soft white base near the bottom,
        // where the page dots/CTA sit.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xCCFFFFFF),
                Color(0x66FFFFFF),
                Color(0x00FFFFFF),
                Color(0x00FFFFFF),
                Color(0xB3FFFFFF),
              ],
              stops: [0.0, 0.16, 0.32, 0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

/// The always-visible "Skip" action — a frosted glass pill so it reads
/// clearly over any part of the photo behind it, matching the same glass
/// language used across the rest of the app.
class _SkipChip extends StatelessWidget {
  const _SkipChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.85),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
          ),
          child: const Text(
            'Skip',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
