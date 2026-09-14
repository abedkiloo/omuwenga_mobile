import 'package:flutter/foundation.dart';

import 'product_variant.dart';

@immutable
class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.price,
    this.sku,
    this.barcode,
    this.stockQuantity,
    this.unit,
    this.hasVariants = false,
  });

  final int id;
  final String name;
  final double price;
  final String? sku;
  final String? barcode;
  final double? stockQuantity;
  final String? unit;
  final bool hasVariants;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return CatalogProduct(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      price: asDouble(json['selling_price'] ?? json['price'] ?? json['mrp']) ?? 0,
      sku: json['sku']?.toString(),
      barcode: json['barcode']?.toString(),
      stockQuantity: asDouble(json['stock_quantity']),
      unit: json['unit']?.toString(),
      hasVariants: json['has_variants'] == true,
    );
  }
}

@immutable
class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
    this.sku,
    this.stockQuantity,
    this.variantId,
    this.variantLabel,
  });

  final int productId;
  final String name;
  final String? sku;
  final double unitPrice;
  final double quantity;
  final double? stockQuantity;
  final int? variantId;
  final String? variantLabel;

  /// Matches web `cartItemKey`: `productId` or `productId-variantId`.
  String get lineKey =>
      variantId == null ? '$productId' : '$productId-$variantId';

  String get displayName {
    final label = variantLabel?.trim();
    if (label == null || label.isEmpty) return name;
    return '$name · $label';
  }

  double get lineTotal => unitPrice * quantity;

  CartLine copyWith({double? quantity, double? unitPrice}) {
    return CartLine(
      productId: productId,
      name: name,
      sku: sku,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      stockQuantity: stockQuantity,
      variantId: variantId,
      variantLabel: variantLabel,
    );
  }
}

@immutable
class PosCart {
  const PosCart({
    this.lines = const [],
    this.customerId,
    this.customerName,
    this.taxAmount = 0,
    this.discountAmount = 0,
  });

  final List<CartLine> lines;
  final int? customerId;
  final String? customerName;
  final double taxAmount;
  final double discountAmount;

  bool get isEmpty => lines.isEmpty;
  bool get isDirty => lines.isNotEmpty || customerId != null;

  double get subtotal =>
      lines.fold<double>(0, (sum, line) => sum + line.lineTotal);

  double get total {
    final raw = subtotal + taxAmount - discountAmount;
    return raw < 0 ? 0 : raw;
  }

  int get itemCount => lines.fold<int>(0, (sum, l) => sum + l.quantity.round());

  PosCart addProduct(
    CatalogProduct product, {
    ProductVariant? variant,
    double qty = 1,
  }) {
    final variantId = variant?.id;
    final lineKey =
        variantId == null ? '${product.id}' : '${product.id}-$variantId';
    final existing = lines.indexWhere((l) => l.lineKey == lineKey);
    if (existing >= 0) {
      final updated = List<CartLine>.from(lines);
      final line = updated[existing];
      updated[existing] = line.copyWith(quantity: line.quantity + qty);
      return copyWith(lines: updated);
    }
    return copyWith(
      lines: [
        ...lines,
        CartLine(
          productId: product.id,
          name: product.name,
          sku: variant?.sku ?? product.sku,
          unitPrice: variant?.effectivePrice ?? product.price,
          quantity: qty,
          stockQuantity: variant?.stockQuantity ?? product.stockQuantity,
          variantId: variantId,
          variantLabel: variant?.displayLabel,
        ),
      ],
    );
  }

  PosCart updateQuantity(String lineKey, double quantity) {
    if (quantity <= 0) return removeLine(lineKey);
    final updated = lines
        .map((l) => l.lineKey == lineKey ? l.copyWith(quantity: quantity) : l)
        .toList();
    return copyWith(lines: updated);
  }

  /// Backward-compatible: updates the first line for [productId] (no variant).
  PosCart updateQuantityForProduct(int productId, double quantity) {
    return updateQuantity('$productId', quantity);
  }

  PosCart removeLine(String lineKey) {
    return copyWith(lines: lines.where((l) => l.lineKey != lineKey).toList());
  }

  PosCart removeProduct(int productId) {
    return removeLine('$productId');
  }

  PosCart attachCustomer({required int id, required String name}) {
    return copyWith(customerId: id, customerName: name);
  }

  PosCart clearCustomer() => copyWith(clearCustomer: true);

  PosCart clear() => const PosCart();

  PosCart copyWith({
    List<CartLine>? lines,
    int? customerId,
    String? customerName,
    double? taxAmount,
    double? discountAmount,
    bool clearCustomer = false,
  }) {
    return PosCart(
      lines: lines ?? this.lines,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      customerName: clearCustomer ? null : (customerName ?? this.customerName),
      taxAmount: taxAmount ?? this.taxAmount,
      discountAmount: discountAmount ?? this.discountAmount,
    );
  }

  List<Map<String, dynamic>> toSaleItemsJson() {
    return [
      for (final line in lines)
        {
          'product_id': line.productId,
          'quantity': line.quantity,
          'unit_price': line.unitPrice,
          if (line.variantId != null) 'variant_id': line.variantId,
        },
    ];
  }
}
