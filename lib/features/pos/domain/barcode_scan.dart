import 'cart.dart';

/// Retail POS duplicate-scan window (continuous camera sweep).
///
/// Industry mobile POS typically uses ~1.0–1.2s so holding a label in frame
/// does not double-add. Clamped by [isDuplicateScan] to 100–2500ms.
const Duration kPosContinuousScanDebounce = Duration(milliseconds: 1200);

/// Normalize a raw scan / typed code for comparison.
///
/// Trims whitespace and caps length at 128. Empty / null → empty string.
String normalizeScanCode(Object? value) {
  if (value == null) return '';
  final text = value.toString().trim();
  if (text.length <= 128) return text;
  return text.substring(0, 128);
}

/// Extract a product SKU/barcode/GTIN from a camera or QR payload.
///
/// Supports:
/// - plain barcode / SKU text
/// - GS1 AI `(01)GTIN` and bare `01` + 14-digit GTIN
/// - http(s) URLs with `barcode` / `sku` / `gtin` / `ean` / `code` query
///   params, or a trailing path segment
///
/// Returns a normalized code (max 128). Empty / null → empty string.
String extractProductScanCode(Object? value) {
  final raw = normalizeScanCode(value);
  if (raw.isEmpty) return '';

  final gs1Paren = RegExp(r'^\(01\)(\d{8,14})$').firstMatch(raw);
  if (gs1Paren != null) return normalizeScanCode(gs1Paren.group(1));

  final gs1Bare = RegExp(r'^01(\d{14})$').firstMatch(raw);
  if (gs1Bare != null) return normalizeScanCode(gs1Bare.group(1));

  final uri = Uri.tryParse(raw);
  if (uri != null &&
      (uri.scheme == 'http' || uri.scheme == 'https') &&
      uri.host.isNotEmpty) {
    const keys = ['barcode', 'sku', 'gtin', 'ean', 'code', 'id'];
    for (final key in keys) {
      final q = uri.queryParameters[key];
      if (q != null && q.trim().isNotEmpty) {
        return normalizeScanCode(q);
      }
    }
    final segments =
        uri.pathSegments.where((s) => s.trim().isNotEmpty).toList();
    if (segments.isNotEmpty) {
      const skip = {
        'product',
        'products',
        'p',
        'item',
        'items',
        'sku',
        'barcode',
      };
      final last = segments.last;
      if (!skip.contains(last.toLowerCase())) {
        return normalizeScanCode(last);
      }
      if (segments.length >= 2) {
        return normalizeScanCode(segments[segments.length - 2]);
      }
    }
  }

  return raw;
}

/// Alternate forms of a scanned numeric code (UPC-A ↔ EAN-13, check digit).
///
/// Phone cameras often return EAN-13 with a leading zero or check digit while
/// the catalog stores UPC-A / 12-digit values (or the reverse). Returns 1–4
/// unique strings; empty input → empty list. Max candidate length 128.
List<String> scanCodeCandidates(Object? value) {
  final code = normalizeScanCode(value);
  if (code.isEmpty) return const [];
  final out = <String>{code};
  final digitsOnly = RegExp(r'^\d+$').hasMatch(code);
  if (digitsOnly) {
    if (code.length == 13 && code.startsWith('0')) {
      out.add(code.substring(1));
    }
    if (code.length == 12) {
      out.add('0$code');
    }
    if (code.length == 13) {
      out.add(code.substring(0, 12));
    }
    if (code.length == 8) {
      out.add(code.padLeft(13, '0'));
    }
    // GTIN-14 → trim leading zero to EAN-13 when present.
    if (code.length == 14 && code.startsWith('0')) {
      out.add(code.substring(1));
      out.add(code.substring(1, 13));
    }
  }
  return out.toList();
}

/// True when [product] is an exact SKU or barcode hit for [code].
///
/// Name-only matches are never scan hits (avoids wrong auto-add).
/// Also matches UPC/EAN length variants via [scanCodeCandidates].
bool productMatchesScanCode(CatalogProduct? product, String code) {
  if (product == null) return false;
  final needles = scanCodeCandidates(code)
      .map((c) => c.toLowerCase())
      .where((c) => c.isNotEmpty)
      .toSet();
  if (needles.isEmpty) return false;

  bool hits(Object? field) {
    for (final candidate in scanCodeCandidates(field)) {
      if (needles.contains(candidate.toLowerCase())) return true;
    }
    return false;
  }

  return hits(product.sku) || hits(product.barcode);
}

/// Why [pickExactScanProduct] accepted or rejected a hit.
enum ScanPickReason { exact, ambiguous, none, empty }

/// Result of picking a product for auto-add from search rows.
class ScanPickResult {
  const ScanPickResult({this.product, required this.reason});

  final CatalogProduct? product;
  final ScanPickReason reason;
}

/// Inline feedback for continuous camera scan (success / miss / stock).
class PosScanFeedback {
  const PosScanFeedback({
    required this.ok,
    required this.message,
  });

  /// True when a cart line was added (or variant picker completed).
  final bool ok;

  /// Short cashier-facing message (max ~160 chars recommended). Empty when
  /// the scan was ignored (duplicate / busy).
  final String message;

  /// Duplicate or in-flight scan — scanner should not flash an error.
  static const ignored = PosScanFeedback(ok: false, message: '');

  bool get isIgnored => message.isEmpty && !ok;
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
  final exact =
      list.where((row) => productMatchesScanCode(row, needle)).toList();
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
///
/// [window] is clamped to 100–2500ms (covers HID gun + continuous camera).
bool isDuplicateScan(
  ScanStamp? last,
  String code, {
  Duration window = const Duration(milliseconds: 450),
  DateTime Function()? now,
}) {
  final needle = normalizeScanCode(code);
  if (needle.isEmpty || last == null) return false;
  final ms = window.inMilliseconds.clamp(100, 2500);
  final clock = now?.call() ?? DateTime.now();
  return normalizeScanCode(last.code) == needle &&
      clock.difference(last.at).inMilliseconds < ms;
}
