import '../../../core/validation/field_types.dart';
import 'cart.dart';

enum PosPaymentMethod { cash, mpesa, card, other }

extension PosPaymentMethodX on PosPaymentMethod {
  String get apiValue => name;

  String get label {
    switch (this) {
      case PosPaymentMethod.cash:
        return 'Cash';
      case PosPaymentMethod.mpesa:
        return 'M-Pesa';
      case PosPaymentMethod.card:
        return 'Card';
      case PosPaymentMethod.other:
        return 'Other';
    }
  }

  bool get requiresReference =>
      this == PosPaymentMethod.card || this == PosPaymentMethod.other;

  static PosPaymentMethod? tryParse(String raw) {
    final key = raw.trim().toLowerCase();
    for (final m in PosPaymentMethod.values) {
      if (m.name == key) return m;
    }
    return null;
  }
}

/// Store / sales flags that gate POS lite — safe defaults never crash the UI.
class PosSettings {
  const PosSettings({
    this.requireCustomer = false,
    this.showTax = false,
    this.showDiscount = false,
    this.enabledPaymentMethods = const [
      PosPaymentMethod.cash,
      PosPaymentMethod.mpesa,
      PosPaymentMethod.card,
    ],
    this.allowPartialPayment = true,
  });

  final bool requireCustomer;
  final bool showTax;
  final bool showDiscount;
  final List<PosPaymentMethod> enabledPaymentMethods;
  final bool allowPartialPayment;

  factory PosSettings.fromApis({
    Map<String, dynamic>? sales,
    Map<String, dynamic>? store,
  }) {
    final requireCustomer = sales?['require_customer'] == true;
    final showTax = sales?['show_tax'] == true;
    final showDiscount = sales?['show_discount'] == true;
    final allowPartial = sales?['allow_partial_payment'];

    final rawMethods = store?['enabled_payment_methods'];
    final methods = <PosPaymentMethod>[];
    if (rawMethods is List) {
      for (final item in rawMethods) {
        final parsed = PosPaymentMethodX.tryParse(item.toString());
        // wallet is not a payment_method on create — skip for method chips
        if (parsed != null) methods.add(parsed);
      }
    }
    return PosSettings(
      requireCustomer: requireCustomer,
      showTax: showTax,
      showDiscount: showDiscount,
      allowPartialPayment: allowPartial == null ? true : allowPartial == true,
      enabledPaymentMethods: methods.isEmpty
          ? const PosSettings().enabledPaymentMethods
          : methods,
    );
  }
}

class CheckoutDraft {
  const CheckoutDraft({
    required this.method,
    required this.amountPaid,
    this.paymentReference = '',
    this.paymentOnAccount = false,
  });

  final PosPaymentMethod method;
  final double amountPaid;
  final String paymentReference;

  /// Cashier opted to put unpaid balance on the customer account.
  final bool paymentOnAccount;

  CheckoutDraft copyWith({
    PosPaymentMethod? method,
    double? amountPaid,
    String? paymentReference,
    bool? paymentOnAccount,
  }) {
    return CheckoutDraft(
      method: method ?? this.method,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentOnAccount: paymentOnAccount ?? this.paymentOnAccount,
    );
  }
}

enum CheckoutKind { full, partial, payLater }

CheckoutKind checkoutKind({required double total, required double paid}) {
  if (paid + 1e-9 >= total) return CheckoutKind.full;
  if (paid <= 0) return CheckoutKind.payLater;
  return CheckoutKind.partial;
}

double accountBalanceDue(double total, double paid) {
  final due = total - paid;
  return due < 0 ? 0 : due;
}

bool isUnderpaid({required double total, required double paid}) =>
    paid + 1e-9 < total;

Map<String, dynamic> posSaleRequestBody({
  required PosCart cart,
  required CheckoutDraft draft,
}) {
  final underpaid = isUnderpaid(total: cart.total, paid: draft.amountPaid);
  return <String, dynamic>{
    'sale_type': 'pos',
    'client_channel': 'mobile',
    'items': cart.toSaleItemsJson(),
    'payment_method': draft.method.apiValue,
    'amount_paid': draft.amountPaid,
    'tax_amount': cart.taxAmount,
    'discount_amount': cart.discountAmount,
    'allow_partial_payment': draft.paymentOnAccount && underpaid,
    'excess_payment_choice': 'change',
    if (cart.customerId != null) 'customer_id': cart.customerId,
    if (draft.paymentReference.trim().isNotEmpty)
      'payment_reference': draft.paymentReference.trim(),
  };
}

/// Returns null when checkout is valid; otherwise a short human reason.
String? validateCheckout({
  required PosCart cart,
  required PosSettings settings,
  required CheckoutDraft draft,
}) {
  if (cart.isEmpty) return 'Add at least one product.';
  if (settings.requireCustomer && cart.customerId == null) {
    return 'Customer is required.';
  }
  if (!settings.enabledPaymentMethods.contains(draft.method)) {
    return 'Payment method is not enabled.';
  }
  if (draft.amountPaid < 0) {
    return 'Enter a KES amount, e.g. $kPaymentAmountExample';
  }
  if (isUnderpaid(total: cart.total, paid: draft.amountPaid)) {
    if (!settings.allowPartialPayment) {
      return 'Payment on account is disabled in store settings.';
    }
    if (!draft.paymentOnAccount) {
      return 'Enable “Payment on customer account” for a partial payment or pay later.';
    }
    if (cart.customerId == null) {
      return 'Assign a customer before recording a balance on their account.';
    }
  }
  if (draft.method.requiresReference &&
      draft.paymentReference.trim().isEmpty &&
      !isUnderpaid(total: cart.total, paid: draft.amountPaid)) {
    if (draft.method == PosPaymentMethod.mpesa) {
      return mpesaReceiptValidationMessage(draft.paymentReference);
    }
    return 'Enter the payment reference, e.g. card slip number.';
  }
  return null;
}

bool canSubmitCheckout({
  required PosCart cart,
  required PosSettings settings,
  required CheckoutDraft draft,
}) => validateCheckout(cart: cart, settings: settings, draft: draft) == null;
