import '../../../design_system/chrome/cb_commit_confirm.dart';
import 'cart.dart';
import 'payment.dart';

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

List<CommitSummaryRow> posCloseSaleRows({
  required PosCart cart,
  required CheckoutKind kind,
  required double paid,
}) {
  final balance = accountBalanceDue(cart.total, paid);
  return [
    CommitSummaryRow(
      label: 'Customer',
      value: cart.customerName?.trim().isNotEmpty == true
          ? cart.customerName!
          : 'Walk-in',
    ),
    CommitSummaryRow(
      label: 'Items',
      value: '${cart.lines.length} line${cart.lines.length == 1 ? '' : 's'}',
    ),
    CommitSummaryRow(label: 'Total', value: _kes(cart.total), emphasis: true),
    if (kind != CheckoutKind.payLater)
      CommitSummaryRow(label: 'Collected now', value: _kes(paid)),
    if (kind != CheckoutKind.full)
      CommitSummaryRow(
        label: 'On account',
        value: _kes(balance),
        emphasis: true,
      ),
  ];
}
