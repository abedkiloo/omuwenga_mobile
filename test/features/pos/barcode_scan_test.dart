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

  test('matches UPC-A / EAN-13 length variants', () {
    const upc = CatalogProduct(
      id: 4,
      name: 'Milk',
      price: 20,
      sku: 'MILK',
      barcode: '123456789012',
    );
    expect(scanCodeCandidates('0123456789012'), containsAll(['0123456789012', '123456789012']));
    expect(productMatchesScanCode(upc, '0123456789012'), isTrue);
    expect(productMatchesScanCode(upc, '1234567890128'), isTrue);
    expect(
      productMatchesScanCode(
        const CatalogProduct(
          id: 5,
          name: 'Tea',
          price: 5,
          barcode: '0123456789012',
        ),
        '123456789012',
      ),
      isTrue,
    );
  });

  test('extracts product code from QR URL and GS1 payloads', () {
    expect(
      extractProductScanCode('https://shop.example/products/SOAP-1'),
      'SOAP-1',
    );
    expect(
      extractProductScanCode(
        'https://shop.example/p?barcode=6281001234567&x=1',
      ),
      '6281001234567',
    );
    expect(extractProductScanCode('(01)01234567890128'), '01234567890128');
    expect(extractProductScanCode('0101234567890128'), '01234567890128');
    expect(extractProductScanCode('  SOAP-1  '), 'SOAP-1');
  });

  test('continuous debounce window covers industry 1.2s hold', () {
    final t0 = DateTime(2026, 11, 5, 12, 0, 0);
    final last = ScanStamp(code: '111', at: t0);
    expect(
      isDuplicateScan(
        last,
        '111',
        window: kPosContinuousScanDebounce,
        now: () => t0.add(const Duration(milliseconds: 800)),
      ),
      isTrue,
    );
    expect(
      isDuplicateScan(
        last,
        '111',
        window: kPosContinuousScanDebounce,
        now: () => t0.add(const Duration(milliseconds: 1300)),
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
