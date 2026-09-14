import 'package:completebyte_pos_mobile/features/customers/domain/wallet_debt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('debtAmountFromWalletBalance', () {
    test('negative wallet is debt owed', () {
      expect(debtAmountFromWalletBalance(-250), 250);
      expect(debtAmountFromWalletBalance(-0.5), 0.5);
    });

    test('zero / positive / null is no debt', () {
      expect(debtAmountFromWalletBalance(0), 0);
      expect(debtAmountFromWalletBalance(40), 0);
      expect(debtAmountFromWalletBalance(null), 0);
    });
  });

  group('standing', () {
    test('from wallet', () {
      expect(standingFromWallet(null), CustomerStanding.good);
      expect(standingFromWallet(0), CustomerStanding.good);
      expect(standingFromWallet(-10), CustomerStanding.debt);
      expect(standingFromWallet(10), CustomerStanding.credit);
    });

    test('labels', () {
      expect(
        standingLabel(CustomerStanding.debt, debtAmount: 100, credit: 0),
        'Owes 100.00',
      );
      expect(
        standingLabel(CustomerStanding.credit, debtAmount: 0, credit: 25),
        'Credit 25.00',
      );
      expect(
        standingLabel(CustomerStanding.good, debtAmount: 0, credit: 0),
        'Good standing',
      );
    });
  });
}
