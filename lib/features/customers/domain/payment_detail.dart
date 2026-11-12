// Full debt-collection / wallet settlement detail for review after receipt.

double _asDouble(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

class PaymentTowardsTarget {
  const PaymentTowardsTarget({
    required this.label,
    this.amount = 0,
    this.saleId,
    this.saleNumber,
    this.invoiceId,
    this.invoiceNumber,
    this.type = '',
  });

  final String label;
  final double amount;
  final int? saleId;
  final String? saleNumber;
  final int? invoiceId;
  final String? invoiceNumber;
  final String type;

  factory PaymentTowardsTarget.fromJson(Map<String, dynamic> json) {
    return PaymentTowardsTarget(
      label: (json['label'] ?? '').toString(),
      amount: _asDouble(json['amount']),
      saleId: (json['sale_id'] as num?)?.toInt(),
      saleNumber: json['sale_number']?.toString(),
      invoiceId: (json['invoice_id'] as num?)?.toInt(),
      invoiceNumber: json['invoice_number']?.toString(),
      type: (json['type'] ?? '').toString(),
    );
  }
}

class PaymentDetail {
  const PaymentDetail({
    required this.id,
    required this.amount,
    this.kind = 'debt_settlement',
    this.customerId,
    this.customerName = '',
    this.customerPhone = '',
    this.customerCode = '',
    this.paymentMethod = '',
    this.paymentMethodLabel = '',
    this.reference = '',
    this.notes = '',
    this.payerName = '',
    this.payerPhone = '',
    this.mpesaDestination = '',
    this.mpesaDestinationLabel = '',
    this.receivedBy = '',
    this.receiptImageUrl = '',
    this.occurredAt,
    this.isBackdated = false,
    this.balanceAfter,
    this.previousDebt,
    this.newDebt,
    this.paidTowardsLabel = '',
    this.paidTowards = const [],
    this.saleNumber,
  });

  final int id;
  final String kind;
  final double amount;
  final int? customerId;
  final String customerName;
  final String customerPhone;
  final String customerCode;
  final String paymentMethod;
  final String paymentMethodLabel;
  final String reference;
  final String notes;
  final String payerName;
  final String payerPhone;
  final String mpesaDestination;
  final String mpesaDestinationLabel;
  final String receivedBy;
  final String receiptImageUrl;
  final String? occurredAt;
  final bool isBackdated;
  final double? balanceAfter;
  final double? previousDebt;
  final double? newDebt;
  final String paidTowardsLabel;
  final List<PaymentTowardsTarget> paidTowards;
  final String? saleNumber;

  String get methodDisplay {
    final base = paymentMethodLabel.trim().isNotEmpty
        ? paymentMethodLabel.trim()
        : (paymentMethod.trim().isEmpty
            ? '—'
            : paymentMethod.replaceAll('_', ' '));
    final via = mpesaDestinationLabel.trim().isNotEmpty
        ? mpesaDestinationLabel.trim()
        : (mpesaDestination == 'till'
            ? 'Till'
            : mpesaDestination == 'bank'
                ? 'Bank'
                : '');
    if (via.isEmpty) return base;
    return '$base · $via';
  }

  String get payerDisplay {
    final name = payerName.trim();
    final phone = payerPhone.trim();
    if (name.isNotEmpty && phone.isNotEmpty) return '$name · $phone';
    return name.isNotEmpty ? name : (phone.isNotEmpty ? phone : '—');
  }

  factory PaymentDetail.fromJson(Map<String, dynamic> json) {
    final targets = <PaymentTowardsTarget>[];
    final raw = json['paid_towards'];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          targets.add(
            PaymentTowardsTarget.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }
    return PaymentDetail(
      id: (json['id'] as num?)?.toInt() ?? 0,
      kind: (json['kind'] ?? 'debt_settlement').toString(),
      amount: _asDouble(json['amount']),
      customerId: (json['customer_id'] as num?)?.toInt(),
      customerName: (json['customer_name'] ?? '').toString(),
      customerPhone: (json['customer_phone'] ?? '').toString(),
      customerCode: (json['customer_code'] ?? '').toString(),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      paymentMethodLabel: (json['payment_method_label'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      payerName: (json['payer_name'] ?? '').toString(),
      payerPhone: (json['payer_phone'] ?? '').toString(),
      mpesaDestination: (json['mpesa_destination'] ?? '').toString(),
      mpesaDestinationLabel:
          (json['mpesa_destination_label'] ?? '').toString(),
      receivedBy: (json['received_by'] ?? json['created_by_name'] ?? '')
          .toString(),
      receiptImageUrl: (json['receipt_image_url'] ?? '').toString(),
      occurredAt: (json['occurred_at'] ?? json['created_at'])?.toString(),
      isBackdated: json['is_backdated'] == true,
      balanceAfter: json.containsKey('balance_after')
          ? _asDouble(json['balance_after'])
          : null,
      previousDebt: json.containsKey('previous_debt')
          ? _asDouble(json['previous_debt'])
          : null,
      newDebt:
          json.containsKey('new_debt') ? _asDouble(json['new_debt']) : null,
      paidTowardsLabel: (json['paid_towards_label'] ?? '').toString(),
      paidTowards: targets,
      saleNumber: json['sale_number']?.toString(),
    );
  }
}
