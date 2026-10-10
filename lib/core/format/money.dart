/// Grouped money / number display for the store app (e.g. 1,000.00).
String formatGroupedNumber(num value, {int fractionDigits = 2}) {
  final n = value.toDouble();
  final sign = n < 0 ? '-' : '';
  final abs = n.abs();
  final fixed = abs.toStringAsFixed(fractionDigits);
  final parts = fixed.split('.');
  final whole = parts[0];
  final grouped = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    final remaining = whole.length - i;
    if (i > 0 && remaining % 3 == 0) grouped.write(',');
    grouped.write(whole[i]);
  }
  if (fractionDigits <= 0 || parts.length < 2) {
    return '$sign${grouped.toString()}';
  }
  return '$sign${grouped.toString()}.${parts[1]}';
}

/// `KES 1,234.56` — drop `.00` when the value is a whole number.
String formatKes(num value, {bool dropTrailingZeros = false}) {
  final n = value.toDouble();
  if (dropTrailingZeros && n == n.roundToDouble()) {
    return 'KES ${formatGroupedNumber(n, fractionDigits: 0)}';
  }
  return 'KES ${formatGroupedNumber(n)}';
}

/// Same as [formatKes] but allows a leading minus outside the prefix.
String formatKesSigned(num value) {
  final n = value.toDouble();
  if (n < 0) return '-${formatKes(-n)}';
  return formatKes(n);
}
