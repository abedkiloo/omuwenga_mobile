import '../../pos/domain/cart.dart';
import '../../../design_system/chrome/cb_commit_confirm.dart';
import 'field_order.dart';
import 'site_pin.dart';
import '../../../core/format/money.dart';


String? visitOrderPlaceError({
  required bool hasCustomer,
  required bool hasProducts,
  required bool hasPin,
  List<CartLine> lines = const [],
}) {
  if (!hasCustomer) return 'Select a customer first.';
  if (!hasProducts) return 'Add at least one product.';
  if (lines.any((line) => line.quantity <= 0)) {
    return 'Each product needs a quantity greater than zero.';
  }
  if (!hasPin) return 'Pin the delivery drop location.';
  return null;
}

List<CommitSummaryRow> visitOrderCommitRows({
  required String customerName,
  required List<CartLine> lines,
  SitePin? pin,
  String landmark = '',
}) {
  final qty = lines.fold<double>(0, (sum, line) => sum + line.quantity);
  final total = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
  final pinText = pin == null
      ? '—'
      : '${pin.latitude.toStringAsFixed(5)}, ${pin.longitude.toStringAsFixed(5)}';
  return [
    CommitSummaryRow(label: 'Customer', value: customerName, emphasis: true),
    CommitSummaryRow(
      label: 'Items',
      value: '${lines.length} SKU · ${qty.round()} packs',
    ),
    CommitSummaryRow(label: 'Total', value: formatKes(total), emphasis: true),
    CommitSummaryRow(label: 'Drop pin', value: pinText),
    if (landmark.trim().isNotEmpty)
      CommitSummaryRow(label: 'Landmark', value: landmark.trim()),
  ];
}

String? fieldOrderReviewError(FieldOrderCart cart) {
  if (cart.siteId <= 0) return 'Site is required.';
  if (cart.lines.isEmpty) return 'Add at least one product.';
  if (cart.lines.any((line) => line.quantity <= 0)) {
    return 'Each product needs a quantity greater than zero.';
  }
  return null;
}

List<CommitSummaryRow> fieldOrderReviewRows(FieldOrderCart cart) {
  final qty = cart.lines.fold<double>(0, (sum, line) => sum + line.quantity);
  final pinText = cart.latitude == null || cart.longitude == null
      ? '—'
      : '${cart.latitude!.toStringAsFixed(5)}, ${cart.longitude!.toStringAsFixed(5)}';
  return [
    CommitSummaryRow(
      label: 'Site',
      value: cart.siteLabel.isEmpty ? 'Site #${cart.siteId}' : cart.siteLabel,
      emphasis: true,
    ),
    CommitSummaryRow(
      label: 'Items',
      value: '${cart.lines.length} SKU · ${qty.round()} packs',
    ),
    CommitSummaryRow(label: 'Total', value: formatKes(cart.subtotal), emphasis: true),
    CommitSummaryRow(label: 'Drop pin', value: pinText),
  ];
}

String? dispatchPackError(FieldOrderSummary order) {
  if ((order.customerName ?? '').trim().isEmpty) {
    return 'This field sale needs a customer before it can be packed.';
  }
  if (order.lines.isEmpty) return 'This order has no products to pack.';
  return null;
}

const String debtorConfirmCopy =
    'This customer will be added as a debtor in the system. Collect later as Cash or M-Pesa.';

String dispatchPackDescription(FieldOrderSummary order) {
  final name = (order.customerName ?? '').trim();
  final who = name.isEmpty ? 'this customer' : name;
  return 'After you confirm, $who is added as a debtor. Collect later as Cash or M-Pesa.';
}

String dispatchAssignDescription(FieldOrderSummary order) {
  return 'The person you pick will see it on their route after you confirm.';
}

const String dispatchStepPack = 'Pack & mark ready for pickup';
const String dispatchStepAssign = 'Assign for delivery';

bool fieldOrderIsPacked(FieldOrderSummary order) {
  return order.status == FieldOrderStatus.ready ||
      order.status == FieldOrderStatus.outForDelivery ||
      order.status == FieldOrderStatus.done;
}

class DispatchWorkflowStep {
  const DispatchWorkflowStep({
    required this.id,
    required this.label,
    required this.done,
    required this.current,
  });

  final String id;
  final String label;
  final bool done;
  final bool current;
}

List<DispatchWorkflowStep> dispatchWorkflowSteps(FieldOrderSummary order) {
  final packed = fieldOrderIsPacked(order);
  final assigned = order.assignedDeliveryDriverId != null;
  return [
    DispatchWorkflowStep(
      id: 'pack',
      label: dispatchStepPack,
      done: packed,
      current: !packed,
    ),
    DispatchWorkflowStep(
      id: 'assign',
      label: dispatchStepAssign,
      done: assigned,
      current: packed && !assigned,
    ),
  ];
}

class DispatchBlockedStep {
  const DispatchBlockedStep({
    required this.title,
    required this.message,
    required this.currentStep,
    required this.nextStep,
    this.opensPack = false,
  });

  final String title;
  final String message;
  final String currentStep;
  final String nextStep;
  final bool opensPack;
}

DispatchBlockedStep? dispatchAssignBlockedStep(
  FieldOrderSummary order, {
  int? driverId,
}) {
  if (!fieldOrderIsPacked(order)) {
    return const DispatchBlockedStep(
      title: 'Pack this order first',
      message:
          'Assign for delivery is the next step. Finish packing and mark the order ready for pickup before you choose who delivers.',
      currentStep: dispatchStepPack,
      nextStep: dispatchStepAssign,
      opensPack: true,
    );
  }
  if (driverId == null) {
    return const DispatchBlockedStep(
      title: 'Choose who delivers first',
      message:
          'Select the sales person or driver, then assign for delivery.',
      currentStep: 'Choose who delivers',
      nextStep: dispatchStepAssign,
    );
  }
  return null;
}

List<CommitSummaryRow> dispatchPackRows(FieldOrderSummary order) {
  final qty = order.lines.fold<double>(0, (sum, line) => sum + line.quantity);
  final total = order.lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
  return [
    CommitSummaryRow(label: 'Order', value: '#${order.id}', emphasis: true),
    CommitSummaryRow(
      label: 'Customer',
      value: (order.customerName ?? '').trim().isEmpty
          ? '—'
          : order.customerName!,
    ),
    CommitSummaryRow(
      label: 'Items',
      value: '${order.lines.length} SKU · qty ${qty.round()}',
    ),
    CommitSummaryRow(label: 'Total', value: formatKes(total), emphasis: true),
    const CommitSummaryRow(
      label: 'Customer account',
      value: debtorConfirmCopy,
    ),
  ];
}

String? dispatchAssignError({
  required FieldOrderSummary order,
  required bool canAssign,
  int? driverId,
}) {
  final blocked = dispatchAssignBlockedStep(order, driverId: driverId);
  if (blocked != null) return blocked.message;
  if (!canAssign) return 'This order cannot be assigned yet.';
  return null;
}

List<CommitSummaryRow> dispatchAssignRows({
  required FieldOrderSummary order,
  required String driverName,
}) {
  return [
    CommitSummaryRow(label: 'Order', value: '#${order.id}', emphasis: true),
    CommitSummaryRow(
      label: 'Customer',
      value: (order.customerName ?? '').trim().isEmpty
          ? '—'
          : order.customerName!,
    ),
    CommitSummaryRow(label: 'Assigned to', value: driverName, emphasis: true),
  ];
}

List<CommitSummaryRow> deliveryClaimRows(FieldOrderSummary order) {
  final qty = order.lines.fold<double>(0, (sum, line) => sum + line.quantity);
  return [
    CommitSummaryRow(label: 'Order', value: '#${order.id}', emphasis: true),
    CommitSummaryRow(
      label: 'Customer',
      value: (order.customerName ?? '').trim().isEmpty
          ? '—'
          : order.customerName!,
    ),
    CommitSummaryRow(
      label: 'Items',
      value: '${order.lines.length} SKU · qty ${qty.round()}',
    ),
  ];
}
