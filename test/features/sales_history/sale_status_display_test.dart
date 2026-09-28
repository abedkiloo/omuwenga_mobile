import 'package:completebyte_pos_mobile/features/sales_history/domain/payment_status.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/sale.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/sale_status_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('describeSaleLifecycle', () {
    test('cancelled stays cancelled even when fully paid', () {
      final display = describeSaleLifecycle(
        status: 'cancelled',
        refundStatus: 'none',
        payment: PaymentStatusDisplay.paid,
      );
      expect(display.label, 'Cancelled');
      expect(display.inactive, isTrue);
    });

    test('fully refunded completed sale is voided', () {
      final display = describeSaleLifecycle(
        status: 'completed',
        refundStatus: 'refunded',
        payment: PaymentStatusDisplay.paid,
      );
      expect(display.label, 'Voided');
      expect(display.inactive, isTrue);
    });

    test('partial refund is not settled', () {
      final display = describeSaleLifecycle(
        status: 'completed',
        refundStatus: 'partial',
        payment: PaymentStatusDisplay.paid,
      );
      expect(display.label, 'Partial refund');
      expect(display.inactive, isFalse);
    });

    test('pending and holding beat payment status', () {
      expect(
        describeSaleLifecycle(
          status: 'pending_approval',
          payment: PaymentStatusDisplay.paid,
        ).label,
        'Awaiting approval',
      );
      expect(
        describeSaleLifecycle(
          status: 'holding',
          payment: PaymentStatusDisplay.debt,
        ).label,
        'On hold',
      );
    });

    test('open completed sales use payment status', () {
      expect(
        describeSaleLifecycle(
          status: 'completed',
          refundStatus: 'none',
          payment: PaymentStatusDisplay.paid,
        ).label,
        'Completed & Settled',
      );
      expect(
        describeSaleLifecycle(
          status: 'completed',
          payment: PaymentStatusDisplay.debt,
        ).label,
        'Debt',
      );
      expect(
        describeSaleLifecycle(
          status: 'completed',
          payment: PaymentStatusDisplay.partial,
        ).label,
        'Partial',
      );
    });
  });

  test('summary and detail share the same lifecycle label', () {
    const json = {
      'id': 9,
      'sale_number': 'S-9',
      'total': '100',
      'amount_paid': '100',
      'status': 'cancelled',
      'refund_status': 'refunded',
      'customer_name': 'Ann',
    };
    final list = SaleSummary.fromJson(json);
    final detail = SaleDetail.fromJson(json);
    expect(list.lifecycle.label, detail.lifecycle.label);
    expect(list.lifecycle.label, 'Cancelled');
    expect(detail.paymentStatus, PaymentStatusDisplay.paid);
  });
}
