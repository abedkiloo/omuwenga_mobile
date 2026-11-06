import 'package:completebyte_pos_mobile/features/pos/domain/barcode_scan.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const a = CatalogProduct(
    id: 1,
    name: 'Soap',
    price: 10,
    sku: 'S1',
    barcode: '111',
  );
  const b = CatalogProduct(
    id: 2,
    name: 'Salt',
    price: 5,
    sku: 'S1',
    barcode: '111',
  );

  test('normalizes and matches sku/barcode only', () {
    expect(normalizeScanCode(null), '');
    expect(normalizeScanCode('  ABC  '), 'ABC');
    expect(normalizeScanCode('x' * 130), 'x' * 128);
    expect(productMatchesScanCode(a, 'abc'), isFalse);
    expect(productMatchesScanCode(null, 'S1'), isFalse);
    expect(productMatchesScanCode(a, 'S1'), isTrue);
    expect(productMatchesScanCode(a, '111'), isTrue);
    expect(
      productMatchesScanCode(
        const CatalogProduct(id: 3, name: 'Soap', price: 1, sku: 'X'),
        'Soap',
      ),
      isFalse,
    );
  });

  test('picks a single exact hit and rejects ambiguous', () {
    expect(pickExactScanProduct([a], '111').reason, ScanPickReason.exact);
    expect(pickExactScanProduct([a], '111').product, a);
    expect(pickExactScanProduct([a, b], '111').reason, ScanPickReason.ambiguous);
    expect(pickExactScanProduct([], '111').reason, ScanPickReason.none);
    expect(pickExactScanProduct([a], '').reason, ScanPickReason.empty);
  });

  test('allows single search hit for scan-like codes (variant parent)', () {
    const parent = CatalogProduct(
      id: 9,
      name: 'Shirt',
      price: 50,
      sku: 'PARENT',
      barcode: '',
    );
    final pick = pickExactScanProduct([parent], '8901234567890');
    expect(pick.product, parent);
    expect(pick.reason, ScanPickReason.exact);
    expect(looksLikeScanCode('8901234567890'), isTrue);
    expect(looksLikeScanCode('ab'), isFalse);
    expect(looksLikeScanCode('Soap'), isFalse);
  });

  test('debounces duplicate scans', () {
    final t0 = DateTime(2026, 11, 5, 12, 0, 0);
    final last = ScanStamp(code: '111', at: t0);
    expect(
      isDuplicateScan(last, '111', now: () => t0.add(const Duration(milliseconds: 100))),
      isTrue,
    );
    expect(
      isDuplicateScan(last, '111', now: () => t0.add(const Duration(milliseconds: 800))),
      isFalse,
    );
  });
}
