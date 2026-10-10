import 'package:completebyte_pos_mobile/core/format/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatGroupedNumber inserts thousand separators', () {
    expect(formatGroupedNumber(1000), '1,000.00');
    expect(formatGroupedNumber(1234567.8), '1,234,567.80');
    expect(formatGroupedNumber(500, fractionDigits: 0), '500');
  });

  test('formatKes prefixes currency', () {
    expect(formatKes(1000), 'KES 1,000.00');
    expect(formatKes(1000, dropTrailingZeros: true), 'KES 1,000');
    expect(formatKesSigned(-2500), '-KES 2,500.00');
  });
}
