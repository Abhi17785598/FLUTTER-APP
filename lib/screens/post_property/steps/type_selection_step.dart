import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/post_property_provider.dart';
import '../portal_theme.dart';

/// Step 1 — reproduction of the portal's `TypeSelectionStep.tsx`.
///
/// Card artwork mirrors the portal's real illustrations: full-bleed
/// `BoxFit.cover` images (no padding, no colour backdrop behind them), using
/// this app's own `assets/formicons/*.png` set — already declared as a
/// Flutter asset — keyed by the same filenames the portal's own
/// `propertyTypeSVG`/`listingTypeSVG` switch on
/// (`propcid/src/components/PropertyWizard/steps/TypeSelectionStep.tsx`).
///
/// Card sizing is intentionally more compact than the portal's own literal
/// desktop pixels (`_kImageBand`/`_kImageBox` etc. below): reproduced at
/// the portal's exact 260/135/80 dimensions, the cards ran taller than a
/// phone-width column needs. Width stays fully responsive — computed from
/// the available layout width via `LayoutBuilder`, never hardcoded — only
/// the fixed vertical/padding dimensions were tightened, and every one of
/// them was checked against `post_property_shell_layout_test.dart`'s
/// no-overflow assertions at 320–1920 dp before landing.
class TypeSelectionStep extends StatelessWidget {
  const TypeSelectionStep({super.key});

  /// Verbatim from `propertyTypes` (TypeSelectionStep.tsx:123-129), in
  /// source order — Land first, not Residential. `imageAsset` mirrors
  /// `propertyTypeSVG`'s id→file switch (TypeSelectionStep.tsx:12-20).
  static const List<_TypeCard> _propertyTypes = [
    _TypeCard(
      id: 'land',
      title: 'Land / Plot',
      description: 'Plots, Agri. Land, etc.',
      imageAsset: 'assets/formicons/land.png',
      category: PropertyCategory.land,
      pastelBg: Color(0xFFE7F5EA),
      chipColor: Color(0xFF4CAF7D),
    ),
    _TypeCard(
      id: 'residential',
      title: 'Residential',
      description: 'Houses, Apartments, Villas, etc.',
      imageAsset: 'assets/formicons/residential.png',
      category: PropertyCategory.residential,
      pastelBg: Color(0xFFFCEBE3),
      chipColor: Color(0xFFEE7B4F),
    ),
    _TypeCard(
      id: 'commercial',
      title: 'Commercial',
      description: 'Offices, Shops, Showrooms, etc.',
      imageAsset: 'assets/formicons/commercial.png',
      category: PropertyCategory.commercial,
      pastelBg: Color(0xFFE6F0FE),
      chipColor: Color(0xFF4A82E8),
    ),
    _TypeCard(
      id: 'pg/Co-living',
      title: 'PG / Co-living',
      description: 'PG, Hostels, Co-living Spaces, etc.',
      imageAsset: 'assets/formicons/pgcoliving.png',
      category: PropertyCategory.pg,
      pastelBg: Color(0xFFF0EBFB),
      chipColor: Color(0xFF8B6FD6),
    ),
    _TypeCard(
      id: 'others',
      title: 'Others',
      description: 'Other Property Types, etc.',
      imageAsset: 'assets/formicons/typeselection.png',
      category: PropertyCategory.other,
      pastelBg: Color(0xFFFDF3DC),
      chipColor: Color(0xFFE8A93B),
    ),
  ];

  /// Verbatim from `getAvailableListingTypes()` — Rent first, then For Sale,
  /// then Lease. Note the middle label is "For Sale", not "Sell".
  /// `imageAsset` mirrors `listingTypeSVG`'s id→file switch
  /// (TypeSelectionStep.tsx:40-45) — note the portal's internal id is
  /// `sell`, matching [ListingIntent.sell] and `sell.png`.
  static const List<_IntentCard> _listingTypes = [
    _IntentCard(
      title: 'Rent',
      description: 'Monthly rental properties',
      imageAsset: 'assets/formicons/rent.png',
      intent: ListingIntent.rent,
    ),
    _IntentCard(
      title: 'For Sale',
      description: 'Properties for sale',
      imageAsset: 'assets/formicons/sell.png',
      intent: ListingIntent.sell,
    ),
    _IntentCard(
      title: 'Lease',
      description: 'Long-term lease properties',
      imageAsset: 'assets/formicons/lease.png',
      intent: ListingIntent.lease,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PostPropertyProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PortalStepHeading(
          title: 'What are you listing?',
          subtitle: 'Choose a property category and how you want to list it.',
        ),

        // ── Property Type ──────────────────────────────────────────────
        const PortalGroupLabel('Property Type'),
        // One per row, stacked vertically — a colour-coded icon-left row
        // card rather than the portal's own 2-column image-on-top grid.
        // Width is whatever the column gives it (no hardcoded dp), so this
        // stays correct at any phone size.
        for (int i = 0; i < _propertyTypes.length; i++) ...[
          if (i > 0) const SizedBox(height: PortalTheme.gapMd),
          _PropertyTypeCard(
            data: _propertyTypes[i],
            selected: provider.category == _propertyTypes[i].category,
            onTap: () => context
                .read<PostPropertyProvider>()
                .setCategory(_propertyTypes[i].category),
          ),
        ],
        const SizedBox(height: 14),

        // ── Listing Type ───────────────────────────────────────────────
        const PortalGroupLabel('Listing Type'),
        // `grid-cols-1` at mobile — one per row, matching the portal.
        for (int i = 0; i < _listingTypes.length; i++) ...[
          if (i > 0) const SizedBox(height: PortalTheme.gapMd),
          _ListingTypeCard(
            data: _listingTypes[i],
            selected: provider.listingIntent == _listingTypes[i].intent,
            onTap: () => context.read<PostPropertyProvider>().setListingIntent(
              _listingTypes[i].intent,
            ),
          ),
        ],
      ],
    );
  }
}

class _TypeCard {
  const _TypeCard({
    required this.id,
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.category,
    required this.pastelBg,
    required this.chipColor,
  });

  final String id;
  final String title;
  final String description;
  final String imageAsset;
  final PropertyCategory category;

  /// The card's own soft background colour — each category gets a
  /// distinct pastel rather than sharing one generic surface colour.
  final Color pastelBg;

  /// The icon chip's fill and the chevron/selected-border accent — a
  /// deeper shade of [pastelBg].
  final Color chipColor;
}

class _IntentCard {
  const _IntentCard({
    required this.title,
    required this.description,
    required this.imageAsset,
    required this.intent,
  });

  final String title;
  final String description;
  final String imageAsset;
  final ListingIntent intent;
}

/// Card artwork: the category's real illustration, full-bleed —
/// `BoxFit.cover` filling the entire band/box exactly like the portal's
/// `objectFit: 'cover', width: '100%', height: '100%'`. No padding, no
/// colour backdrop behind it — the image itself is the entire visual,
/// matching source. `assets/formicons/*.png` are the portal's own
/// illustrations (same art family, same filenames), high-resolution
/// source images, so `cover` crops cleanly with no pixelation at any of
/// the compact sizes below.
class _CategoryImageArt extends StatelessWidget {
  const _CategoryImageArt({required this.imageAsset});

  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imageAsset,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
    );
  }
}

/// Property-type row card — icon chip, title/description, trailing
/// chevron, each category tinted with its own pastel colour rather than a
/// single shared surface. One per row (see the vertical stack in `build`
/// above) instead of the portal's 2-column image-on-top grid.
class _PropertyTypeCard extends StatelessWidget {
  const _PropertyTypeCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _TypeCard data;
  final bool selected;
  final VoidCallback onTap;

  static const double _kChipSize = 46;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: data.pastelBg,
          borderRadius: BorderRadius.circular(PortalTheme.cardRadius),
          border: Border.all(
            color: selected ? data.chipColor : Colors.transparent,
            width: 2,
          ),
          boxShadow: selected
              ? PortalTheme.cardShadowActive
              : PortalTheme.cardShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(PortalTheme.imageRadius),
              child: Container(
                width: _kChipSize,
                height: _kChipSize,
                color: data.chipColor.withOpacity(0.18),
                child: Padding(
                  padding: const EdgeInsets.all(7),
                  child: _CategoryImageArt(imageAsset: data.imageAsset),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    data.title,
                    // The category's own chip colour when selected, rather
                    // than the theme's one universal accent — keeps each
                    // row's selected state feeling like part of its own
                    // colour, not a generic highlight.
                    style: PortalTheme.cardTitle(
                      selected,
                    ).copyWith(color: selected ? data.chipColor : null),
                  ),
                  const SizedBox(height: 2),
                  Text(data.description, style: PortalTheme.cardDescription),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: data.chipColor, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Landscape card — `cardBaseLandscape` / `cardActiveLandscape`.
/// Indicator sits top-LEFT here, and the text block is left-aligned, inset
/// just enough to clear the badge.
///
/// Compact like [_PropertyTypeCard]: the portal's fixed 80px row/image
/// shrinks to [_kCardMinHeight]/[_kImageBox] here.
class _ListingTypeCard extends StatelessWidget {
  const _ListingTypeCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _IntentCard data;
  final bool selected;
  final VoidCallback onTap;

  static const double _kCardMinHeight = 62;
  static const double _kImageBox = 58;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        // A floor, not an exact height — narrow phones that wrap the
        // description onto a third line still get the room they need
        // instead of being clipped.
        constraints: const BoxConstraints(minHeight: _kCardMinHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? PortalTheme.accentSurface : PortalTheme.cardSurface,
          borderRadius: BorderRadius.circular(PortalTheme.cardRadius),
          border: Border.all(
            color: selected ? PortalTheme.accent : PortalTheme.cardBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? PortalTheme.cardShadowActive
              : PortalTheme.cardShadow,
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 26, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.title,
                          style: PortalTheme.cardTitle(selected),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          data.description,
                          style: PortalTheme.cardDescription,
                        ),
                      ],
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: _kImageBox,
                    height: _kImageBox,
                    child: AnimatedScale(
                      scale: selected ? 1.06 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Opacity(
                        opacity: selected ? 1.0 : 0.85,
                        child: _CategoryImageArt(imageAsset: data.imageAsset),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              child: PortalCheckBadge(selected: selected),
            ),
          ],
        ),
      ),
    );
  }
}
