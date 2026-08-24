import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/property_model.dart';
import '../../providers/compare_provider.dart';
import '../theme/app_colors.dart';

/// Single choke point every property card's compare toggle calls through —
/// so the "limit reached" / "category mismatch" feedback is worded and
/// triggered identically everywhere, instead of each of the ~8 call sites
/// (Home rails, Search, Shortlist, My Activity, Property Detail) re-deriving
/// it from [CompareProvider.toggle]'s return value.
void handleCompareToggle(BuildContext context, PropertyModel property) {
  final compare = context.read<CompareProvider>();
  final result = compare.toggle(property);

  final String? message = switch (result) {
    CompareAddResult.added || CompareAddResult.removed => null,
    CompareAddResult.limitReached =>
      'You can compare up to ${CompareProvider.maxCompare} properties at a time.',
    CompareAddResult.categoryMismatch =>
      "Can't compare these — you can only compare properties of the same "
          'category and listing type.',
  };
  if (message == null) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppColors.error),
  );
}
