import 'cart.dart';

/// Normalize a raw scan / typed code for comparison.
///
/// Trims whitespace and caps length at 128. Empty / null → empty string.
String normalizeScanCode(Object? value) {
  if (value == null) return '';
  final text = value.toString().trim();
  if (text.length <= 128) return text;
  return text.substring(0, 128);
}

/// True when [product] is an exact SKU or barcode hit for [code].
///
/// Name-only matches are never scan hits (avoids wrong auto-add).
bool productMatchesScanCode(CatalogProduct? product, String code) {
  final needle = normalizeScanCode(code).toLowerCase();
  if (product == null || needle.isEmpty) return false;
  final sku = normalizeScanCode(product.sku).toLowerCase();
  final barcode = normalizeScanCode(product.barcode).toLowerCase();
  return sku == needle || barcode == needle;
}

/// Why [pickExactScanProduct] accepted or rejected a hit.
enum ScanPickReason { exact, ambiguous, none, empty }

/// Result of picking a product for auto-add from search rows.
class ScanPickResult {
  const ScanPickResult({this.product, required this.reason});

  final CatalogProduct? product;
  final ScanPickReason reason;
}

/// Pick a single product for auto-add from [results].
ScanPickResult pickExactScanProduct(
  Iterable<CatalogProduct>? results,
  String code,
) {
  final list = results?.toList() ?? const <CatalogProduct>[];
  final needle = normalizeScanCode(code);
  if (needle.isEmpty) {
    return const ScanPickResult(reason: ScanPickReason.empty);
  }
  final exact = list.where((row) => productMatchesScanCode(row, needle)).toList();
  if (exact.length == 1) {
    return ScanPickResult(product: exact.first, reason: ScanPickReason.exact);
  }
  if (exact.length > 1) {
    return const ScanPickResult(reason: ScanPickReason.ambiguous);
  }
  // Backend may return a parent after a variant barcode hit.
  if (list.length == 1 && looksLikeScanCode(needle)) {
    return ScanPickResult(product: list.first, reason: ScanPickReason.exact);
  }
  return const ScanPickResult(reason: ScanPickReason.none);
}

/// Heuristic: codes with digits that look like barcodes/SKUs, not names.
bool looksLikeScanCode(String code) {
  final raw = normalizeScanCode(code);
  if (raw.length < 3 || raw.length > 64) return false;
  final scanLike = RegExp(r'^[0-9A-Za-z\-_.]+$');
  if (!scanLike.hasMatch(raw)) return false;
  return RegExp(r'[0-9]').hasMatch(raw);
}

/// Last successful / attempted scan stamp for debounce.
class ScanStamp {
  const ScanStamp({required this.code, required this.at});

  final String code;
  final DateTime at;
}

/// True when [code] matches [last] within [window] (default 450ms).
bool isDuplicateScan(
  ScanStamp? last,
  String code, {
  Duration window = const Duration(milliseconds: 450),
  DateTime Function()? now,
}) {
  final needle = normalizeScanCode(code);
  if (needle.isEmpty || last == null) return false;
  final ms = window.inMilliseconds.clamp(100, 2000);
  final clock = now?.call() ?? DateTime.now();
  return normalizeScanCode(last.code) == needle &&
      clock.difference(last.at).inMilliseconds < ms;
}
