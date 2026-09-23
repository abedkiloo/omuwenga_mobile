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

class DebtCollectionRow {
  const DebtCollectionRow({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.amount,
    this.customerPhone = '',
    this.customerCode = '',
    this.balanceAfter = 0,
    this.reference = '',
    this.notes = '',
    this.saleNumber,
    this.receivedBy = '',
    this.createdAt,
  });

  final int id;
  final int customerId;
  final String customerName;
  final String customerPhone;
  final String customerCode;
  final double amount;
  final double balanceAfter;
  final String reference;
  final String notes;
  final String? saleNumber;
  final String receivedBy;
  final String? createdAt;

  bool get stillOwes => balanceAfter < -0.005;

  double get remainingDebt => stillOwes ? -balanceAfter : 0;

  String get remainingLabel => stillOwes ? 'Remains' : 'Settled';

  String get subtitle {
    final parts = [
      if (customerPhone.isNotEmpty) customerPhone,
      if (customerCode.isNotEmpty) customerCode,
    ];
    return parts.join(' · ');
  }

  factory DebtCollectionRow.fromJson(Map<String, dynamic> json) {
    return DebtCollectionRow(
      id: (json['id'] as num?)?.toInt() ?? 0,
      customerId: (json['customer_id'] as num?)?.toInt() ?? 0,
      customerName: (json['customer_name'] ?? 'Customer').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      customerCode: (json['customer_code'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      balanceAfter: _asDouble(json['balance_after']),
      reference: (json['reference'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      saleNumber: json['sale_number']?.toString(),
      receivedBy: (json['received_by'] ?? '').toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class DebtCollections {
  const DebtCollections({
    this.date = '',
    this.count = 0,
    this.total = 0,
    this.results = const [],
  });

  final String date;
  final int count;
  final double total;
  final List<DebtCollectionRow> results;

  factory DebtCollections.fromJson(Map<String, dynamic> json) {
    final raw = json['results'];
    final results = <DebtCollectionRow>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          results.add(
            DebtCollectionRow.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return DebtCollections(
      date: (json['date'] ?? '').toString(),
      count: (json['count'] as num?)?.toInt() ?? results.length,
      total: _asDouble(json['total']),
      results: results,
    );
  }
}

String localDateString([DateTime? value]) {
  final d = (value ?? DateTime.now()).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String shiftDateString(String dateStr, int offsetDays) {
  final parsed = DateTime.tryParse(dateStr);
  if (parsed == null) return localDateString();
  return localDateString(parsed.add(Duration(days: offsetDays)));
}

String formatCollectionDateLabel(String dateStr) {
  final today = localDateString();
  final yesterday = shiftDateString(today, -1);
  if (dateStr == today) return 'Today';
  if (dateStr == yesterday) return 'Yesterday';
  return dateStr;
}

String formatCollectionTime(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  final local = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
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
