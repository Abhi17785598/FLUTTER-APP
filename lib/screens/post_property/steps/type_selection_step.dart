import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/post_property_provider.dart';
import '../portal_theme.dart';

/// Step 1 — reproduction of the portal's `TypeSelectionStep.tsx`.
///
/// The React portal is the design specification for this screen. Copy, order,
/// colours, type scale, card geometry and the selection indicator are matched
/// to source; the only deviations are the mobile layout adaptations noted
/// inline (grid column counts, which the portal itself varies by breakpoint).
class TypeSelectionStep extends StatelessWidget {
  const TypeSelectionStep({super.key});

  /// Verbatim from `propertyTypes` (TypeSelectionStep.tsx:119), in source
  /// order — Land first, not Residential.
  static const List<_TypeCard> _propertyTypes = [
    _TypeCard(
      id: 'land',
      title: 'Land / Plot',
      description: 'Plots, Agricultural Land, Independent Land, etc.',
      asset: 'assets/formicons/land.png',
      category: PropertyCategory.land,
    ),
    _TypeCard(
      id: 'residential',
      title: 'Residential',
      description: 'Houses, Apartments, Flats, Villas, etc.',
      asset: 'assets/formicons/residential.png',
      category: PropertyCategory.residential,
    ),
    _TypeCard(
      id: 'commercial',
      title: 'Commercial',
      description: 'Offices, Shops, Showrooms, Warehouses, etc.',
      asset: 'assets/formicons/commercial.png',
      category: PropertyCategory.commercial,
    ),
    _TypeCard(
      id: 'pg/Co-living',
      title: 'PG / Co-living',
      description: 'PG, Hostels, Co-living Spaces, etc.',
      asset: 'assets/formicons/pgcoliving.png',
      category: PropertyCategory.pg,
    ),
    _TypeCard(
      id: 'others',
      title: 'Others',
      description: 'Other properties, warehouses, etc.',
      asset: 'assets/formicons/typeselection.png',
      category: PropertyCategory.other,
    ),
  ];

  /// Verbatim from `getAvailableListingTypes()` — Rent first, then For Sale,
  /// then Lease. Note the middle label is "For Sale", not "Sell".
  static const List<_IntentCard> _listingTypes = [
    _IntentCard(
      title: 'Rent',
      description: 'Monthly rental properties',
      asset: 'assets/formicons/rent.png',
      intent: ListingIntent.rent,
    ),
    _IntentCard(
      title: 'For Sale',
      description: 'Properties for sale',
      asset: 'assets/formicons/sell.png',
      intent: ListingIntent.sell,
    ),
    _IntentCard(
      title: 'Lease',
      description: 'Long-term lease properties',
      asset: 'assets/formicons/lease.png',
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
        // The portal is `grid-cols-2` at mobile width (3 at md, 5 at lg), so
        // two columns is the portal's own mobile layout, not an adaptation.
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = PortalTheme.gapMd;
            final cardWidth = (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final type in _propertyTypes)
                  SizedBox(
                    width: cardWidth,
                    child: _PropertyTypeCard(
                      data: type,
                      selected: provider.category == type.category,
                      onTap: () => context
                          .read<PostPropertyProvider>()
                          .setCategory(type.category),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),

        // ── Listing Type ───────────────────────────────────────────────
        const PortalGroupLabel('Listing Type'),
        // `grid-cols-1` at mobile — one per row, matching the portal.
        for (int i = 0; i < _listingTypes.length; i++) ...[
          if (i > 0) const SizedBox(height: PortalTheme.gapMd),
          _ListingTypeCard(
            data: _listingTypes[i],
            selected: provider.listingIntent == _listingTypes[i].intent,
            onTap: () => context
                .read<PostPropertyProvider>()
                .setListingIntent(_listingTypes[i].intent),
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
    required this.asset,
    required this.category,
  });

  final String id;
  final String title;
  final String description;
  final String asset;
  final PropertyCategory category;
}

class _IntentCard {
  const _IntentCard({
    required this.title,
    required this.description,
    required this.asset,
    required this.intent,
  });

  final String title;
  final String description;
  final String asset;
  final ListingIntent intent;
}

/// Portrait card — `cardBase` / `cardActive` in the portal.
///
/// minHeight 260 is the portal's desktop card. On a ~175px-wide mobile column
/// that would be mostly whitespace, so the card sizes to its content while
/// keeping the portal's 135px image band, padding and type scale.
class _PropertyTypeCard extends StatelessWidget {
  const _PropertyTypeCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _TypeCard data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: selected ? PortalTheme.accentSurface : PortalTheme.cardSurface,
          borderRadius: BorderRadius.circular(PortalTheme.cardRadius),
          border: Border.all(
            color: selected ? PortalTheme.accent : PortalTheme.cardBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow:
              selected ? PortalTheme.cardShadowActive : PortalTheme.cardShadow,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 135px image band, full card width, 12px radius, cover fit.
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(PortalTheme.imageRadius),
                  child: SizedBox(
                    width: double.infinity,
                    height: 135,
                    child: AnimatedScale(
                      // `transform: scale(1.06)` when active.
                      scale: selected ? 1.06 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Opacity(
                        // `grayscale(15%) opacity(0.85)` when inactive; the
                        // opacity half is reproduced, the 15% desaturation is
                        // dropped rather than paying for a colour matrix.
                        opacity: selected ? 1.0 : 0.85,
                        child: Image.asset(data.asset, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: PortalTheme.cardTitle(selected),
                ),
                const SizedBox(height: 4),
                Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: PortalTheme.cardDescription,
                ),
              ],
            ),
            // Indicator: top-right, 12px inset.
            Positioned(
              top: 0,
              right: 0,
              child: PortalCheckBadge(selected: selected),
            ),
          ],
        ),
      ),
    );
  }
}

/// Landscape card — `cardBaseLandscape` / `cardActiveLandscape`.
/// Indicator sits top-LEFT here, and the text block is left-aligned with a
/// 32px left inset so it clears the badge.
class _ListingTypeCard extends StatelessWidget {
  const _ListingTypeCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _IntentCard data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        // The portal's card is a fixed 80px row. Narrow phones wrap the
        // description onto a third line, which a hard height clips and hatches
        // — so 80 is the floor rather than the exact height. Identical at every
        // width where the text already fits.
        constraints: const BoxConstraints(minHeight: 80),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? PortalTheme.accentSurface : PortalTheme.cardSurface,
          borderRadius: BorderRadius.circular(PortalTheme.cardRadius),
          border: Border.all(
            color: selected ? PortalTheme.accent : PortalTheme.cardBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow:
              selected ? PortalTheme.cardShadowActive : PortalTheme.cardShadow,
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 32, right: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(data.title,
                            style: PortalTheme.cardTitle(selected)),
                        const SizedBox(height: 4),
                        Text(data.description,
                            style: PortalTheme.cardDescription),
                      ],
                    ),
                  ),
                ),
                // `w-20 h-20` (80px) at mobile, `rounded-xl`, cover.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: AnimatedScale(
                      scale: selected ? 1.06 : 1.0,
                      duration: const Duration(milliseconds: 150),
                      child: Opacity(
                        opacity: selected ? 1.0 : 0.85,
                        child: Image.asset(data.asset, fit: BoxFit.cover),
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
