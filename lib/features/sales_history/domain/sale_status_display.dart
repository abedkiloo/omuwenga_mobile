import '../../../design_system/chrome/cb_status_pill.dart';
import 'payment_status.dart';

/// Shared sale lifecycle for list cards and detail, so they never disagree.
enum SaleLifecycleTone { success, warning, danger, info, neutral }

class SaleLifecycleDisplay {
  const SaleLifecycleDisplay({
    required this.label,
    required this.tone,
    this.inactive = false,
  });

  final String label;
  final SaleLifecycleTone tone;
  final bool inactive;

  CbStatusPillVariant get pillVariant {
    switch (tone) {
      case SaleLifecycleTone.success:
        return CbStatusPillVariant.success;
      case SaleLifecycleTone.warning:
      case SaleLifecycleTone.danger:
        return CbStatusPillVariant.warning;
      case SaleLifecycleTone.info:
        return CbStatusPillVariant.info;
      case SaleLifecycleTone.neutral:
        return CbStatusPillVariant.neutral;
    }
  }
}

SaleLifecycleDisplay describeSaleLifecycle({
  String? status,
  String? refundStatus,
  required PaymentStatusDisplay payment,
  bool needsSalespersonAction = false,
}) {
  final saleStatus = (status ?? '').trim().toLowerCase();
  final refund = (refundStatus ?? '').trim().toLowerCase();

  if (needsSalespersonAction) {
    return const SaleLifecycleDisplay(
      label: 'Needs salesperson action',
      tone: SaleLifecycleTone.danger,
    );
  }
  if (saleStatus == 'pending_approval') {
    return const SaleLifecycleDisplay(
      label: 'Awaiting approval',
      tone: SaleLifecycleTone.info,
    );
  }
  if (saleStatus == 'awaiting_payment') {
    return const SaleLifecycleDisplay(
      label: 'Collect payment',
      tone: SaleLifecycleTone.warning,
    );
  }
  if (saleStatus == 'holding') {
    return const SaleLifecycleDisplay(
      label: 'On hold',
      tone: SaleLifecycleTone.warning,
    );
  }
  if (saleStatus == 'cancelled') {
    return const SaleLifecycleDisplay(
      label: 'Cancelled',
      tone: SaleLifecycleTone.danger,
      inactive: true,
    );
  }
  if (saleStatus == 'voided' || refund == 'refunded') {
    return const SaleLifecycleDisplay(
      label: 'Voided',
      tone: SaleLifecycleTone.danger,
      inactive: true,
    );
  }
  if (refund == 'partial') {
    return const SaleLifecycleDisplay(
      label: 'Partial refund',
      tone: SaleLifecycleTone.warning,
    );
  }

  switch (payment) {
    case PaymentStatusDisplay.paid:
      return const SaleLifecycleDisplay(
        label: 'Completed & Settled',
        tone: SaleLifecycleTone.success,
      );
    case PaymentStatusDisplay.debt:
      return const SaleLifecycleDisplay(
        label: 'Debt',
        tone: SaleLifecycleTone.warning,
      );
    case PaymentStatusDisplay.partial:
      return const SaleLifecycleDisplay(
        label: 'Partial',
        tone: SaleLifecycleTone.warning,
      );
  }
}
