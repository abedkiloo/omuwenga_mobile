/// Display helpers mirroring backend `classify_sale_payment`.
enum PaymentStatusDisplay { paid, debt, partial }

PaymentStatusDisplay classifyPaymentStatus({
  required double total,
  required double amountPaid,
}) {
  final tot = total < 0 ? 0.0 : total;
  final paid = amountPaid < 0 ? 0.0 : amountPaid;
  final paidAmount = paid > tot ? tot : paid;
  final debtAmount = tot - paidAmount;
  if (debtAmount <= 1e-9) return PaymentStatusDisplay.paid;
  if (paidAmount <= 1e-9) return PaymentStatusDisplay.debt;
  return PaymentStatusDisplay.partial;
}

String paymentStatusLabel(PaymentStatusDisplay status) {
  switch (status) {
    case PaymentStatusDisplay.paid:
      return 'Paid';
    case PaymentStatusDisplay.debt:
      return 'Debt';
    case PaymentStatusDisplay.partial:
      return 'Partial';
  }
}

PaymentStatusDisplay? tryParsePaymentStatus(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'paid':
      return PaymentStatusDisplay.paid;
    case 'debt':
      return PaymentStatusDisplay.debt;
    case 'partial':
      return PaymentStatusDisplay.partial;
    default:
      return null;
  }
}

String formatApiDate(DateTime day) {
  final y = day.year.toString().padLeft(4, '0');
  final m = day.month.toString().padLeft(2, '0');
  final d = day.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime? parseApiDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final parts = raw.trim().split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

DateTime previousDay(DateTime day) =>
    DateTime(day.year, day.month, day.day).subtract(const Duration(days: 1));

DateTime nextDay(DateTime day) =>
    DateTime(day.year, day.month, day.day).add(const Duration(days: 1));
