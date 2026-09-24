import 'wallet_debt.dart';

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item != null && item.toString().trim().isNotEmpty)
        item.toString().trim(),
  ];
}

class CustomerSummary {
  const CustomerSummary({
    required this.id,
    required this.name,
    this.customerCode,
    this.phone,
    this.email,
    this.walletBalance,
    this.totalOutstanding,
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? customerCode;
  final String? phone;
  final String? email;
  final double? walletBalance;
  final double? totalOutstanding;
  final bool isActive;

  double get debtAmount => debtAmountFromWalletBalance(walletBalance);
  CustomerStanding get standing => standingFromWallet(walletBalance);

  factory CustomerSummary.fromJson(Map<String, dynamic> json) {
    return CustomerSummary(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? '').toString(),
      customerCode: json['customer_code']?.toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      walletBalance: _asDouble(json['wallet_balance']),
      totalOutstanding: _asDouble(json['total_outstanding']),
      isActive: json['is_active'] != false,
    );
  }
}

class CustomerStandingSummary {
  const CustomerStandingSummary({
    required this.standing,
    this.walletBalance,
    this.walletDebt = 0,
    this.walletCredit = 0,
    this.totalOutstanding = 0,
    this.lifetimeOrders = 0,
    this.lifetimeSalesTotal = 0,
    this.totalDebtIncurred = 0,
    this.totalDebtCollected = 0,
  });

  final CustomerStanding standing;
  final double? walletBalance;
  final double walletDebt;
  final double walletCredit;
  final double totalOutstanding;
  final int lifetimeOrders;
  final double lifetimeSalesTotal;
  final double totalDebtIncurred;
  final double totalDebtCollected;

  factory CustomerStandingSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CustomerStandingSummary(standing: CustomerStanding.good);
    }
    final standingRaw = (json['standing'] ?? '').toString().toLowerCase();
    final standing = switch (standingRaw) {
      'debt' => CustomerStanding.debt,
      'credit' => CustomerStanding.credit,
      _ => standingFromWallet(_asDouble(json['wallet_balance'])),
    };
    return CustomerStandingSummary(
      standing: standing,
      walletBalance: _asDouble(json['wallet_balance']),
      walletDebt: _asDouble(json['wallet_debt']) ?? 0,
      walletCredit: _asDouble(json['wallet_credit']) ?? 0,
      totalOutstanding: _asDouble(json['total_outstanding']) ?? 0,
      lifetimeOrders: (json['lifetime_orders'] as num?)?.toInt() ?? 0,
      lifetimeSalesTotal: _asDouble(json['lifetime_sales_total']) ?? 0,
      totalDebtIncurred: _asDouble(json['total_debt_incurred']) ?? 0,
      totalDebtCollected: _asDouble(json['total_debt_collected']) ?? 0,
    );
  }
}

class CustomerDetail {
  const CustomerDetail({
    required this.id,
    required this.name,
    this.customerCode,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.notes,
    this.ownerName,
    this.contactPerson,
    this.typicalGoods = const [],
    this.walletBalance,
    this.totalOutstanding,
    this.standing = CustomerStanding.good,
    this.standingSummary,
    this.recentOrders = const [],
    this.ledger = const [],
    this.isActive = true,
  });

  final int id;
  final String name;
  final String? customerCode;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final String? notes;
  final String? ownerName;
  final String? contactPerson;
  final List<String> typicalGoods;
  final double? walletBalance;
  final double? totalOutstanding;
  final CustomerStanding standing;
  final CustomerStandingSummary? standingSummary;
  final List<CustomerOrderLite> recentOrders;
  final List<CustomerLedgerEntry> ledger;
  final bool isActive;

  double get debtAmount {
    final fromSummary = standingSummary?.walletDebt;
    if (fromSummary != null && fromSummary > 0) return fromSummary;
    return debtAmountFromWalletBalance(walletBalance);
  }

  double get creditAmount {
    final fromSummary = standingSummary?.walletCredit;
    if (fromSummary != null && fromSummary > 0) return fromSummary;
    final bal = walletBalance;
    if (bal == null || bal <= 0) return 0;
    return bal;
  }

  String get standingHeadline =>
      standingLabel(standing, debtAmount: debtAmount, credit: creditAmount);

  String get locationLine {
    final parts = [
      if (address != null && address!.trim().isNotEmpty) address!.trim(),
      if (city != null && city!.trim().isNotEmpty) city!.trim(),
    ];
    return parts.join(', ');
  }

  factory CustomerDetail.fromDetailJson(Map<String, dynamic> json) {
    final customer = Map<String, dynamic>.from(
      json['customer'] is Map
          ? Map<String, dynamic>.from(json['customer'] as Map)
          : json,
    );
    final summaryMap = json['standing_summary'] is Map
        ? Map<String, dynamic>.from(json['standing_summary'] as Map)
        : null;
    final summary = CustomerStandingSummary.fromJson(summaryMap);
    final standingRaw =
        (summaryMap?['standing'] ?? customer['standing'])
            ?.toString()
            .toLowerCase() ??
        '';
    final standing = switch (standingRaw) {
      'debt' => CustomerStanding.debt,
      'credit' => CustomerStanding.credit,
      _ => standingFromWallet(_asDouble(customer['wallet_balance'])),
    };

    final orders = <CustomerOrderLite>[];
    final rawOrders = json['orders'];
    if (rawOrders is List) {
      for (final item in rawOrders) {
        if (item is Map) {
          orders.add(
            CustomerOrderLite.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    final ledger = <CustomerLedgerEntry>[];
    final rawLedger = json['ledger'];
    if (rawLedger is List) {
      for (final item in rawLedger) {
        if (item is Map) {
          ledger.add(
            CustomerLedgerEntry.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return CustomerDetail(
      id: (customer['id'] as num).toInt(),
      name: (customer['name'] ?? '').toString(),
      customerCode: customer['customer_code']?.toString(),
      phone: customer['phone']?.toString(),
      email: customer['email']?.toString(),
      address: customer['address']?.toString(),
      city: customer['city']?.toString(),
      notes: customer['notes']?.toString(),
      ownerName: customer['owner_name']?.toString(),
      contactPerson: customer['contact_person']?.toString(),
      typicalGoods: _stringList(customer['typical_goods']),
      walletBalance: _asDouble(customer['wallet_balance']),
      totalOutstanding: _asDouble(customer['total_outstanding']),
      standing: standing,
      standingSummary: summary,
      recentOrders: orders,
      ledger: ledger,
      isActive: customer['is_active'] != false,
    );
  }
}

class CustomerOrderLite {
  const CustomerOrderLite({
    required this.id,
    required this.saleNumber,
    required this.total,
    this.createdAt,
    this.debtAmount = 0,
    this.paidAmount = 0,
    this.paymentStatus = 'paid',
    this.notes,
    this.itemCount,
    this.clientChannel,
  });

  final int id;
  final String saleNumber;
  final double total;
  final String? createdAt;
  final double debtAmount;
  final double paidAmount;
  final String paymentStatus;
  final String? notes;
  final int? itemCount;
  final String? clientChannel;

  bool get hasOpenDebt => debtAmount > 0.009;

  factory CustomerOrderLite.fromJson(Map<String, dynamic> json) {
    return CustomerOrderLite(
      id: (json['id'] as num?)?.toInt() ?? 0,
      saleNumber: (json['sale_number'] ?? json['id'] ?? '').toString(),
      total: _asDouble(json['total']) ?? 0,
      createdAt:
          json['occurred_at']?.toString() ??
          json['created_at']?.toString() ??
          json['sale_date']?.toString(),
      debtAmount: _asDouble(json['debt_amount']) ?? 0,
      paidAmount:
          _asDouble(json['paid_amount']) ?? _asDouble(json['amount_paid']) ?? 0,
      paymentStatus: (json['payment_status'] ?? 'paid').toString(),
      notes: json['notes']?.toString(),
      itemCount: (json['item_count'] as num?)?.toInt(),
      clientChannel: json['client_channel']?.toString(),
    );
  }
}

class CustomerLedgerEntry {
  const CustomerLedgerEntry({
    required this.id,
    required this.transactionType,
    required this.sourceType,
    required this.amount,
    this.reference = '',
    this.notes = '',
    this.saleId,
    this.saleNumber,
    this.createdAt,
    this.previousDebt,
    this.newDebt,
    this.paymentAmount,
    this.debtAdded,
    this.balanceAfter,
  });

  final int id;
  final String transactionType;
  final String sourceType;
  final double amount;
  final String reference;
  final String notes;
  final int? saleId;
  final String? saleNumber;
  final String? createdAt;
  final double? previousDebt;
  final double? newDebt;
  final double? paymentAmount;
  final double? debtAdded;
  final double? balanceAfter;

  bool get isSettlement =>
      sourceType == 'debt_settlement' ||
      (transactionType == 'credit' && sourceType != 'debt');

  bool get stillOwes {
    if (newDebt != null) return newDebt! > 0.005;
    if (balanceAfter != null) return balanceAfter! < -0.005;
    return false;
  }

  double get remainingDebt {
    if (newDebt != null && newDebt! > 0.005) return newDebt!;
    if (balanceAfter != null && balanceAfter! < -0.005) {
      return -balanceAfter!;
    }
    return 0;
  }

  factory CustomerLedgerEntry.fromJson(Map<String, dynamic> json) {
    return CustomerLedgerEntry(
      id: (json['id'] as num?)?.toInt() ?? 0,
      transactionType: (json['transaction_type'] ?? '').toString(),
      sourceType: (json['source_type'] ?? '').toString(),
      amount: _asDouble(json['amount']) ?? 0,
      reference: (json['reference'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      saleId: (json['sale'] as num?)?.toInt(),
      saleNumber: json['sale_number']?.toString(),
      createdAt: json['created_at']?.toString(),
      previousDebt: _asDouble(json['previous_debt']),
      newDebt: _asDouble(json['new_debt']),
      paymentAmount: _asDouble(json['payment_amount']),
      debtAdded: _asDouble(json['debt_added']),
      balanceAfter: _asDouble(json['balance_after']),
    );
  }
}

class DebtAgingBuckets {
  const DebtAgingBuckets({
    this.current = 0,
    this.pending = 0,
    this.overdue = 0,
  });

  final double current;
  final double pending;
  final double overdue;

  double get total => current + pending + overdue;

  /// Buckets open debt on recent orders by age of [CustomerOrderLite.createdAt].
  static DebtAgingBuckets fromOrders(
    List<CustomerOrderLite> orders, {
    DateTime? now,
  }) {
    final clock = now ?? DateTime.now();
    var current = 0.0;
    var pending = 0.0;
    var overdue = 0.0;
    for (final order in orders) {
      if (!order.hasOpenDebt) continue;
      final when = DateTime.tryParse(order.createdAt ?? '');
      final days = when == null ? 0 : clock.difference(when).inDays;
      if (days <= 14) {
        current += order.debtAmount;
      } else if (days <= 30) {
        pending += order.debtAmount;
      } else {
        overdue += order.debtAmount;
      }
    }
    return DebtAgingBuckets(
      current: current,
      pending: pending,
      overdue: overdue,
    );
  }
}

class CustomerDraft {
  const CustomerDraft({
    required this.name,
    this.phone = '',
    this.email = '',
    this.notes = '',
    this.ownerName = '',
    this.contactPerson = '',
    this.city = '',
    this.address = '',
    this.typicalGoods = const [],
  });

  final String name;
  final String phone;
  final String email;
  final String notes;
  final String ownerName;
  final String contactPerson;
  final String city;
  final String address;
  final List<String> typicalGoods;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'phone': phone.trim(),
    'email': email.trim(),
    'notes': notes.trim(),
    'owner_name': ownerName.trim(),
    'contact_person': contactPerson.trim(),
    'city': city.trim(),
    'address': address.trim(),
    'typical_goods': [
      for (final item in typicalGoods)
        if (item.trim().isNotEmpty) item.trim(),
    ],
  };
}

class CustomersModuleSettings {
  const CustomersModuleSettings({
    this.showWalletBalance = true,
    this.enableWalletPayment = true,
    this.enableCustomerCreate = true,
    this.enableCustomerEdit = true,
    this.allowQuickAddAtPos = true,
  });

  final bool showWalletBalance;
  final bool enableWalletPayment;
  final bool enableCustomerCreate;
  final bool enableCustomerEdit;
  final bool allowQuickAddAtPos;

  factory CustomersModuleSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CustomersModuleSettings();

    // Supports flat flags or GET /api/settings/customers/ shape:
    // { "module": "customers", "settings": { "key": { "value": true } } }
    var values = Map<String, dynamic>.from(json);
    final nested = json['settings'];
    if (nested is Map) {
      final flat = <String, dynamic>{};
      for (final entry in nested.entries) {
        final raw = entry.value;
        if (raw is Map && raw.containsKey('value')) {
          flat[entry.key.toString()] = raw['value'];
        } else {
          flat[entry.key.toString()] = raw;
        }
      }
      values = flat;
    }

    bool read(String key, bool fallback) {
      if (!values.containsKey(key)) return fallback;
      return values[key] == true;
    }

    return CustomersModuleSettings(
      showWalletBalance: read('show_wallet_balance', true),
      enableWalletPayment: read('enable_wallet_payment', true),
      enableCustomerCreate: read('enable_customer_create', true),
      enableCustomerEdit: read('enable_customer_edit', true),
      allowQuickAddAtPos: read('allow_quick_add_at_pos', true),
    );
  }

  bool canSettleDebt({required bool hasUpdatePermission}) =>
      hasUpdatePermission && showWalletBalance && enableWalletPayment;
}
