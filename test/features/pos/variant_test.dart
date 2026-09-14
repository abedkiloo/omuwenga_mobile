import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/product_variant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProductVariant', () {
    test('fromJson and displayLabel', () {
      final v = ProductVariant.fromJson({
        'id': 9,
        'product': 1,
        'size': 2,
        'size_name': 'Large',
        'color': 3,
        'color_name': 'White',
        'sku': 'TSH-L-W',
        'effective_price': '22.50',
        'stock_quantity': 4,
        'is_active': true,
      });
      expect(v.displayLabel, 'Large / White');
      expect(v.effectivePrice, 22.5);
      expect(v.productId, 1);
    });

    test('picker mode size-color vs list', () {
      final sizeColor = [
        const ProductVariant(
          id: 1,
          productId: 1,
          effectivePrice: 10,
          sizeId: 1,
          sizeName: 'S',
          colorId: 2,
          colorName: 'Red',
        ),
        const ProductVariant(
          id: 2,
          productId: 1,
          effectivePrice: 10,
          sizeId: 1,
          sizeName: 'S',
          colorId: 3,
          colorName: 'Blue',
        ),
      ];
      expect(getVariantPickerMode(sizeColor), VariantPickerMode.sizeColor);

      final mixed = [
        ...sizeColor,
        const ProductVariant(
          id: 3,
          productId: 1,
          effectivePrice: 10,
          colorId: 4,
          colorName: 'Green',
        ),
      ];
      expect(getVariantPickerMode(mixed), VariantPickerMode.list);
    });
  });

  group('CatalogProduct has_variants', () {
    test('parses flag', () {
      final p = CatalogProduct.fromJson({
        'id': 1,
        'name': 'Tee',
        'selling_price': 20,
        'has_variants': true,
      });
      expect(p.hasVariants, isTrue);
    });
  });

  group('PosCart variant lines', () {
    test('separate lines and sale json include variant_id', () {
      const product = CatalogProduct(
        id: 5,
        name: 'Tee',
        price: 20,
        hasVariants: true,
      );
      const v1 = ProductVariant(
        id: 101,
        productId: 5,
        effectivePrice: 22,
        sizeId: 1,
        sizeName: 'L',
        colorId: 2,
        colorName: 'White',
        sku: 'T-L-W',
      );
      const v2 = ProductVariant(
        id: 102,
        productId: 5,
        effectivePrice: 21,
        sizeId: 1,
        sizeName: 'L',
        colorId: 3,
        colorName: 'Black',
        sku: 'T-L-B',
      );

      var cart = const PosCart()
          .addProduct(product, variant: v1)
          .addProduct(product, variant: v2)
          .addProduct(product, variant: v1);
      expect(cart.lines, hasLength(2));
      expect(cart.lines.first.quantity, 2);
      expect(cart.lines.first.displayName, 'Tee · L / White');
      expect(cart.toSaleItemsJson(), [
        {
          'product_id': 5,
          'quantity': 2.0,
          'unit_price': 22.0,
          'variant_id': 101,
        },
        {
          'product_id': 5,
          'quantity': 1.0,
          'unit_price': 21.0,
          'variant_id': 102,
        },
      ]);
    });
  });
}
