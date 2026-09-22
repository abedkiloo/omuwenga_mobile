/// Shared typed-input validation with examples in the messages.

const kPaymentAmountExample = '250.00';
const kPaymentAmountHelper =
    'KES amount with up to 2 decimal places, e.g. $kPaymentAmountExample';

const kMpesaReceiptExample = 'QHX7K2L9M1';
const kMpesaReceiptHelper =
    '10 letters and numbers from the M-Pesa SMS, e.g. $kMpesaReceiptExample';
const kMpesaReceiptLength = 10;

const kEmailExample = 'name@example.com';
const kEmailHelper = 'Email address, e.g. $kEmailExample';

const kPhoneExample = '0712 345 678';
const kPhoneHelper = 'Kenyan mobile, e.g. $kPhoneExample';

const kDateExample = '2026-09-22';
const kQuantityExample = '3';
const kNameExample = 'Jane Wambua';

final _emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _moneyRe = RegExp(r'^\d+(\.\d{1,2})?$');
final _signedMoneyRe = RegExp(r'^-?\d+(\.\d{1,2})?$');
final _intRe = RegExp(r'^-?\d+$');
final _isoDateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

String normalizeMpesaReceipt(String raw) {
  return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
}

String normalizePaymentAmountInput(String raw) {
  return raw.trim().replaceAll(',', '');
}

String? moneyValidationMessage(
  String? raw, {
  bool required = true,
  bool allowZero = false,
  bool allowNegative = false,
}) {
  final text = normalizePaymentAmountInput(raw ?? '');
  if (text.isEmpty) {
    if (!required) return null;
    return 'Enter a KES amount, e.g. $kPaymentAmountExample';
  }
  final pattern = allowNegative ? _signedMoneyRe : _moneyRe;
  if (!pattern.hasMatch(text)) {
    return 'Use numbers only, up to 2 decimal places, e.g. $kPaymentAmountExample';
  }
  final amount = double.parse(text);
  if (!allowNegative && amount < 0) {
    return 'Amount cannot be negative, e.g. $kPaymentAmountExample';
  }
  if (!allowZero && amount <= 0) {
    return 'Amount must be greater than zero, e.g. $kPaymentAmountExample';
  }
  return null;
}

/// Returns null when [raw] is a valid KES amount greater than zero.
String? paymentAmountValidationMessage(String? raw) {
  return moneyValidationMessage(raw);
}

double? parsePaymentAmount(String? raw) {
  if (paymentAmountValidationMessage(raw) != null) return null;
  return double.parse(normalizePaymentAmountInput(raw ?? ''));
}

double? parseMoney(
  String? raw, {
  bool allowZero = false,
  bool required = true,
}) {
  if (moneyValidationMessage(
        raw,
        allowZero: allowZero,
        required: required,
      ) !=
      null) {
    return null;
  }
  final text = normalizePaymentAmountInput(raw ?? '');
  if (text.isEmpty) return 0;
  return double.parse(text);
}

/// Returns a field message when the M-Pesa code is missing or the wrong shape.
String? mpesaReceiptValidationMessage(String? raw) {
  final code = normalizeMpesaReceipt(raw ?? '');
  if (code.isEmpty) {
    return 'Enter the 10-character M-Pesa code from the SMS, e.g. $kMpesaReceiptExample';
  }
  if (!RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
    return 'Use letters and numbers only, e.g. $kMpesaReceiptExample';
  }
  if (code.length != kMpesaReceiptLength) {
    return 'Expected 10 characters (you entered ${code.length}), e.g. $kMpesaReceiptExample';
  }
  return null;
}

String? emailValidationMessage(String? raw, {bool required = false}) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    if (required) return 'Enter an email, e.g. $kEmailExample';
    return null;
  }
  if (!_emailRe.hasMatch(text)) {
    final shown = text.length <= 40 ? text : '${text.substring(0, 37)}...';
    return 'Enter an email like $kEmailExample. "$shown" is not a valid email.';
  }
  return null;
}

String? phoneValidationMessage(String? raw, {bool required = false}) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    if (required) return 'Enter a Kenyan mobile, e.g. $kPhoneExample';
    return null;
  }
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return 'Enter a Kenyan mobile, e.g. $kPhoneExample. Letters are not allowed.';
  }
  final ok = (digits.startsWith('254') && digits.length == 12) ||
      (digits.startsWith('0') && digits.length == 10) ||
      (digits.length == 9 && (digits.startsWith('1') || digits.startsWith('7')));
  if (!ok) {
    return 'Enter a Kenyan mobile, e.g. $kPhoneExample. You entered ${digits.length} digits.';
  }
  return null;
}

String? requiredTextMessage(
  String? raw, {
  required String label,
  required String example,
  int minLength = 1,
}) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    return 'Enter $label, e.g. $example';
  }
  if (text.length < minLength) {
    final titled = '${label[0].toUpperCase()}${label.substring(1)}';
    return '$titled must be at least $minLength characters, e.g. $example';
  }
  return null;
}

String? dateValidationMessage(
  String? raw, {
  bool required = true,
  String label = 'date',
}) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    if (required) return 'Enter a $label, e.g. $kDateExample';
    return null;
  }
  if (!_isoDateRe.hasMatch(text)) {
    return 'Use YYYY-MM-DD, e.g. $kDateExample';
  }
  final parts = text.split('-').map(int.parse).toList();
  final parsed = DateTime.tryParse(text);
  if (parsed == null ||
      parsed.year != parts[0] ||
      parsed.month != parts[1] ||
      parsed.day != parts[2]) {
    return 'Use a real calendar date, e.g. $kDateExample';
  }
  return null;
}

String? integerValidationMessage(
  String? raw, {
  bool required = false,
  int min = 0,
  String label = 'whole number',
  String example = kQuantityExample,
}) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) {
    if (required) return 'Enter a $label, e.g. $example';
    return null;
  }
  if (!_intRe.hasMatch(text)) {
    return 'Use a whole number (no decimals), e.g. $example';
  }
  final number = int.parse(text);
  if (number < min) {
    final titled = '${label[0].toUpperCase()}${label.substring(1)}';
    return '$titled must be at least $min, e.g. $example';
  }
  return null;
}
