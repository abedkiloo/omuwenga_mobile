import '../../customers/domain/debt_management.dart';
import '../../sales_history/domain/payment_status.dart';

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

class DailySummary {
  const DailySummary({
    required this.totalSales,
    required this.ordersCount,
    required this.totalPaid,
    required this.paidOrdersCount,
    required this.totalDebtIncurred,
    required this.debtOrdersCount,
    required this.partialOrdersCount,
    required this.totalDebtCollected,
    required this.totalCollected,
    this.debtSettlementCount = 0,
  });

  final double totalSales;
  final int ordersCount;
  final double totalPaid;
  final int paidOrdersCount;
  final double totalDebtIncurred;
  final int debtOrdersCount;
  final int partialOrdersCount;
  final double totalDebtCollected;
  final int debtSettlementCount;
  final double totalCollected;

  factory DailySummary.fromJson(Map<String, dynamic> json) {
    return DailySummary(
      totalSales: _asDouble(json['total_sales']) ?? 0,
      ordersCount: (json['orders_count'] as num?)?.toInt() ?? 0,
      totalPaid: _asDouble(json['total_paid']) ?? 0,
      paidOrdersCount: (json['paid_orders_count'] as num?)?.toInt() ?? 0,
      totalDebtIncurred: _asDouble(json['total_debt_incurred']) ?? 0,
      debtOrdersCount: (json['debt_orders_count'] as num?)?.toInt() ?? 0,
      partialOrdersCount: (json['partial_orders_count'] as num?)?.toInt() ?? 0,
      totalDebtCollected: _asDouble(json['total_debt_collected']) ?? 0,
      debtSettlementCount: (json['debt_settlement_count'] as num?)?.toInt() ?? 0,
      totalCollected: _asDouble(json['total_collected']) ?? 0,
    );
  }
}

class DailyOrder {
  const DailyOrder({
    required this.id,
    required this.saleNumber,
    required this.total,
    required this.amountPaid,
    required this.paymentStatus,
    this.customerId,
    this.customerName,
    this.paymentMethod,
    this.occurredAt,
    this.debtAmount = 0,
    this.cashierName,
    this.servedByName,
    this.clientChannel,
  });

  final int id;
  final String saleNumber;
  final double total;
  final double amountPaid;
  final PaymentStatusDisplay paymentStatus;
  final int? customerId;
  final String? customerName;
  final String? paymentMethod;
  final String? occurredAt;
  final double debtAmount;
  final String? cashierName;
  final String? servedByName;
  final String? clientChannel;

  factory DailyOrder.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    int? customerId;
    String? customerName;
    if (customer is Map) {
      customerId = (customer['id'] as num?)?.toInt();
      customerName = customer['name']?.toString();
    }
    final status =
        tryParsePaymentStatus(json['payment_status']?.toString()) ??
        classifyPaymentStatus(
          total: _asDouble(json['total']) ?? 0,
          amountPaid: _asDouble(json['amount_paid']) ?? 0,
        );
    return DailyOrder(
      id: (json['id'] as num).toInt(),
      saleNumber: (json['sale_number'] ?? '').toString(),
      total: _asDouble(json['total']) ?? 0,
      amountPaid: _asDouble(json['amount_paid']) ?? 0,
      paymentStatus: status,
      customerId: customerId,
      customerName: customerName,
      paymentMethod: json['payment_method']?.toString(),
      occurredAt: json['occurred_at']?.toString(),
      debtAmount: _asDouble(json['debt_amount']) ?? 0,
      cashierName: json['cashier_name']?.toString(),
      servedByName: json['served_by_name']?.toString(),
      clientChannel: json['client_channel']?.toString(),
    );
  }
}

class DailySalesReport {
  const DailySalesReport({
    required this.date,
    required this.summary,
    required this.orders,
    this.collections = const DebtCollections(),
  });

  final String date;
  final DailySummary summary;
  final List<DailyOrder> orders;
  final DebtCollections collections;

  factory DailySalesReport.fromJson(Map<String, dynamic> json) {
    final orders = <DailyOrder>[];
    final raw = json['orders'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          orders.add(DailyOrder.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    final summaryRaw = json['summary'];
    final collectionsRaw = json['collections'];
    return DailySalesReport(
      date: (json['date'] ?? '').toString(),
      summary: DailySummary.fromJson(
        summaryRaw is Map
            ? Map<String, dynamic>.from(summaryRaw)
            : const <String, dynamic>{},
      ),
      orders: orders,
      collections: collectionsRaw is Map
          ? DebtCollections.fromJson(Map<String, dynamic>.from(collectionsRaw))
          : const DebtCollections(),
    );
  }
}

class CustomerDayDetail {
  const CustomerDayDetail({
    required this.customerId,
    required this.customerName,
    required this.dayStanding,
    required this.ordersCount,
    required this.orders,
    this.standing,
  });

  final int customerId;
  final String customerName;
  final String dayStanding;
  final int ordersCount;
  final List<DailyOrder> orders;
  final String? standing;

  factory CustomerDayDetail.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] is Map
        ? Map<String, dynamic>.from(json['customer'] as Map)
        : <String, dynamic>{};
    final day = json['day_summary'] is Map
        ? Map<String, dynamic>.from(json['day_summary'] as Map)
        : <String, dynamic>{};
    final orders = <DailyOrder>[];
    final raw = json['orders'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          orders.add(DailyOrder.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return CustomerDayDetail(
      customerId: (customer['id'] as num?)?.toInt() ?? 0,
      customerName: (customer['name'] ?? '').toString(),
      standing: customer['standing']?.toString(),
      dayStanding: (day['day_standing'] ?? '').toString(),
      ordersCount: (day['orders_count'] as num?)?.toInt() ?? orders.length,
      orders: orders,
    );
  }
}
