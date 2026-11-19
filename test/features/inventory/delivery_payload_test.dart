import 'package:completebyte_pos_mobile/features/inventory/domain/delivery_payload.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a new delivery starts without a selling price', () {
    final body = deliveryWriteBody(productId: 4, quantity: 2, newPrice: true);
    expect(body['price_mode'], 'new');
    expect(body.containsKey('unit_sell_price'), isFalse);
    expect(body.containsKey('unit_cost'), isFalse);
    expect(CatalogProduct.newSalePriceUnsetLabel, 'New sale price has not been set');
  });

  test('old price keeps the current selling price and still omits cost', () {
    final body = deliveryWriteBody(
      productId: 4,
      quantity: 3,
      newPrice: false,
      sellingPrice: '90',
    );
    expect(body['price_mode'], 'old');
    expect(body.containsKey('unit_sell_price'), isFalse);
    expect(body.containsKey('unit_cost'), isFalse);
  });

  test('a typed new selling price is sent with the delivery', () {
    final body = deliveryWriteBody(
      productId: 4,
      quantity: 1,
      newPrice: true,
      sellingPrice: '75.00',
      mrp: '90',
    );
    expect(body['unit_sell_price'], '75.00');
    expect(body['unit_mrp'], '90');
  });
}
