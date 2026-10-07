/// Sale-line unit price rules — matches web `saleUnitPrice.js` and
/// backend `validate_sale_unit_price_override`.
///
/// Charge catalog selling price or higher; never go below.

String? saleUnitPriceOverrideError({
  required double catalogPrice,
  required double? requestedPrice,
}) {
  if (requestedPrice == null || requestedPrice.isNaN || requestedPrice < 0) {
    return 'Enter a valid unit price.';
  }
  if (catalogPrice.isNaN) {
    return 'Catalog selling price is missing for this item.';
  }
  if (requestedPrice + 1e-9 < catalogPrice) {
    final floor = catalogPrice.toStringAsFixed(
      catalogPrice.truncateToDouble() == catalogPrice ? 0 : 2,
    );
    return 'Unit price cannot be below the selling price ($floor).';
  }
  return null;
}

bool isSaleUnitPriceOverrideAllowed({
  required double catalogPrice,
  required double? requestedPrice,
}) {
  return saleUnitPriceOverrideError(
        catalogPrice: catalogPrice,
        requestedPrice: requestedPrice,
      ) ==
      null;
}
