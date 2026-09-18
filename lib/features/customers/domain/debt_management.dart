import 'wallet_debt.dart';

double _asDouble(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class DebtAgingBucket {
  const DebtAgingBucket({required this.count, required this.amount});

  final int count;
  final double amount;

  factory DebtAgingBucket.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DebtAgingBucket(count: 0, amount: 0);
    return DebtAgingBucket(
      count: (json['count'] as num?)?.toInt() ?? 0,
      amount: _asDouble(json['amount']),
    );
  }
}

class DebtSummary {
  const DebtSummary({
    this.customersWithDebt = 0,
    this.totalDebt = 0,
    this.averageDebt = 0,
    this.collectedToday = 0,
    this.aging = const {},
  });

  final int customersWithDebt;
  final double totalDebt;
  final double averageDebt;
  final double collectedToday;
  final Map<String, DebtAgingBucket> aging;

  factory DebtSummary.fromJson(Map<String, dynamic> json) {
    final agingRaw = json['aging'];
    final aging = <String, DebtAgingBucket>{};
    if (agingRaw is Map) {
      for (final entry in agingRaw.entries) {
        aging[entry.key.toString()] = DebtAgingBucket.fromJson(
          entry.value is Map
              ? Map<String, dynamic>.from(entry.value as Map)
              : null,
        );
      }
    }
    return DebtSummary(
      customersWithDebt: (json['customers_with_debt'] as num?)?.toInt() ?? 0,
      totalDebt: _asDouble(json['total_debt']),
      averageDebt: _asDouble(json['average_debt']),
      collectedToday: _asDouble(json['collected_today']),
      aging: aging,
    );
  }
}

class DebtorRow {
  const DebtorRow({
    required this.id,
    required this.name,
    required this.debtAmount,
    this.phone = '',
    this.customerCode = '',
    this.walletBalance,
    this.debtAgeDays = 0,
    this.agingBucket = '0_7',
    this.lastSaleAt,
    this.lastPaymentAt,
  });

  final int id;
  final String name;
  final String phone;
  final String customerCode;
  final double? walletBalance;
  final double debtAmount;
  final int debtAgeDays;
  final String agingBucket;
  final String? lastSaleAt;
  final String? lastPaymentAt;

  CustomerStanding get standing => CustomerStanding.debt;

  String get agingLabel => switch (agingBucket) {
    '0_7' => '0–7 days',
    '8_30' => '8–30 days',
    '31_60' => '31–60 days',
    '60_plus' => '60+ days',
    _ => agingBucket,
  };

  factory DebtorRow.fromJson(Map<String, dynamic> json) {
    return DebtorRow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      customerCode: (json['customer_code'] ?? '').toString(),
      walletBalance: json['wallet_balance'] == null
          ? null
          : _asDouble(json['wallet_balance']),
      debtAmount: _asDouble(json['debt_amount']),
      debtAgeDays: (json['debt_age_days'] as num?)?.toInt() ?? 0,
      agingBucket: (json['aging_bucket'] ?? '0_7').toString(),
      lastSaleAt: json['last_sale_at']?.toString(),
      lastPaymentAt: json['last_payment_at']?.toString(),
    );
  }
}
