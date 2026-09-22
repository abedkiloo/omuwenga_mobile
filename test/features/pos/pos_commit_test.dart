import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/payment.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/pos_commit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const line = CartLine(
    productId: 1,
    name: 'Cement',
    unitPrice: 100,
    quantity: 2,
  );

  test('full payment shows collected now and walk-in fallback', () {
    final rows = posCloseSaleRows(
      cart: const PosCart(lines: [line]),
      kind: CheckoutKind.full,
      paid: 200,
    );
    expect(rows.where((r) => r.label == 'Customer').single.value, 'Walk-in');
    expect(rows.where((r) => r.label == 'Items').single.value, '1 line');
    expect(rows.any((r) => r.label == 'Collected now'), isTrue);
    expect(rows.any((r) => r.label == 'On account'), isFalse);

    final blankName = posCloseSaleRows(
      cart: const PosCart(lines: [line], customerName: '  '),
      kind: CheckoutKind.full,
      paid: 200,
    );
    expect(blankName.where((r) => r.label == 'Customer').single.value, 'Walk-in');
  });

  test('partial and pay-later include the account balance', () {
    final named = PosCart(
      lines: const [line, line],
      customerName: ' Ada ',
    );
    final partial = posCloseSaleRows(
      cart: named,
      kind: CheckoutKind.partial,
      paid: 50,
    );
    expect(partial.where((r) => r.label == 'Customer').single.value, ' Ada ');
    expect(partial.where((r) => r.label == 'Items').single.value, '2 lines');
    expect(partial.any((r) => r.label == 'On account'), isTrue);

    final later = posCloseSaleRows(
      cart: named,
      kind: CheckoutKind.payLater,
      paid: 0,
    );
    expect(later.any((r) => r.label == 'Collected now'), isFalse);
    expect(later.any((r) => r.label == 'On account'), isTrue);
  });
}
