import '../../../core/format/money.dart';

/// Wallet debt helpers — negative balance means the customer owes money.
double debtAmountFromWalletBalance(double? walletBalance) {
  if (walletBalance == null) return 0;
  if (walletBalance >= 0) return 0;
  return -walletBalance;
}

enum CustomerStanding { good, debt, credit }

CustomerStanding standingFromWallet(double? walletBalance) {
  if (walletBalance == null || walletBalance == 0) return CustomerStanding.good;
  if (walletBalance < 0) return CustomerStanding.debt;
  return CustomerStanding.credit;
}

String standingLabel(
  CustomerStanding standing, {
  required double debtAmount,
  required double credit,
}) {
  switch (standing) {
    case CustomerStanding.debt:
      return 'Owes ${formatGroupedNumber(debtAmount)}';
    case CustomerStanding.credit:
      return 'Credit ${formatGroupedNumber(credit)}';
    case CustomerStanding.good:
      return 'Good standing';
  }
}
