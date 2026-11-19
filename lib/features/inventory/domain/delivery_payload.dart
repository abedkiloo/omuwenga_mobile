/// Body for recording one stock delivery from the phone.
///
/// [productId] is 1 or greater. [quantity] is at least 1.
/// [newPrice] stays true until the person chooses the current price.
/// [sellingPrice] and [mrp] are optional money strings, at most 12 characters.
///
/// Returns the purchase body. An empty new selling price is left off the body
/// so those pieces cannot be sold until a price is saved.
Map<String, dynamic> deliveryWriteBody({
  required int productId,
  required int quantity,
  required bool newPrice,
  String sellingPrice = '',
  String mrp = '',
}) {
  final body = <String, dynamic>{
    'product_id': productId,
    'quantity': quantity < 1 ? 1 : quantity,
    'price_mode': newPrice ? 'new' : 'old',
  };
  final sell = sellingPrice.trim();
  final marked = mrp.trim();
  if (newPrice && sell.isNotEmpty) body['unit_sell_price'] = sell;
  if (newPrice && marked.isNotEmpty) body['unit_mrp'] = marked;
  return body;
}
