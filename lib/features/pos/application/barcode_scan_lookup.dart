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
/// [search] defaults to wiring via [PosApi] when callers pass
/// `(q, {limit}) => api.searchProducts(q, limit: limit)`.
Future<ScanPickResult> lookupScanProduct(
  ProductScanSearch search,
  String rawCode, {
  int limit = 8,
}) async {
  final code = normalizeScanCode(rawCode);
  if (code.isEmpty) {
    return const ScanPickResult(reason: ScanPickReason.empty);
  }
  final result = await search(code, limit: limit);
  return result.when(
    success: (list) => pickExactScanProduct(list, code),
    failure: (_, _) => const ScanPickResult(reason: ScanPickReason.none),
  );
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
