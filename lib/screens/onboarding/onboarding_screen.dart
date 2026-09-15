import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int currentIndex = 0;

  // Clean, editorial real-estate photography — no text/UI baked into the
  // image itself, so it can sit behind our own typography without
  // duplicating anything. Same three photos already vetted and in active
  // use elsewhere in this app (the Home hero carousel), reused rather than
  // introducing new remote assets. Titles/subtitles/icons/colours are the
  // app's original onboarding copy, unchanged.
  final List<Map<String, dynamic>> slides = [
    {
      "title": "Find Your Dream Home",
      "subtitle": "Browse thousands of verified properties across India",
      "icon": Icons.home_work_outlined,
      "color": AppColors.primary,
      "imageUrl":
          "https://images.unsplash.com/photo-1568605114967-8130f3a36994?w=900&q=80",
    },
    {
      "title": "Post Property Easily",
      "subtitle": "Upload photos, details and connect with buyers instantly",
      "icon": Icons.add_business_outlined,
      "color": const Color(0xFF10B981),
      "imageUrl":
          "https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=900&q=80",
    },
    {
      "title": "Schedule Site Visits",
      "subtitle": "Connect with owners and visit your future property",
      "icon": Icons.calendar_month_outlined,
      "color": const Color(0xFFC2410C),
      "imageUrl":
          "https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=900&q=80",
    },
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
      // Matches the bottom sheet's own colour so there is no flash of a
      // different background while the first photo loads.
      backgroundColor: Colors.white,
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
          // outside the swiping PageView (same white surface the per-slide
          // sheet already ends on, so the two read as one continuous panel)
          // so only the photo/title/subtitle swipe while this stays put.
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
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
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
                      child: Text(
                        _isLastSlide ? "Get Started" : "Next",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
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

const double _kBadgeDiameter = 64;

/// One slide's visual: a full-bleed real-estate photo, a soft scrim, a
/// rising white content sheet with title/subtitle, and a small icon
/// medallion on the seam between them — no page-indicator or CTA here,
/// those are the fixed strip in `_OnboardingScreenState`.
class _OnboardingSlideVisual extends StatelessWidget {
  const _OnboardingSlideVisual({required this.slide});

  final Map<String, dynamic> slide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final photoHeight = constraints.maxHeight * 0.56;
        final sheetTop = photoHeight - 26;
        final badgeTop = photoHeight - 34;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: photoHeight,
              child: _SlidePhoto(imageUrl: slide['imageUrl'] as String),
            ),
            Positioned(
              top: sheetTop,
              left: 0,
              right: 0,
              bottom: 0,
              child: _SlideSheet(
                title: slide['title'] as String,
                subtitle: slide['subtitle'] as String,
              ),
            ),
            Positioned(
              top: badgeTop,
              left: 0,
              right: 0,
              child: Center(
                child: _SlideBadge(
                  icon: slide['icon'] as IconData,
                  color: slide['color'] as Color,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SlidePhoto extends StatelessWidget {
  const _SlidePhoto({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
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
          // A gentle top wash (for the Skip chip's contrast) and a fade into
          // white at the very bottom, so the photo meets the sheet below as
          // a soft blend rather than a hard edge.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x33000000),
                  Color(0x00000000),
                  Color(0x00000000),
                  Color(0xFFFFFFFF),
                ],
                stops: [0.0, 0.22, 0.82, 1.0],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideSheet extends StatelessWidget {
  const _SlideSheet({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 46, 28, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The slide's small icon medallion — a compact badge on the photo/sheet
/// seam.
class _SlideBadge extends StatelessWidget {
  const _SlideBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _kBadgeDiameter,
      width: _kBadgeDiameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(icon, size: 30, color: color),
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
            "Skip",
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
