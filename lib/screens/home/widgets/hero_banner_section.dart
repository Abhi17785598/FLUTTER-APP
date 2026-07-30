import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/navigation/banner_destination_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/banner_destination.dart';
import '../../../models/property_model.dart';
import '../../../providers/property_provider.dart';

class _BannerData {
  const _BannerData({
    required this.imageUrl,
    required this.eyebrow,
    required this.headline,
    required this.accentWord,
    required this.subtext,
    required this.destination,
  });

  final String imageUrl;
  final String eyebrow;
  final String headline;
  final String accentWord;
  final String subtext;
  final BannerDestination destination;
}

/// The Home hero carousel — full-bleed photo cards, "FEATURED" pill, page
/// counter, a large headline with one accent word, and a white CTA pill, per
/// the reference design. One card per `BannerDestinationType` so every
/// resolver branch (including the graceful "coming soon" ones) is exercised
/// at least once. Every tap — card or CTA — hands a `BannerDestination` to
/// `BannerDestinationResolver`; nothing here calls `Navigator` directly.
class HeroBannerSection extends StatefulWidget {
  const HeroBannerSection({super.key});

  @override
  State<HeroBannerSection> createState() => _HeroBannerSectionState();
}

class _HeroBannerSectionState extends State<HeroBannerSection>
    with AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return false;
      final total = _bannerCount;
      if (total > 1 && _pageController.hasClients) {
        final next = (_currentPage + 1) % total;
        await _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      }
      return mounted;
    });
  }

  int _bannerCount = 5;

  List<_BannerData> _buildBanners(BuildContext context) {
    final properties = context.watch<PropertyProvider>().properties;
    final PropertyModel? featured = properties.isEmpty
        ? null
        : properties.firstWhere(
            (p) => p.isFeatured,
            orElse: () => properties.first,
          );

    return [
      _BannerData(
        imageUrl:
            featured?.imageUrl ??
            'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=800&q=80',
        eyebrow: 'Featured Listing',
        headline: 'Discover Your',
        accentWord: 'Dream Home.',
        subtext: featured != null
            ? 'Featured now: ${featured.title} · ${featured.location}'
            : 'Premium properties, trusted by thousands',
        destination: featured != null
            ? BannerDestination.property(featured.id)
            : const BannerDestination.collection(),
      ),
      const _BannerData(
        imageUrl:
            'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=800&q=80',
        eyebrow: 'Luxury Collection',
        headline: 'Live in',
        accentWord: 'Style.',
        subtext: 'Handpicked premium residences, 50+ cities',
        destination: BannerDestination.collection(budgetMin: 20000000),
      ),
      const _BannerData(
        imageUrl:
            'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=800&q=80',
        eyebrow: 'New Launches',
        headline: 'Your Dream',
        accentWord: 'Home.',
        subtext: 'Exclusive pre-launch deals available now',
        destination: BannerDestination.project(hashtag: 'newlaunch'),
      ),
      const _BannerData(
        imageUrl:
            'https://images.unsplash.com/photo-1503387762-592deb58ef4e?w=800&q=80',
        eyebrow: 'Builder Spotlight',
        headline: 'Trusted',
        accentWord: 'Builders.',
        subtext: 'Verified developers, verified projects',
        destination: BannerDestination.builder(),
      ),
      const _BannerData(
        imageUrl:
            'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=80',
        eyebrow: 'PropCID Magazine',
        headline: 'City Living',
        accentWord: 'Guides.',
        subtext: 'Neighborhood guides & smart buying tips',
        // Placeholder destination — points at the reserved documentation
        // domain until a real magazine/blog URL exists.
        destination: BannerDestination.externalUrl(
          'https://example.com/propcid-magazine',
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final banners = _buildBanners(context);
    _bannerCount = banners.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: banners.length,
            itemBuilder: (context, i) => _BannerCard(
              data: banners[i],
              pageController: _pageController,
              index: i,
              total: banners.length,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(banners.length, (i) {
              final active = i == _currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ),
        // Gradient bleed: the brand tint fades out under the dot row instead
        // of ending on a hard edge, so the next section doesn't read as a
        // separate box dropped underneath.
        Container(
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryLight.withOpacity(0.5),
                AppColors.primaryLight.withOpacity(0),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.data,
    required this.pageController,
    required this.index,
    required this.total,
  });

  final _BannerData data;
  final PageController pageController;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () =>
            BannerDestinationResolver.navigate(context, data.destination),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Subtle parallax: the photo drifts opposite the swipe as the
              // page settles, driven directly by the PageController (no
              // extra AnimationController needed).
              AnimatedBuilder(
                animation: pageController,
                builder: (context, child) {
                  double page = index.toDouble();
                  if (pageController.hasClients &&
                      pageController.position.haveDimensions) {
                    page = pageController.page ?? index.toDouble();
                  }
                  final delta = (page - index).clamp(-1.0, 1.0);
                  return OverflowBox(
                    maxWidth: double.infinity,
                    child: Transform.translate(
                      offset: Offset(-delta * 24, 0),
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width - 32 + 48,
                        child: child,
                      ),
                    ),
                  );
                },
                child: CachedNetworkImage(
                  imageUrl: data.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      Container(color: AppColors.primaryLight),
                  errorWidget: (context, url, error) =>
                      Container(color: AppColors.primary.withOpacity(0.25)),
                ),
              ),
              // Bottom scrim for text legibility.
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                      Colors.black.withOpacity(0.75),
                    ],
                    stops: const [0.35, 0.7, 1.0],
                  ),
                ),
              ),
              // FEATURED pill.
              Positioned(
                top: 14,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'FEATURED',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ),
              // Page counter.
              Positioned(
                top: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${index + 1} / $total',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Text + CTA.
              Positioned(
                left: 18,
                right: 18,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.eyebrow.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.75),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                        ),
                        children: [
                          TextSpan(text: '${data.headline} '),
                          TextSpan(
                            text: data.accentWord,
                            style: const TextStyle(color: Color(0xFFC9BBFF)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.subtext,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explore Properties',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
