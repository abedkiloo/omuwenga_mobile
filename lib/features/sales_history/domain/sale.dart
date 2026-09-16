import 'payment_status.dart';

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is Map) return _asInt(value['id']);
  return int.tryParse(value.toString());
}

class SaleSummary {
  const SaleSummary({
    required this.id,
    required this.saleNumber,
    required this.total,
    required this.amountPaid,
    this.paymentMethod,
    this.customerName,
    this.occurredAt,
    this.status,
    this.refundStatus,
    this.cashierName,
    this.itemCount = 0,
  });

  final int id;
  final String saleNumber;
  final double total;
  final double amountPaid;
  final String? paymentMethod;
  final String? customerName;
  final String? occurredAt;
  final String? status;
  final String? refundStatus;
  final String? cashierName;
  final int itemCount;

  PaymentStatusDisplay get paymentStatus =>
      classifyPaymentStatus(total: total, amountPaid: amountPaid);

  double get debtAmount {
    final debt = total - amountPaid;
    return debt < 0 ? 0 : debt;
  }

  factory SaleSummary.fromJson(Map<String, dynamic> json) {
    return SaleSummary(
      id: _asInt(json['id']) ?? 0,
      saleNumber: (json['sale_number'] ?? json['id'] ?? '').toString(),
      total: _asDouble(json['total']) ?? 0,
      amountPaid: _asDouble(json['amount_paid']) ?? 0,
      paymentMethod: json['payment_method']?.toString(),
      customerName: json['customer_name']?.toString(),
      occurredAt:
          json['occurred_at']?.toString() ?? json['created_at']?.toString(),
      status: json['status']?.toString(),
      refundStatus: json['refund_status']?.toString(),
      cashierName: json['cashier_name']?.toString(),
      itemCount: (json['item_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SaleLine {
  const SaleLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.productId,
    this.sku,
    this.variantName,
  });

  final int? productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final String? sku;
  final String? variantName;

  double get lineTotal => quantity * unitPrice;

  factory SaleLine.fromJson(Map<String, dynamic> json) {
    return SaleLine(
      productId: _asInt(json['product_id']) ?? _asInt(json['product']),
      productName: (json['product_name'] ?? json['name'] ?? 'Item').toString(),
      quantity: _asDouble(json['quantity']) ?? 0,
      unitPrice: _asDouble(json['unit_price']) ?? 0,
      sku: (json['product_sku'] ?? json['sku'])?.toString(),
      variantName: (json['variant_name'] ?? json['variant_display'])
          ?.toString(),
    );
  }
}

class SaleDetail {
  const SaleDetail({
    required this.id,
    required this.saleNumber,
    required this.total,
    required this.amountPaid,
    this.paymentMethod,
    this.paymentReference,
    this.customerId,
    this.customerName,
    this.cashierName,
    this.occurredAt,
    this.status,
    this.refundStatus,
    this.canRefund = false,
    this.amountRefunded = 0,
    this.notes,
    this.subtotal = 0,
    this.taxAmount = 0,
    this.discountAmount = 0,
    this.change = 0,
    this.servedByName,
    this.saleType,
    this.items = const [],
  });

  final int id;
  final String saleNumber;
  final double total;
  final double amountPaid;
  final String? paymentMethod;
  final String? paymentReference;
  final int? customerId;
  final String? customerName;
  final String? cashierName;
  final String? occurredAt;
  final String? status;
  final String? refundStatus;
  final bool canRefund;
  final double amountRefunded;
  final String? notes;
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double change;
  final String? servedByName;
  final String? saleType;
  final List<SaleLine> items;

  PaymentStatusDisplay get paymentStatus =>
      classifyPaymentStatus(total: total, amountPaid: amountPaid);

  factory SaleDetail.fromJson(Map<String, dynamic> json) {
    final items = <SaleLine>[];
    final raw = json['items'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          items.add(SaleLine.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return SaleDetail(
      id: _asInt(json['id']) ?? 0,
      saleNumber: (json['sale_number'] ?? json['id'] ?? '').toString(),
      total: _asDouble(json['total']) ?? 0,
      amountPaid: _asDouble(json['amount_paid']) ?? 0,
      paymentMethod: json['payment_method']?.toString(),
      paymentReference: json['payment_reference']?.toString(),
      customerId: _asInt(json['customer_id']) ?? _asInt(json['customer']),
      customerName: json['customer_name']?.toString(),
      cashierName: json['cashier_name']?.toString(),
      occurredAt:
          json['occurred_at']?.toString() ?? json['created_at']?.toString(),
      status: json['status']?.toString(),
      refundStatus: json['refund_status']?.toString(),
      canRefund: json['can_refund'] == true,
      amountRefunded: _asDouble(json['amount_refunded']) ?? 0,
      notes: json['notes']?.toString(),
      subtotal: _asDouble(json['subtotal']) ?? 0,
      taxAmount: _asDouble(json['tax_amount']) ?? 0,
      discountAmount: _asDouble(json['discount_amount']) ?? 0,
      change: _asDouble(json['change']) ?? 0,
      servedByName: json['served_by_name']?.toString(),
      saleType: json['sale_type']?.toString(),
      items: items,
    );
  }
}

class SalesHistoryFilters {
  const SalesHistoryFilters({
    this.dateFrom,
    this.dateTo,
    this.paymentMethod = '',
    this.search = '',
  });

  final String? dateFrom;
  final String? dateTo;
  final String paymentMethod;
  final String search;

  SalesHistoryFilters copyWith({
    String? dateFrom,
    String? dateTo,
    String? paymentMethod,
    String? search,
    bool clearDates = false,
  }) {
    return SalesHistoryFilters(
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      search: search ?? this.search,
    );
  }

  Map<String, String> toQuery() {
    final q = <String, String>{};
    if (dateFrom != null && dateFrom!.isNotEmpty) q['date_from'] = dateFrom!;
    if (dateTo != null && dateTo!.isNotEmpty) q['date_to'] = dateTo!;
    if (paymentMethod.trim().isNotEmpty) {
      q['payment_method'] = paymentMethod.trim();
    }
    if (search.trim().isNotEmpty) q['search'] = search.trim();
    return q;
  }
}
