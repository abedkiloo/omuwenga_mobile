import '../../pos/domain/cart.dart';
import '../../pos/domain/product_variant.dart';

enum FieldOrderStatus {
  draft,
  submitted,
  packing,
  ready,
  outForDelivery,
  done,
  cancelled;

  static FieldOrderStatus parse(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'submitted':
        return FieldOrderStatus.submitted;
      case 'packing':
        return FieldOrderStatus.packing;
      case 'ready':
        return FieldOrderStatus.ready;
      case 'out_for_delivery':
        return FieldOrderStatus.outForDelivery;
      case 'done':
        return FieldOrderStatus.done;
      case 'cancelled':
        return FieldOrderStatus.cancelled;
      default:
        return FieldOrderStatus.draft;
    }
  }

  String get apiValue {
    switch (this) {
      case FieldOrderStatus.outForDelivery:
        return 'out_for_delivery';
      default:
        return name;
    }
  }
}

class FieldOrderCart {
  const FieldOrderCart({
    required this.siteId,
    this.siteLabel = '',
    this.lines = const [],
    this.notes = '',
    this.photoUrls = const [],
    this.latitude,
    this.longitude,
  });

  final int siteId;
  final String siteLabel;
  final List<CartLine> lines;
  final String notes;
  final List<String> photoUrls;
  final double? latitude;
  final double? longitude;

  bool get canSubmit => siteId > 0 && lines.isNotEmpty;

  double get subtotal =>
      lines.fold(0, (sum, line) => sum + line.lineTotal);

  FieldOrderCart copyWith({
    int? siteId,
    String? siteLabel,
    List<CartLine>? lines,
    String? notes,
    List<String>? photoUrls,
    double? latitude,
    double? longitude,
  }) {
    return FieldOrderCart(
      siteId: siteId ?? this.siteId,
      siteLabel: siteLabel ?? this.siteLabel,
      lines: lines ?? this.lines,
      notes: notes ?? this.notes,
      photoUrls: photoUrls ?? this.photoUrls,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  FieldOrderCart addProduct(
    CatalogProduct product, {
    ProductVariant? variant,
    double qty = 1,
  }) {
    final variantId = variant?.id;
    final lineKey =
        variantId == null ? '${product.id}' : '${product.id}-$variantId';
    final existing = lines.indexWhere((l) => l.lineKey == lineKey);
    if (existing >= 0) {
      final next = [...lines];
      next[existing] = next[existing].copyWith(
        quantity: next[existing].quantity + qty,
      );
      return copyWith(lines: next);
    }
    return copyWith(
      lines: [
        ...lines,
        CartLine(
          productId: product.id,
          name: product.name,
          unitPrice: variant?.effectivePrice ?? product.price,
          quantity: qty,
          sku: variant?.sku ?? product.sku,
          stockQuantity: variant?.stockQuantity ?? product.stockQuantity,
          variantId: variantId,
          variantLabel: variant?.displayLabel,
        ),
      ],
    );
  }

  List<Map<String, dynamic>> toLinesJson() => [
        for (final line in lines)
          {
            'product_id': line.productId,
            'quantity': line.quantity.toString(),
            'unit_price': line.unitPrice.toStringAsFixed(2),
            if (line.variantId != null) 'variant_id': line.variantId,
          },
      ];
}

class FieldOrderSummary {
  const FieldOrderSummary({
    required this.id,
    required this.status,
    required this.siteId,
    this.siteLabel = '',
    this.customerName,
    this.photoUrls = const [],
    this.latitude,
    this.longitude,
    this.lines = const [],
    this.assignedDeliveryAgentId,
    this.stockAllocated = false,
  });

  final int id;
  final FieldOrderStatus status;
  final int siteId;
  final String siteLabel;
  final String? customerName;
  final List<String> photoUrls;
  final double? latitude;
  final double? longitude;
  final List<CartLine> lines;
  final int? assignedDeliveryAgentId;
  final bool stockAllocated;

  factory FieldOrderSummary.fromJson(Map<String, dynamic> json) {
    final site = json['site_detail'];
    final media = json['site_media'];
    final urls = <String>[];
    if (media is List) {
      for (final m in media) {
        if (m is Map && m['image_url'] != null) {
          urls.add(m['image_url'].toString());
        }
      }
    }
    final linesRaw = json['lines'];
    final lines = <CartLine>[];
    if (linesRaw is List) {
      for (final row in linesRaw) {
        if (row is! Map) continue;
        lines.add(
          CartLine(
            productId: (row['product_id'] as num?)?.toInt() ?? 0,
            name: (row['product_name'] ?? '').toString(),
            unitPrice: double.tryParse('${row['unit_price']}') ?? 0,
            quantity: double.tryParse('${row['quantity']}') ?? 0,
            variantId: (row['variant_id'] as num?)?.toInt(),
          ),
        );
      }
    }
    return FieldOrderSummary(
      id: (json['id'] as num).toInt(),
      status: FieldOrderStatus.parse(json['status']?.toString()),
      siteId: (json['site'] as num?)?.toInt() ??
          (site is Map ? (site['id'] as num?)?.toInt() : null) ??
          0,
      siteLabel: site is Map ? (site['label'] ?? '').toString() : '',
      customerName: json['customer_name']?.toString(),
      photoUrls: urls,
      latitude: site is Map
          ? double.tryParse('${site['latitude']}')
          : null,
      longitude: site is Map
          ? double.tryParse('${site['longitude']}')
          : null,
      lines: lines,
      assignedDeliveryAgentId:
          (json['assigned_delivery_agent_id'] as num?)?.toInt(),
      stockAllocated: json['stock_allocated'] == true,
    );
  }
}
