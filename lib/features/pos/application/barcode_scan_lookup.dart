import '../../../core/result/result.dart';
import '../data/pos_api.dart';
import '../domain/barcode_scan.dart';
import '../domain/cart.dart';

/// Search function used by [lookupScanProduct] (typically [PosApi.searchProducts]).
typedef ProductScanSearch = Future<Result<List<CatalogProduct>>> Function(
  String query, {
  int limit,
});

/// Look up a barcode/SKU and pick an exact cart hit.
///
/// Tries [scanCodeCandidates] in order (raw, UPC/EAN variants) until an exact
/// or ambiguous hit. [limit] is 1–50 (default 8). Empty code → empty reason.
Future<ScanPickResult> lookupScanProduct(
  ProductScanSearch search,
  String rawCode, {
  int limit = 8,
}) async {
  final extracted = extractProductScanCode(rawCode);
  final candidates = scanCodeCandidates(extracted);
  if (candidates.isEmpty) {
    return const ScanPickResult(reason: ScanPickReason.empty);
  }
  final capped = limit.clamp(1, 50);
  ScanPickResult last = const ScanPickResult(reason: ScanPickReason.none);
  for (final code in candidates) {
    final result = await search(code, limit: capped);
    final pick = result.when(
      success: (list) => pickExactScanProduct(list, code),
      failure: (_, _) => const ScanPickResult(reason: ScanPickReason.none),
    );
    if (pick.product != null || pick.reason == ScanPickReason.ambiguous) {
      return pick;
    }
    last = pick;
  }
  return last;
}

/// Convenience: look up using [PosApi.searchProducts].
Future<ScanPickResult> lookupScanProductWithApi(
  PosApi api,
  String rawCode, {
  int limit = 8,
}) {
  return lookupScanProduct(
    (query, {int limit = 8}) => api.searchProducts(query, limit: limit),
    rawCode,
    limit: limit,
  );
}
