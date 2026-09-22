import '../../pos/domain/cart.dart';
import '../../../design_system/chrome/cb_commit_confirm.dart';
import 'field_order.dart';
import 'site_pin.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

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
    CommitSummaryRow(label: 'Total', value: _kes(total), emphasis: true),
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
    CommitSummaryRow(label: 'Total', value: _kes(cart.subtotal), emphasis: true),
    CommitSummaryRow(label: 'Drop pin', value: pinText),
  ];
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
      value: '${order.lines.length} lines · qty ${qty.round()}',
    ),
    CommitSummaryRow(label: 'Total', value: _kes(total), emphasis: true),
    const CommitSummaryRow(label: 'After confirm', value: 'Ready for pickup'),
  ];
}

String? dispatchAssignError({required bool canAssign, int? driverId}) {
  if (driverId == null) return 'Select a delivery driver first.';
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
    CommitSummaryRow(label: 'Driver', value: driverName, emphasis: true),
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
      value: '${order.lines.length} lines · qty ${qty.round()}',
    ),
  ];
}
