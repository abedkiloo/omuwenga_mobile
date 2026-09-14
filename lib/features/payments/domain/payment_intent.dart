enum PaymentIntentStatus {
  created,
  prompted,
  paid,
  failed,
  cancelled,
  expired;

  static PaymentIntentStatus parse(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'prompted':
        return PaymentIntentStatus.prompted;
      case 'paid':
        return PaymentIntentStatus.paid;
      case 'failed':
        return PaymentIntentStatus.failed;
      case 'cancelled':
        return PaymentIntentStatus.cancelled;
      case 'expired':
        return PaymentIntentStatus.expired;
      default:
        return PaymentIntentStatus.created;
    }
  }

  bool get isTerminal =>
      this == paid || this == failed || this == cancelled || this == expired;

  bool get isWaiting => this == created || this == prompted;
}

enum PaymentPurpose { pos, debt, delivery, other }

class PaymentIntent {
  const PaymentIntent({
    required this.id,
    required this.amount,
    required this.phone,
    required this.status,
    this.purpose = PaymentPurpose.other,
    this.invoiceNumber = '',
    this.invoiceLinkToken = '',
    this.mpesaReceipt,
    this.failureReason,
    this.smsQueued = false,
    this.smsSent = false,
    this.customerName,
  });

  final int id;
  final double amount;
  final String phone;
  final PaymentIntentStatus status;
  final PaymentPurpose purpose;
  final String invoiceNumber;
  final String invoiceLinkToken;
  final String? mpesaReceipt;
  final String? failureReason;
  final bool smsQueued;
  final bool smsSent;
  final String? customerName;

  factory PaymentIntent.fromJson(Map<String, dynamic> json) {
    final purposeRaw = (json['purpose'] ?? 'other').toString();
    final purpose = PaymentPurpose.values.firstWhere(
      (p) => p.name == purposeRaw,
      orElse: () => PaymentPurpose.other,
    );
    return PaymentIntent(
      id: (json['id'] as num).toInt(),
      amount: double.tryParse('${json['amount']}') ?? 0,
      phone: (json['phone'] ?? '').toString(),
      status: PaymentIntentStatus.parse(json['status']?.toString()),
      purpose: purpose,
      invoiceNumber: (json['invoice_number'] ?? '').toString(),
      invoiceLinkToken: (json['invoice_link_token'] ?? '').toString(),
      mpesaReceipt: json['mpesa_receipt']?.toString(),
      failureReason: json['failure_reason']?.toString(),
      smsQueued: json['sms_queued'] == true,
      smsSent: json['sms_sent'] == true,
      customerName: json['customer_name']?.toString(),
    );
  }
}
