double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int? _asInt(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

const kExpensePaymentMethods = <String, String>{
  'cash': 'Cash',
  'mpesa': 'M-PESA',
  'bank': 'Bank',
  'card': 'Card',
  'other': 'Other',
};

const kExpenseStatuses = <String, String>{
  'pending': 'Pending',
  'approved': 'Approved',
  'rejected': 'Rejected',
  'paid': 'Paid',
  'voided': 'Voided',
};

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.name,
    this.description = '',
    this.isActive = true,
    this.expenseCount = 0,
  });

  final int id;
  final String name;
  final String description;
  final bool isActive;
  final int expenseCount;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: _asInt(json['id']) ?? 0,
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      isActive: json['is_active'] != false,
      expenseCount: _asInt(json['expense_count']) ?? 0,
    );
  }
}

class Expense {
  const Expense({
    required this.id,
    required this.expenseNumber,
    required this.amount,
    required this.description,
    required this.status,
    this.categoryId,
    this.categoryName,
    this.paymentMethod = 'cash',
    this.vendor = '',
    this.receiptNumber = '',
    this.expenseDate = '',
    this.notes = '',
    this.createdById,
    this.createdByName,
    this.approvedById,
    this.approvedByName,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String expenseNumber;
  final double amount;
  final String description;
  final String status;
  final int? categoryId;
  final String? categoryName;
  final String paymentMethod;
  final String vendor;
  final String receiptNumber;
  final String expenseDate;
  final String notes;
  final int? createdById;
  final String? createdByName;
  final int? approvedById;
  final String? approvedByName;
  final String? createdAt;
  final String? updatedAt;

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isVoided => status == 'voided';
  bool get isPosted => status == 'approved' || status == 'paid';

  String get statusLabel => kExpenseStatuses[status] ?? status;
  String get paymentLabel =>
      kExpensePaymentMethods[paymentMethod] ?? paymentMethod;

  /// Aligns with web `financialRecordEditable` when maker-checker is on.
  bool isEditable({required bool makerCheckerEnabled}) {
    if (isVoided) return false;
    if (makerCheckerEnabled && isPosted) return false;
    return true;
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: _asInt(json['id']) ?? 0,
      expenseNumber: (json['expense_number'] ?? '').toString(),
      amount: _asDouble(json['amount']) ?? 0,
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      categoryId: _asInt(json['category']),
      categoryName: json['category_name']?.toString(),
      paymentMethod: (json['payment_method'] ?? 'cash').toString(),
      vendor: (json['vendor'] ?? '').toString(),
      receiptNumber: (json['receipt_number'] ?? '').toString(),
      expenseDate: (json['expense_date'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      createdById: _asInt(json['created_by']),
      createdByName: json['created_by_name']?.toString(),
      approvedById: _asInt(json['approved_by']),
      approvedByName: json['approved_by_name']?.toString(),
      createdAt: json['created_at']?.toString(),
      updatedAt: json['updated_at']?.toString(),
    );
  }

  Map<String, dynamic> toWriteBody({String? proposalReason}) {
    final body = <String, dynamic>{
      'category': categoryId,
      'amount': amount.toStringAsFixed(2),
      'description': description.trim(),
      'payment_method': paymentMethod,
      'vendor': vendor.trim(),
      'receipt_number': receiptNumber.trim(),
      'expense_date': expenseDate,
      'notes': notes.trim(),
    };
    if (proposalReason != null && proposalReason.trim().isNotEmpty) {
      body['proposal_reason'] = proposalReason.trim();
    }
    return body;
  }
}

class ExpenseListFilters {
  const ExpenseListFilters({
    this.status = '',
    this.categoryId = '',
    this.paymentMethod = '',
    this.dateFrom = '',
    this.dateTo = '',
    this.search = '',
  });

  final String status;
  final String categoryId;
  final String paymentMethod;
  final String dateFrom;
  final String dateTo;
  final String search;

  ExpenseListFilters copyWith({
    String? status,
    String? categoryId,
    String? paymentMethod,
    String? dateFrom,
    String? dateTo,
    String? search,
  }) {
    return ExpenseListFilters(
      status: status ?? this.status,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      search: search ?? this.search,
    );
  }

  Map<String, String> toQuery({int page = 1, int pageSize = 50}) {
    final q = <String, String>{
      'page': '$page',
      'page_size': '$pageSize',
      'show_all': 'true',
    };
    void put(String key, String value) {
      final v = value.trim();
      if (v.isNotEmpty) q[key] = v;
    }

    put('status', status);
    put('category', categoryId);
    put('payment_method', paymentMethod);
    put('date_from', dateFrom);
    put('date_to', dateTo);
    put('search', search);
    return q;
  }
}
