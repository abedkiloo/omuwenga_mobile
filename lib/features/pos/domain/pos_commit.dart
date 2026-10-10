import '../../../design_system/chrome/cb_commit_confirm.dart';
import 'cart.dart';
import 'payment.dart';
import '../../../core/format/money.dart';


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
    CommitSummaryRow(label: 'Total', value: formatKes(cart.total), emphasis: true),
    if (kind != CheckoutKind.payLater)
      CommitSummaryRow(label: 'Collected now', value: formatKes(paid)),
    if (kind != CheckoutKind.full)
      CommitSummaryRow(
        label: 'On account',
        value: formatKes(balance),
        emphasis: true,
      ),
  ];
}
