// screens/home/widgets/investors_corner_section.dart
//
// Home's "Investor's Corner" rail — the Flutter counterpart to the portal's
// `InvestorsCornerSection.tsx`. Cards are intentionally not tappable: the
// portal's own cards carry no `onClick` either (only its "View All" header
// action does, and that opens a dedicated `/investors-corner` list page
// this app has no equivalent screen for).
//
// HIDES ITSELF WHEN THERE IS NOTHING TO SHOW — same convention as every
// other admin/backend-driven Home rail.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/investor_opportunity.dart';
import '../../../models/property_model.dart';
import '../../../services/investors_corner_service.dart';
import '../../../widgets/section_header.dart';

const double _kInvestorCardWidth = 240;
const double _kInvestorImageHeight = 120;

class InvestorsCornerSection extends StatefulWidget {
  const InvestorsCornerSection({super.key, this.service});

  @visibleForTesting
  final InvestorsCornerService? service;

  @override
  State<InvestorsCornerSection> createState() => _InvestorsCornerSectionState();
}

class _InvestorsCornerSectionState extends State<InvestorsCornerSection> {
  late final Future<List<InvestorOpportunity>> _future =
      (widget.service ?? InvestorsCornerService()).listActive();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InvestorOpportunity>>(
      future: _future,
      builder: (context, snapshot) {
        final items = snapshot.data;
        if (items == null || items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: "Investor's Corner"),
              SizedBox(
                height: 236,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingL,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(
                      right: AppConstants.spacingM,
                    ),
                    child: _InvestorCard(item: items[i]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InvestorCard extends StatelessWidget {
  const _InvestorCard({required this.item});

  final InvestorOpportunity item;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kInvestorCardWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        boxShadow: AppColors.surfaceCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.cardRadius),
            ),
            child: item.featuredImageUrl.isEmpty
                ? _placeholder()
                : CachedNetworkImage(
                    imageUrl: item.featuredImageUrl,
                    height: _kInvestorImageHeight,
                    width: _kInvestorCardWidth,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => _placeholder(),
                    errorWidget: (_, _, _) => _placeholder(),
                  ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    item.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(fontSize: 10.5),
                  ),
                  const Spacer(),
                  if (item.expectedRoiPercentage != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 13,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${item.expectedRoiPercentage!.toStringAsFixed(1)}% ROI',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                        if (item.investmentAmount != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            'from ${PropertyModel.formatIndianPrice(item.investmentAmount)}',
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    height: _kInvestorImageHeight,
    width: _kInvestorCardWidth,
    color: AppColors.primaryLight,
    alignment: Alignment.center,
    child: const Icon(
      Icons.insights_rounded,
      size: 26,
      color: AppColors.primary,
    ),
  );
}
