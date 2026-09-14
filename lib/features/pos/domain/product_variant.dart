import 'package:flutter/foundation.dart';

@immutable
class ProductVariant {
  const ProductVariant({
    required this.id,
    required this.productId,
    required this.effectivePrice,
    this.sizeId,
    this.sizeName,
    this.colorId,
    this.colorName,
    this.sku,
    this.stockQuantity,
    this.isActive = true,
  });

  final int id;
  final int productId;
  final double effectivePrice;
  final int? sizeId;
  final String? sizeName;
  final int? colorId;
  final String? colorName;
  final String? sku;
  final double? stockQuantity;
  final bool isActive;

  String get displayLabel {
    final parts = <String>[
      if (sizeName != null && sizeName!.trim().isNotEmpty) sizeName!.trim(),
      if (colorName != null && colorName!.trim().isNotEmpty) colorName!.trim(),
    ];
    if (parts.isNotEmpty) return parts.join(' / ');
    if (sku != null && sku!.trim().isNotEmpty) return sku!.trim();
    return 'Variant #$id';
  }

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    double? asDouble(Object? v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    int? asInt(Object? v) {
      if (v == null) return null;
      if (v is Map && v['id'] != null) return asInt(v['id']);
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    final productRaw = json['product'];
    final productId = asInt(productRaw) ?? 0;

    return ProductVariant(
      id: (json['id'] as num).toInt(),
      productId: productId,
      effectivePrice: asDouble(
            json['effective_price'] ?? json['selling_price'] ?? json['price'],
          ) ??
          0,
      sizeId: asInt(json['size'] ?? json['size_id']),
      sizeName: json['size_name']?.toString(),
      colorId: asInt(json['color'] ?? json['color_id']),
      colorName: json['color_name']?.toString(),
      sku: json['sku']?.toString(),
      stockQuantity: asDouble(json['stock_quantity']),
      isActive: json['is_active'] != false,
    );
  }
}

enum VariantPickerMode { none, sizeColor, sizeOnly, colorOnly, list }

bool _usesSize(ProductVariant v) => v.sizeId != null;
bool _usesColor(ProductVariant v) => v.colorId != null;

bool hasHeterogeneousVariantAttributes(List<ProductVariant> active) {
  if (active.isEmpty) return false;
  final withSize = active.where(_usesSize).length;
  final withColor = active.where(_usesColor).length;
  final withBoth = active.where((v) => _usesSize(v) && _usesColor(v)).length;
  final withColorOnly = active.where((v) => !_usesSize(v) && _usesColor(v)).length;
  final withSizeOnly = active.where((v) => _usesSize(v) && !_usesColor(v)).length;
  final withNeither = active.where((v) => !_usesSize(v) && !_usesColor(v)).length;

  if (withBoth > 0 && (withColorOnly > 0 || withSizeOnly > 0)) return true;
  if (withSize > 0 && withSize < active.length) return true;
  if (withColor > 0 && withColor < active.length) return true;
  if (withNeither > 0 && withNeither < active.length) return true;
  return false;
}

VariantPickerMode getVariantPickerMode(List<ProductVariant> active) {
  if (active.isEmpty) return VariantPickerMode.none;
  if (hasHeterogeneousVariantAttributes(active)) return VariantPickerMode.list;

  final anySize = active.any(_usesSize);
  final anyColor = active.any(_usesColor);
  final anyBoth = active.any((v) => _usesSize(v) && _usesColor(v));
  if (anyBoth || (anySize && anyColor)) return VariantPickerMode.sizeColor;
  if (anySize) return VariantPickerMode.sizeOnly;
  if (anyColor) return VariantPickerMode.colorOnly;
  return VariantPickerMode.list;
}

@immutable
class VariantAttributeOption {
  const VariantAttributeOption({required this.id, required this.name});

  final int id;
  final String name;
}

List<VariantAttributeOption> pickerSizes(List<ProductVariant> active) {
  final byId = <int, VariantAttributeOption>{};
  for (final v in active) {
    final id = v.sizeId;
    if (id == null || byId.containsKey(id)) continue;
    byId[id] = VariantAttributeOption(
      id: id,
      name: (v.sizeName != null && v.sizeName!.isNotEmpty) ? v.sizeName! : 'Size #$id',
    );
  }
  return byId.values.toList();
}

List<VariantAttributeOption> pickerColors(
  List<ProductVariant> active, {
  int? selectedSizeId,
}) {
  final pool = selectedSizeId == null
      ? active
      : active.where((v) => v.sizeId == selectedSizeId);
  final byId = <int, VariantAttributeOption>{};
  for (final v in pool) {
    final id = v.colorId;
    if (id == null || byId.containsKey(id)) continue;
    byId[id] = VariantAttributeOption(
      id: id,
      name: (v.colorName != null && v.colorName!.isNotEmpty)
          ? v.colorName!
          : 'Color #$id',
    );
  }
  return byId.values.toList();
}

ProductVariant? findVariantForSelection(
  List<ProductVariant> active, {
  required VariantPickerMode mode,
  int? sizeId,
  int? colorId,
}) {
  switch (mode) {
    case VariantPickerMode.sizeColor:
      if (sizeId == null || colorId == null) return null;
      for (final v in active) {
        if (v.sizeId == sizeId && v.colorId == colorId) return v;
      }
      return null;
    case VariantPickerMode.sizeOnly:
      if (sizeId == null) return null;
      for (final v in active) {
        if (v.sizeId == sizeId && v.colorId == null) return v;
      }
      return null;
    case VariantPickerMode.colorOnly:
      if (colorId == null) return null;
      for (final v in active) {
        if (v.colorId == colorId && v.sizeId == null) return v;
      }
      return null;
    case VariantPickerMode.list:
    case VariantPickerMode.none:
      return null;
  }
}
