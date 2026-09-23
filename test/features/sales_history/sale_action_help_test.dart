import 'package:completebyte_pos_mobile/features/sales_history/domain/sale_action_help.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('refund and rollback copy stay distinct', () {
    expect(SaleActionHelp.refund.shortLabel, 'Void / refund');
    expect(SaleActionHelp.refund.body, contains('customer returns'));
    expect(SaleActionHelp.refund.contrast, contains('Roll back'));
    expect(SaleActionHelp.rollback.body, contains('should never have been recorded'));
    expect(SaleActionHelp.rollback.contrast, contains('Void / refund'));
  });
}
