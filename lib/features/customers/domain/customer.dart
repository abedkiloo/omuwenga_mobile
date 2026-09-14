import 'wallet_debt.dart';

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
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
    this.walletBalance,
    this.totalOutstanding,
    this.standing = CustomerStanding.good,
    this.recentOrders = const [],
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
  final double? walletBalance;
  final double? totalOutstanding;
  final CustomerStanding standing;
  final List<CustomerOrderLite> recentOrders;
  final bool isActive;

  double get debtAmount => debtAmountFromWalletBalance(walletBalance);
  double get creditAmount {
    final bal = walletBalance;
    if (bal == null || bal <= 0) return 0;
    return bal;
  }

  String get standingHeadline => standingLabel(
        standing,
        debtAmount: debtAmount,
        credit: creditAmount,
      );

  factory CustomerDetail.fromDetailJson(Map<String, dynamic> json) {
    final customer = Map<String, dynamic>.from(
      json['customer'] is Map ? Map<String, dynamic>.from(json['customer'] as Map) : json,
    );
    final summary = json['standing_summary'];
    final standingRaw = (summary is Map ? summary['standing'] : customer['standing'])
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
          orders.add(CustomerOrderLite.fromJson(Map<String, dynamic>.from(item)));
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
      walletBalance: _asDouble(customer['wallet_balance']),
      totalOutstanding: _asDouble(customer['total_outstanding']),
      standing: standing,
      recentOrders: orders,
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
  });

  final int id;
  final String saleNumber;
  final double total;
  final String? createdAt;

  factory CustomerOrderLite.fromJson(Map<String, dynamic> json) {
    return CustomerOrderLite(
      id: (json['id'] as num?)?.toInt() ?? 0,
      saleNumber: (json['sale_number'] ?? json['id'] ?? '').toString(),
      total: _asDouble(json['total']) ?? 0,
      createdAt: json['created_at']?.toString() ?? json['sale_date']?.toString(),
    );
  }
}

class CustomerDraft {
  const CustomerDraft({
    required this.name,
    this.phone = '',
    this.email = '',
    this.notes = '',
  });

  final String name;
  final String phone;
  final String email;
  final String notes;

  Map<String, dynamic> toJson() => {
        'name': name.trim(),
        if (phone.trim().isNotEmpty) 'phone': phone.trim(),
        if (email.trim().isNotEmpty) 'email': email.trim(),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
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
