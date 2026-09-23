import 'package:completebyte_pos_mobile/features/customers/domain/mpesa_receipt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeMpesaReceipt', () {
    test('trims, uppercases, and drops spaces', () {
      expect(normalizeMpesaReceipt('  qhx 7k2 l9m1 '), 'QHX7K2L9M1');
      expect(normalizeMpesaReceipt(''), '');
    });
  });

  group('paymentAmountValidationMessage', () {
    test('explains empty, non-numeric, and zero amounts', () {
      expect(
        paymentAmountValidationMessage(null),
        'Enter a KES amount, e.g. 250.00',
      );
      expect(
        paymentAmountValidationMessage('  '),
        'Enter a KES amount, e.g. 250.00',
      );
      expect(
        paymentAmountValidationMessage('abc'),
        'Use numbers only, up to 2 decimal places, e.g. 250.00',
      );
      expect(
        paymentAmountValidationMessage('12.345'),
        'Use numbers only, up to 2 decimal places, e.g. 250.00',
      );
      expect(
        paymentAmountValidationMessage('0'),
        'Amount must be greater than zero, e.g. 250.00',
      );
      expect(paymentAmountValidationMessage('250'), isNull);
      expect(paymentAmountValidationMessage('1,250.50'), isNull);
    });

    test('parsePaymentAmount returns a number only when valid', () {
      expect(parsePaymentAmount(''), isNull);
      expect(parsePaymentAmount('0'), isNull);
      expect(parsePaymentAmount('1,250.50'), 1250.50);
    });
  });

  group('mpesaReceiptValidationMessage', () {
    test('requires a code and shows the expected format', () {
      expect(
        mpesaReceiptValidationMessage(null),
        'Enter the M-Pesa code from the SMS (at least 4 letters and numbers), e.g. QHX7K2L9M1',
      );
      expect(
        mpesaReceiptValidationMessage('   '),
        'Enter the M-Pesa code from the SMS (at least 4 letters and numbers), e.g. QHX7K2L9M1',
      );
    });

    test('rejects symbols and codes shorter than 4', () {
      expect(
        mpesaReceiptValidationMessage('QHX-7K2'),
        'Use letters and numbers only, e.g. QHX7K2L9M1',
      );
      expect(
        mpesaReceiptValidationMessage('AB1'),
        'Must be at least 4 characters (you entered 3), e.g. QHX7K2L9M1',
      );
    });

    test('accepts codes of 4 or more letters and numbers', () {
      expect(mpesaReceiptValidationMessage('AB12'), isNull);
      expect(mpesaReceiptValidationMessage('ABC12'), isNull);
      expect(mpesaReceiptValidationMessage('QHX7K2L9M1'), isNull);
      expect(mpesaReceiptValidationMessage('QHX7K2L9M1X'), isNull);
      expect(mpesaReceiptValidationMessage(' qhx 7k2 l9m1 '), isNull);
    });
  });

  group('email and phone', () {
    test('emailValidationMessage explains the expected shape', () {
      expect(emailValidationMessage(null), isNull);
      expect(
        emailValidationMessage('', required: true),
        'Enter an email, e.g. name@example.com',
      );
      expect(
        emailValidationMessage('not-an-email'),
        contains('name@example.com'),
      );
      expect(emailValidationMessage('name@example.com'), isNull);
    });

    test('phoneValidationMessage accepts Kenyan mobiles', () {
      expect(phoneValidationMessage(null), isNull);
      expect(
        phoneValidationMessage('', required: true),
        contains('0712 345 678'),
      );
      expect(phoneValidationMessage('abc'), contains('Letters are not allowed'));
      expect(phoneValidationMessage('123'), contains('You entered 3 digits'));
      expect(phoneValidationMessage('0712345678'), isNull);
      expect(phoneValidationMessage('+254712345678'), isNull);
    });
  });

  group('name date integer', () {
    test('requiredTextMessage uses the example', () {
      expect(
        requiredTextMessage('', label: 'customer name', example: 'Jane Wambua'),
        'Enter customer name, e.g. Jane Wambua',
      );
      expect(
        requiredTextMessage('A', label: 'customer name', example: 'Jane Wambua', minLength: 2),
        contains('at least 2'),
      );
    });

    test('dateValidationMessage requires YYYY-MM-DD', () {
      expect(dateValidationMessage(''), contains('2026-09-22'));
      expect(dateValidationMessage('22/09/2026'), contains('YYYY-MM-DD'));
      expect(dateValidationMessage('2026-09-22'), isNull);
    });

    test('integerValidationMessage rejects decimals', () {
      expect(integerValidationMessage(''), isNull);
      expect(integerValidationMessage('1.5'), contains('whole number'));
      expect(integerValidationMessage('3', min: 1), isNull);
    });
  });
}
