import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/sale_unit_price.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('saleUnitPriceOverrideError', () {
    test('allows catalog price or higher', () {
      expect(
        saleUnitPriceOverrideError(catalogPrice: 20, requestedPrice: 20),
        isNull,
      );
      expect(
        saleUnitPriceOverrideError(catalogPrice: 20, requestedPrice: 50),
        isNull,
      );
      expect(
        isSaleUnitPriceOverrideAllowed(catalogPrice: 20, requestedPrice: 50),
        isTrue,
      );
    });

    test('blocks undercutting selling price', () {
      expect(
        saleUnitPriceOverrideError(catalogPrice: 20, requestedPrice: 15),
        contains('below the selling price'),
      );
      expect(
        isSaleUnitPriceOverrideAllowed(catalogPrice: 20, requestedPrice: 15),
        isFalse,
      );
    });

    test('rejects invalid prices', () {
      expect(
        saleUnitPriceOverrideError(catalogPrice: 20, requestedPrice: -1),
        contains('valid unit price'),
      );
      expect(
        saleUnitPriceOverrideError(catalogPrice: 20, requestedPrice: null),
        contains('valid unit price'),
      );
    });
  });

  group('PosCart unit price', () {
    const product = CatalogProduct(id: 1, name: 'Zipper', price: 20);

    test('stores catalog floor when product is added', () {
      final cart = const PosCart().addProduct(product);
      expect(cart.lines.single.catalogPrice, 20);
      expect(cart.lines.single.unitPrice, 20);
    });

    test('allows raising unit price above selling price', () {
      var cart = const PosCart().addProduct(product);
      cart = cart.updateUnitPrice(cart.lines.single.lineKey, 55);
      expect(cart.lines.single.unitPrice, 55);
      expect(cart.lines.single.catalogPrice, 20);
      expect(cart.total, 55);
    });

    test('rejects unit price below selling price', () {
      final cart = const PosCart().addProduct(product);
      expect(
        cart.tryUpdateUnitPrice(cart.lines.single.lineKey, 10),
        contains('below the selling price'),
      );
      expect(
        () => cart.updateUnitPrice(cart.lines.single.lineKey, 10),
        throwsA(isA<ArgumentError>()),
      );
      expect(cart.lines.single.unitPrice, 20);
    });
  });
}
