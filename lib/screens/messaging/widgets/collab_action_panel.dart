// screens/messaging/widgets/collab_action_panel.dart
//
// The status-stepper + per-status action panel rendered above the composer
// in a collaboration's DM thread — a phone-first port of
// `CollabActionPanel.tsx`'s status -> action -> role table (see the research
// transcript this was built from: 6-step stepper, per-status action list,
// dispute gating). Every action calls [CollaborationThreadController], which
// only ever calls RPCs/Edge Functions — nothing here writes collab state
// directly or predicts the next status locally.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/collaboration.dart';
import '../../../providers/collaboration_thread_controller.dart';
import '../../../services/location_service.dart';
import '../../../services/payment_service.dart';
import '../../../services/razorpay_checkout_session.dart';
import 'collab_dispute_sheet.dart';

const List<({String status, String label})> kCollabSteps = [
  (status: CollabStatuses.accepted, label: 'Agreement'),
  (status: CollabStatuses.agreementPending, label: 'Advance (25%)'),
  (status: CollabStatuses.inProgress, label: 'In progress'),
  (status: CollabStatuses.deliverablePending, label: 'Final (75%)'),
  (status: CollabStatuses.delivered, label: 'Delivered'),
  (status: CollabStatuses.completed, label: 'Completed'),
];

/// `CollabActionPanel.tsx`'s `stepIndex` — folds the two statuses that are
/// declared in the enum but never actually stored (`advance_paid`,
/// `final_paid`) into their displayed step.
int collabStepIndex(String status) {
  final idx = kCollabSteps.indexWhere((s) => s.status == status);
  if (idx >= 0) return idx;
  if (status == CollabStatuses.advancePaid) return 2;
  if (status == CollabStatuses.finalPaid) return 3;
  return 0;
}

const Set<String> _kStepperHiddenStatuses = {
  CollabStatuses.declined,
  CollabStatuses.disputed,
  CollabStatuses.cancelled,
};

const Set<String> _kWorkStatuses = {
  CollabStatuses.advancePaid,
  CollabStatuses.inProgress,
};

const Set<String> _kDeliverableStatuses = {
  CollabStatuses.finalPaid,
  CollabStatuses.deliverablePending,
};

const Set<String> _kDisputableStatuses = {
  CollabStatuses.advancePaid,
  CollabStatuses.inProgress,
  CollabStatuses.deliverablePending,
  CollabStatuses.delivered,
};

class CollabActionPanel extends StatefulWidget {
  final CollaborationThreadController controller;

  /// Called after any action that inserted a new message (sample/deliverable
  /// upload, location share/request) so the caller's message list refetches
  /// — mirrors `onMessagesChanged` in `CollabActionPanel.tsx`. The realtime
  /// subscription usually gets there first; this is the same belt-and-
  /// suspenders `await refresh()` pattern already used elsewhere in this app.
  final VoidCallback? onMessagesChanged;

  const CollabActionPanel({
    super.key,
    required this.controller,
    this.onMessagesChanged,
  });

  @override
  State<CollabActionPanel> createState() => _CollabActionPanelState();
}

class _CollabActionPanelState extends State<CollabActionPanel> {
  final _imagePicker = ImagePicker();
  final _locationService = LocationService();
  bool _localBusy = false;

  CollaborationThreadController get controller => widget.controller;

  bool get _busy => _localBusy || controller.busy;

  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _localBusy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _localBusy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _setAgreement() async {
    final controllerText = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Set agreement amount'),
        content: TextField(
          controller: controllerText,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            prefixText: '₹ ',
            hintText: 'Total amount',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controllerText.text.trim());
              Navigator.of(dialogContext).pop(value);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0 || !mounted) return;
    await _guard(() async {
      final error = await controller.setAgreement(amount);
      if (error != null) _snack(error);
    });
  }

  Future<void> _downloadAgreement() async {
    await _guard(() async {
      final (url, error) = await controller.fetchAgreementUrl();
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else if (error != null) {
        _snack(error);
      }
    });
  }

  Future<void> _pay(String milestone) async {
    await _guard(() async {
      Map<String, dynamic> order;
      try {
        order = await controller.createPaymentOrder(milestone);
      } catch (e) {
        _snack('Could not start payment. Please try again.');
        return;
      }
      final keyId = order['keyId'] as String?;
      final orderId = order['orderId'] as String?;
      final amount = order['amount'];
      final currency = (order['currency'] as String?) ?? 'INR';
      if (keyId == null ||
          keyId.isEmpty ||
          orderId == null ||
          orderId.isEmpty ||
          amount == null) {
        _snack('Failed to create payment order.');
        return;
      }

      final session = RazorpayCheckoutSession();
      try {
        final result = await session.open(
          keyId: keyId,
          amountMinor: amount is int ? amount : int.tryParse('$amount') ?? 0,
          currency: currency,
          orderId: orderId,
          name: 'PropCid',
          description: milestone == CollabMilestones.advance
              ? 'Collaboration advance (25%)'
              : 'Collaboration final payment (75%)',
          customerId: order['customerId'] as String?,
          prefill: (order['prefill'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ),
        );

        if (result is CheckoutSuccess) {
          try {
            await PaymentService().verifyPayment(
              razorpayOrderId: result.orderId,
              razorpayPaymentId: result.paymentId,
              razorpaySignature: result.signature,
            );
            // Collab state advances server-side only — never predicted
            // locally. The realtime subscription (or this belt-and-
            // suspenders refresh) picks up the new status.
            await controller.refresh();
            _snack('Payment successful.');
          } catch (e) {
            _snack(
              'Payment could not be verified. If you were charged, it will be reconciled automatically.',
            );
          }
        } else if (result is CheckoutCancelled) {
          _snack('Payment cancelled.');
        } else if (result is CheckoutFailed) {
          _snack(result.message);
        }
      } finally {
        session.dispose();
      }
    });
  }

  Future<void> _sendSample() async {
    final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    await _guard(() async {
      final error = await controller.uploadSample(File(picked.path));
      if (error != null) {
        _snack(error);
      } else {
        widget.onMessagesChanged?.call();
      }
    });
  }

  Future<void> _sendDeliverable() async {
    final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    await _guard(() async {
      final error = await controller.uploadDeliverable(File(picked.path));
      if (error != null) {
        _snack(error);
      } else {
        widget.onMessagesChanged?.call();
      }
    });
  }

  Future<void> _requestLocation() async {
    await _guard(() async {
      final error = await controller.requestLocation();
      if (error != null) {
        _snack(error);
      } else {
        widget.onMessagesChanged?.call();
      }
    });
  }

  Future<void> _shareLocation() async {
    await _guard(() async {
      final result = await _locationService.getCurrentPosition();
      if (!result.isSuccess) {
        _snack(_locationFailureMessage(result.failureReason));
        return;
      }
      final error = await controller.sendLocation(
        latitude: result.latitude!,
        longitude: result.longitude!,
      );
      if (error != null) {
        _snack(error);
      } else {
        widget.onMessagesChanged?.call();
      }
    });
  }

  String _locationFailureMessage(LocationFailureReason? reason) {
    switch (reason) {
      case LocationFailureReason.servicesDisabled:
        return 'Turn on location services to share your location.';
      case LocationFailureReason.permissionDenied:
        return 'Location permission is required to share your location.';
      case LocationFailureReason.permissionDeniedForever:
        return 'Location access is turned off for this app. Enable it in Settings.';
      case LocationFailureReason.unknown:
      case null:
        return "Couldn't get your location. Please try again.";
    }
  }

  Future<void> _confirmPayFinal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pay final amount?'),
        content: Text(
          'This pays the remaining ${formatCollabAmount(controller.finalPayment?.amountMinor ?? controller.collaboration?.finalAmountMinor)} '
          'to complete the collaboration.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes, pay now'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _pay(CollabMilestones.finalMilestone);
  }

  Future<void> _raiseDispute() async {
    final reason = await showCollabDisputeSheet(context);
    if (reason == null || !mounted) return;
    await _guard(() async {
      final error = await controller.raiseDispute(reason);
      if (error != null) _snack(error);
    });
  }

  Future<void> _downloadInvoice(CollabInvoice invoice) async {
    await _guard(() async {
      final (url, error) = await controller.fetchInvoiceUrl(invoice.id);
      if (url != null) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else if (error != null) {
        _snack(error);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final collab = controller.collaboration;
    if (collab == null) {
      return controller.loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : const SizedBox.shrink();
    }

    final status = collab.status;
    return Container(
      color: AppColors.cardBackground,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_kStepperHiddenStatuses.contains(status)) _buildStepper(status),
          const SizedBox(height: 10),
          ..._buildStatusActions(collab, status),
          if (controller.invoices.isNotEmpty) _buildInvoices(),
        ],
      ),
    );
  }

  Widget _buildStepper(String status) {
    final activeIndex = collabStepIndex(status);
    return SizedBox(
      height: 44,
      child: Row(
        children: List.generate(kCollabSteps.length, (i) {
          final step = kCollabSteps[i];
          final reached = i <= activeIndex;
          return Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == 0
                            ? Colors.transparent
                            : (i <= activeIndex
                                  ? AppColors.primary
                                  : const Color(0xFFEDEDF2)),
                      ),
                    ),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached
                            ? AppColors.primary
                            : const Color(0xFFEDEDF2),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 3,
                        color: i == kCollabSteps.length - 1
                            ? Colors.transparent
                            : (i < activeIndex
                                  ? AppColors.primary
                                  : const Color(0xFFEDEDF2)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  step.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 9,
                    fontWeight: reached ? FontWeight.w700 : FontWeight.w500,
                    color: reached ? AppColors.primary : AppColors.textHint,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  List<Widget> _buildStatusActions(Collaboration collab, String status) {
    final actions = <Widget>[];

    if (status == CollabStatuses.accepted) {
      actions.add(
        _actionButton(
          'Set agreement amount',
          Icons.handshake_outlined,
          _setAgreement,
        ),
      );
    }

    if (status == CollabStatuses.agreementPending) {
      actions.add(
        _infoLine(
          'Total ${formatCollabAmount(collab.agreedAmountMinor)} · '
          'Advance ${formatCollabAmount(collab.advanceAmountMinor)} · '
          'Final ${formatCollabAmount(collab.finalAmountMinor)}',
        ),
      );
      actions.add(
        _actionButton(
          'Agreement PDF',
          Icons.description_outlined,
          _downloadAgreement,
          outlined: true,
        ),
      );
      if (controller.isClient) {
        actions.add(
          _actionButton(
            'Pay advance (25%) — ${formatCollabAmount(controller.advancePayment?.amountMinor)}',
            Icons.payment_outlined,
            () => _pay(CollabMilestones.advance),
          ),
        );
      }
    }

    if (_kWorkStatuses.contains(status)) {
      if (controller.isInfluencer) {
        actions.add(
          _actionButton(
            'Send sample (view once)',
            Icons.videocam_outlined,
            _sendSample,
            outlined: true,
          ),
        );
        actions.add(
          _actionButton(
            'Request site location',
            Icons.location_searching,
            _requestLocation,
            outlined: true,
          ),
        );
      }
      if (controller.isClient) {
        actions.add(
          _actionButton(
            'Share my location',
            Icons.my_location_outlined,
            _shareLocation,
            outlined: true,
          ),
        );
        actions.add(
          _actionButton(
            'Confirm & pay final (75%) — ${formatCollabAmount(controller.finalPayment?.amountMinor ?? collab.finalAmountMinor)}',
            Icons.payment_outlined,
            _confirmPayFinal,
          ),
        );
      }
    }

    if (_kDeliverableStatuses.contains(status) && controller.isInfluencer) {
      actions.add(
        _actionButton(
          'Upload final deliverable',
          Icons.upload_file_outlined,
          _sendDeliverable,
        ),
      );
    }

    if (status == CollabStatuses.delivered) {
      if (controller.isClient) {
        actions.add(
          _infoLine(
            'Download the deliverable from the chat below — it expires 7 days after delivery.',
          ),
        );
      }
      if (controller.isInfluencer) {
        actions.add(
          _actionButton(
            'Send corrected deliverable',
            Icons.upload_file_outlined,
            _sendDeliverable,
            outlined: true,
          ),
        );
      }
    }

    if (status == CollabStatuses.completed) {
      actions.add(
        _infoLine(
          'Collaboration completed. Payout to the influencer is scheduled within 30 days.',
        ),
      );
    }

    if (status == CollabStatuses.disputed) {
      actions.add(_disputeBanner(collab.disputeReason));
    }

    if (status == CollabStatuses.cancelled) {
      actions.add(_infoLine('This collaboration was cancelled.'));
    }

    if (_kDisputableStatuses.contains(status)) {
      actions.add(
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _busy ? null : _raiseDispute,
            icon: const Icon(Icons.flag_outlined, size: 15, color: Colors.red),
            label: const Text(
              'Raise a dispute',
              style: TextStyle(color: Colors.red, fontSize: 12.5),
            ),
          ),
        ),
      );
    }

    return actions
        .map(
          (w) => Padding(padding: const EdgeInsets.only(bottom: 6), child: w),
        )
        .toList();
  }

  Widget _buildInvoices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: controller.invoices
          .map(
            (invoice) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _actionButton(
                '${invoice.milestone == CollabMilestones.advance ? 'Advance' : 'Final'} invoice',
                Icons.receipt_long_outlined,
                () => _downloadInvoice(invoice),
                outlined: true,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _actionButton(
    String label,
    IconData icon,
    VoidCallback onTap, {
    bool outlined = false,
  }) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_busy)
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1),
        ),
      ],
    );
    return SizedBox(
      width: double.infinity,
      child: outlined
          ? OutlinedButton(onPressed: _busy ? null : onTap, child: child)
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: _busy ? null : onTap,
              child: child,
            ),
    );
  }

  Widget _infoLine(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: AppTextStyles.caption.copyWith(
        fontSize: 12,
        color: AppColors.textSecondary,
      ),
    ),
  );

  Widget _disputeBanner(String? reason) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEE2E2),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      'Disputed${reason != null && reason.isNotEmpty ? ': $reason' : ''} — payout is frozen pending admin review.',
      style: AppTextStyles.caption.copyWith(
        fontSize: 12,
        color: const Color(0xFFB91C1C),
      ),
    ),
  );
}
