import 'package:completebyte_pos_mobile/design_system/chrome/cb_commit_confirm.dart';
import 'package:completebyte_pos_mobile/features/field_orders/domain/field_order.dart';
import 'package:completebyte_pos_mobile/features/field_orders/domain/field_order_commit.dart';
import 'package:completebyte_pos_mobile/features/field_orders/domain/site_pin.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CartLine _line({double qty = 2, String name = 'Cement'}) => CartLine(
  productId: 1,
  name: name,
  unitPrice: 150,
  quantity: qty,
);

void main() {
  group('visitOrderPlaceError', () {
    test('requires customer, products, qty, and pin', () {
      expect(
        visitOrderPlaceError(
          hasCustomer: false,
          hasProducts: false,
          hasPin: false,
        ),
        'Select a customer first.',
      );
      expect(
        visitOrderPlaceError(
          hasCustomer: true,
          hasProducts: false,
          hasPin: false,
        ),
        'Add at least one product.',
      );
      expect(
        visitOrderPlaceError(
          hasCustomer: true,
          hasProducts: true,
          hasPin: true,
          lines: [_line(qty: 0)],
        ),
        'Each product needs a quantity greater than zero.',
      );
      expect(
        visitOrderPlaceError(
          hasCustomer: true,
          hasProducts: true,
          hasPin: false,
          lines: [_line()],
        ),
        'Pin the delivery drop location.',
      );
      expect(
        visitOrderPlaceError(
          hasCustomer: true,
          hasProducts: true,
          hasPin: true,
          lines: [_line()],
        ),
        isNull,
      );
    });
  });

  test('visitOrderCommitRows include pin, landmark, and empty pin fallback', () {
    final withPin = visitOrderCommitRows(
      customerName: 'Ada',
      lines: [_line()],
      pin: const SitePin(latitude: -1.2921, longitude: 36.8219),
      landmark: ' Blue gate ',
    );
    expect(withPin.map((r) => r.label), containsAll(['Customer', 'Landmark']));
    expect(withPin.first.emphasis, isTrue);

    final noPin = visitOrderCommitRows(
      customerName: 'Ada',
      lines: [_line()],
    );
    expect(noPin.where((r) => r.label == 'Drop pin').single.value, '—');
    expect(noPin.any((r) => r.label == 'Landmark'), isFalse);
  });

  test('fieldOrderReviewError and rows', () {
    expect(fieldOrderReviewError(const FieldOrderCart(siteId: 0)), 'Site is required.');
    expect(
      fieldOrderReviewError(const FieldOrderCart(siteId: 7)),
      'Add at least one product.',
    );
    expect(
      fieldOrderReviewError(
        FieldOrderCart(siteId: 7, lines: [_line(qty: 0)]),
      ),
      'Each product needs a quantity greater than zero.',
    );
    expect(
      fieldOrderReviewError(FieldOrderCart(siteId: 7, lines: [_line()])),
      isNull,
    );

    final unlabeled = fieldOrderReviewRows(
      FieldOrderCart(siteId: 7, lines: [_line()]),
    );
    expect(unlabeled.first.value, 'Site #7');
    expect(unlabeled.where((r) => r.label == 'Drop pin').single.value, '—');

    final labeled = fieldOrderReviewRows(
      FieldOrderCart(
        siteId: 7,
        siteLabel: 'Gate',
        latitude: -1.2,
        longitude: 36.8,
        lines: [_line()],
      ),
    );
    expect(labeled.first.value, 'Gate');
    expect(labeled.where((r) => r.label == 'Drop pin').single.value, contains('-1.20000'));
  });

  test('dispatch and claim rows hide blank customer names', () {
    const blank = FieldOrderSummary(
      id: 11,
      status: FieldOrderStatus.submitted,
      siteId: 1,
    );
    expect(dispatchPackRows(blank).where((r) => r.label == 'Customer').single.value, '—');
    expect(
      dispatchAssignRows(order: blank, driverName: 'Jane')
          .where((r) => r.label == 'Driver')
          .single
          .value,
      'Jane',
    );
    expect(deliveryClaimRows(blank).where((r) => r.label == 'Customer').single.value, '—');

    const named = FieldOrderSummary(
      id: 12,
      status: FieldOrderStatus.ready,
      siteId: 1,
      customerName: 'Ada',
      lines: [
        CartLine(productId: 1, name: 'A', unitPrice: 10, quantity: 2),
      ],
    );
    expect(dispatchPackRows(named).where((r) => r.label == 'Customer').single.value, 'Ada');
    expect(deliveryClaimRows(named).where((r) => r.label == 'Customer').single.value, 'Ada');
    expect(
      dispatchAssignRows(order: named, driverName: 'Jane')
          .where((r) => r.label == 'Customer')
          .single
          .value,
      'Ada',
    );
  });

  test('dispatchAssignError', () {
    expect(
      dispatchAssignError(canAssign: true, driverId: null),
      'Select a delivery driver first.',
    );
    expect(
      dispatchAssignError(canAssign: false, driverId: 3),
      'This order cannot be assigned yet.',
    );
    expect(dispatchAssignError(canAssign: true, driverId: 3), isNull);
  });

  testWidgets('showCommitConfirm confirms and cancels', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCommitConfirm(
                context: context,
                title: 'Pack this order?',
                description: 'Review first.',
                rows: const [
                  CommitSummaryRow(label: 'Order', value: '#11', emphasis: true),
                  CommitSummaryRow(label: 'Customer', value: 'Ada'),
                ],
                confirmKey: const Key('unit_confirm'),
                cancelKey: const Key('unit_cancel'),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Pack this order?'), findsOneWidget);
    expect(find.text('Review first.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('unit_cancel')));
    await tester.pumpAndSettle();
    expect(find.text('Pack this order?'), findsNothing);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('unit_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Pack this order?'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showCommitConfirm(
                context: context,
                title: 'Submit?',
                description: '',
                confirmKey: const Key('unit_confirm'),
                cancelKey: const Key('unit_cancel'),
              ),
              child: const Text('open2'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open2'));
    await tester.pumpAndSettle();
    expect(find.text('Submit?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('unit_confirm')));
    await tester.pumpAndSettle();
  });
}
