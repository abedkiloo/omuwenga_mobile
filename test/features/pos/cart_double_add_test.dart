import 'package:completebyte_pos_mobile/features/pos/application/pos_controllers.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/product_variant.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = CatalogProduct(
    id: 7,
    name: 'Cement 50kg',
    price: 100,
    stockQuantity: 20,
  );

  const variant = ProductVariant(
    id: 3,
    productId: 7,
    sku: 'CEM-50-RED',
    stockQuantity: 10,
    effectivePrice: 100,
  );

  test('picker double-fire within 500ms does not double quantity', () {
    var clock = DateTime(2026, 11, 4, 12, 0, 0);
    final cart = CartController(now: () => clock);

    cart.addProduct(product, variant: variant, qty: 3, fromPicker: true);
    expect(cart.state.lines.single.quantity, 3);

    clock = clock.add(const Duration(milliseconds: 100));
    cart.addProduct(product, variant: variant, qty: 3, fromPicker: true);
    expect(cart.state.lines.single.quantity, 3);

    clock = clock.add(const Duration(milliseconds: 500));
    cart.addProduct(product, variant: variant, qty: 3, fromPicker: true);
    expect(cart.state.lines.single.quantity, 6);
  });

  test('simple catalog taps still merge quantity without debounce', () {
    final cart = CartController();
    cart.addProduct(product);
    cart.addProduct(product);
    expect(cart.state.lines.single.quantity, 2);
  });
}
