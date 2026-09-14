import 'package:completebyte_pos_mobile/features/sales_history/domain/payment_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('classifyPaymentStatus', () {
    test('paid when fully covered', () {
      expect(
        classifyPaymentStatus(total: 100, amountPaid: 100),
        PaymentStatusDisplay.paid,
      );
      expect(
        classifyPaymentStatus(total: 100, amountPaid: 120),
        PaymentStatusDisplay.paid,
      );
    });

    test('debt when nothing paid', () {
      expect(
        classifyPaymentStatus(total: 100, amountPaid: 0),
        PaymentStatusDisplay.debt,
      );
    });

    test('partial when some paid', () {
      expect(
        classifyPaymentStatus(total: 100, amountPaid: 40),
        PaymentStatusDisplay.partial,
      );
    });
  });

  test('labels and parse', () {
    expect(paymentStatusLabel(PaymentStatusDisplay.paid), 'Paid');
    expect(paymentStatusLabel(PaymentStatusDisplay.debt), 'Debt');
    expect(paymentStatusLabel(PaymentStatusDisplay.partial), 'Partial');
    expect(tryParsePaymentStatus('DEBT'), PaymentStatusDisplay.debt);
    expect(tryParsePaymentStatus('nope'), isNull);
  });

  test('day navigation helpers', () {
    final day = DateTime(2026, 9, 14);
    expect(formatApiDate(day), '2026-09-14');
    expect(parseApiDate('2026-09-14'), DateTime(2026, 9, 14));
    expect(parseApiDate('bad'), isNull);
    expect(formatApiDate(previousDay(day)), '2026-09-13');
    expect(formatApiDate(nextDay(day)), '2026-09-15');
  });
}
