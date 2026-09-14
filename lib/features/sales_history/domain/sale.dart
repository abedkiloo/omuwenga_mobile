import 'payment_status.dart';

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
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

  PaymentStatusDisplay get paymentStatus =>
      classifyPaymentStatus(total: total, amountPaid: amountPaid);

  double get debtAmount {
    final debt = total - amountPaid;
    return debt < 0 ? 0 : debt;
  }

  factory SaleSummary.fromJson(Map<String, dynamic> json) {
    return SaleSummary(
      id: (json['id'] as num).toInt(),
      saleNumber: (json['sale_number'] ?? json['id'] ?? '').toString(),
      total: _asDouble(json['total']) ?? 0,
      amountPaid: _asDouble(json['amount_paid']) ?? 0,
      paymentMethod: json['payment_method']?.toString(),
      customerName: json['customer_name']?.toString(),
      occurredAt: json['occurred_at']?.toString() ?? json['created_at']?.toString(),
      status: json['status']?.toString(),
      refundStatus: json['refund_status']?.toString(),
    );
  }
}

class SaleLine {
  const SaleLine({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    this.productId,
  });

  final int? productId;
  final String productName;
  final double quantity;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;

  factory SaleLine.fromJson(Map<String, dynamic> json) {
    return SaleLine(
      productId: (json['product'] as num?)?.toInt() ??
          (json['product_id'] as num?)?.toInt(),
      productName: (json['product_name'] ?? json['name'] ?? 'Item').toString(),
      quantity: _asDouble(json['quantity']) ?? 0,
      unitPrice: _asDouble(json['unit_price']) ?? 0,
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
      id: (json['id'] as num).toInt(),
      saleNumber: (json['sale_number'] ?? json['id'] ?? '').toString(),
      total: _asDouble(json['total']) ?? 0,
      amountPaid: _asDouble(json['amount_paid']) ?? 0,
      paymentMethod: json['payment_method']?.toString(),
      paymentReference: json['payment_reference']?.toString(),
      customerId: (json['customer'] as num?)?.toInt(),
      customerName: json['customer_name']?.toString(),
      cashierName: json['cashier_name']?.toString(),
      occurredAt: json['occurred_at']?.toString() ?? json['created_at']?.toString(),
      status: json['status']?.toString(),
      refundStatus: json['refund_status']?.toString(),
      canRefund: json['can_refund'] == true,
      amountRefunded: _asDouble(json['amount_refunded']) ?? 0,
      notes: json['notes']?.toString(),
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
