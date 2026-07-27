import 'package:flutter/material.dart';
import 'dart:math' as math;

// ─── Data model ───────────────────────────────────────────────────────────────

class _BannerData {
  final String imageUrl;
  final String headline;
  final String accentWord;
  final String eyebrow;
  final String subtext;
  final List<_StatItem> stats;

  const _BannerData({
    required this.imageUrl,
    required this.headline,
    required this.accentWord,
    required this.eyebrow,
    required this.subtext,
    required this.stats,
  });
}

class _StatItem {
  final String value;
  final String label;
  const _StatItem(this.value, this.label);
}

// ─── Constants ────────────────────────────────────────────────────────────────

const _kDeepViolet = Color(0xFF0D0B1F);
const _kMidViolet = Color(0xFF1A1040);
const _kRichPurple = Color(0xFF2D1B69);
const _kAccentPurple = Color(0xFFC8B4FF);
const _kAccentPink = Color(0xFFF0A0E0);
const _kLiveGreen = Color(0xFF7DFFB3);
const _kGlassWhite = Color(0x1AFFFFFF);
const _kGlassBorder = Color(0x33FFFFFF);

const _banners = [
  _BannerData(
    imageUrl: 'https://images.unsplash.com/photo-1600596542815-ffad4c1539a9?w=600&q=80',
    eyebrow: 'Premium Real Estate',
    headline: 'Find. Visit.',
    accentWord: 'Own.',
    subtext: 'Curated properties across the city',
    stats: [
      _StatItem('2,400+', 'Listings'),
      _StatItem('98%', 'Verified'),
      _StatItem('4.9★', 'Rating'),
    ],
  ),
  _BannerData(
    imageUrl: 'https://images.unsplash.com/photo-1512917774080-9991f1c4c750?w=600&q=80',
    eyebrow: 'Luxury Collection',
    headline: 'Live in',
    accentWord: 'Style.',
    subtext: 'Handpicked premium residences',
    stats: [
      _StatItem('500+', 'Luxury'),
      _StatItem('50+', 'Cities'),
      _StatItem('10yr', 'Trust'),
    ],
  ),
  _BannerData(
    imageUrl: 'https://images.unsplash.com/photo-1613490493576-7fde63acd811?w=600&q=80',
    eyebrow: 'New Launches',
    headline: 'Your Dream',
    accentWord: 'Home.',
    subtext: 'Exclusive pre-launch deals available',
    stats: [
      _StatItem('120+', 'New'),
      _StatItem('0%', 'Brokerage'),
      _StatItem('24/7', 'Support'),
    ],
  ),
];

// ─── Widget ───────────────────────────────────────────────────────────────────

class HeroBannerCarousel extends StatefulWidget {
  const HeroBannerCarousel({super.key});

  @override
  State<HeroBannerCarousel> createState() => _HeroBannerCarouselState();
}

class _HeroBannerCarouselState extends State<HeroBannerCarousel>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _shimmerController;

  int _currentPage = 0;
  final int _totalPages = _banners.length;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      final next = (_currentPage + 1) % _totalPages;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
      return mounted;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _totalPages,
            itemBuilder: (ctx, i) => _PremiumBannerCard(
              data: _banners[i],
              shimmerController: _shimmerController,
              index: i,
              total: _totalPages,
            ),
          ),

          // Pill indicator
          Positioned(
            bottom: 10,
            right: 26,
            child: Row(
              children: List.generate(_totalPages, (i) {
                final active = i == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.only(left: 4),
                  width: active ? 16 : 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withOpacity(0.9)
                        : Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _PremiumBannerCard extends StatelessWidget {
  final _BannerData data;
  final AnimationController shimmerController;
  final int index;
  final int total;

  const _PremiumBannerCard({
    required this.data,
    required this.shimmerController,
    required this.index,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width - 32; // 16px margin each side

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kDeepViolet, _kRichPurple, _kMidViolet],
              stops: [0, 0.5, 1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Grid texture
              const _GridTexture(),

              // Aurora glow
              Positioned(
                right: -40,
                top: -20,
                child: Container(
                  width: w * 0.8,
                  height: 260,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _kAccentPurple.withOpacity(0.3),
                        Colors.transparent,
                      ],
                      radius: 0.7,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: -20,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _kAccentPink.withOpacity(0.15),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Photo panel (clipped diagonal)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: w * 0.44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      data.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: _kRichPurple),
                    ),
                    // Diagonal mask
                    _DiagonalFade(color: _kMidViolet.withOpacity(0.85)),
                    // Dark tint
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_kDeepViolet, Colors.transparent],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.55],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Shimmer sweep
              AnimatedBuilder(
                animation: shimmerController,
                builder: (_, __) {
                  final p = shimmerController.value;
                  return Positioned.fill(
                    child: Transform.translate(
                      offset: Offset((p * 2 - 0.5) * w, 0),
                      child: Transform.rotate(
                        angle: -math.pi / 6,
                        child: Container(
                          width: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.04),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Content
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: chip + counter
                    Row(
                      children: [
                        _VerifiedChip(),
                        const Spacer(),
                        Text(
                          '${(index + 1).toString().padLeft(2, '0')} / ${total.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 10,
                            color: Colors.white.withOpacity(0.3),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Eyebrow
                    Text(
                      data.eyebrow.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2.5,
                        color: Colors.white.withOpacity(0.4),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Headline
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${data.headline}\n',
                            style: const TextStyle(
                              fontFamily: 'Georgia',
                              fontSize: 25,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.05,
                              letterSpacing: -0.5,
                            ),
                          ),
                          WidgetSpan(
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [_kAccentPurple, _kAccentPink],
                              ).createShader(bounds),
                              child: Text(
                                data.accentWord,
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.05,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Stats row
                    Row(
                      children: [
                        for (int i = 0; i < data.stats.length; i++) ...[
                          if (i > 0) _StatDivider(),
                          _StatCell(stat: data.stats[i]),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),

                    // CTA
                    _CTAButton(),
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

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _VerifiedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _kGlassWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _kGlassBorder, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kLiveGreen,
              boxShadow: [BoxShadow(color: _kLiveGreen, blurRadius: 4)],
            ),
          ),
          const SizedBox(width: 5),
          Text(
            'VERIFIED',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final _StatItem stat;
  const _StatCell({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stat.value,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          stat.label.toUpperCase(),
          style: TextStyle(
            fontSize: 7.5,
            color: Colors.white.withOpacity(0.35),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      width: 0.5,
      height: 22,
      color: Colors.white.withOpacity(0.12),
    );
  }
}

class _CTAButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: _kGlassWhite,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGlassBorder, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Explore Now',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [_kAccentPurple, _kAccentPink],
                ),
              ),
              child: const Icon(
                Icons.arrow_forward,
                size: 8,
                color: Color(0xFF1A1040),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _GridTexture extends StatelessWidget {
  const _GridTexture();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: 0.05,
        child: CustomPaint(painter: _GridPainter()),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _DiagonalFade extends StatelessWidget {
  final Color color;
  const _DiagonalFade({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DiagonalPainter(color));
  }
}

class _DiagonalPainter extends CustomPainter {
  final Color color;
  const _DiagonalPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.35, 0)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}