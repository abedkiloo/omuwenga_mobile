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
  });

  final bool requireCustomer;
  final bool showTax;
  final bool showDiscount;
  final List<PosPaymentMethod> enabledPaymentMethods;

  factory PosSettings.fromApis({
    Map<String, dynamic>? sales,
    Map<String, dynamic>? store,
  }) {
    final requireCustomer = sales?['require_customer'] == true;
    final showTax = sales?['show_tax'] == true;
    final showDiscount = sales?['show_discount'] == true;

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
  });

  final PosPaymentMethod method;
  final double amountPaid;
  final String paymentReference;
}

/// Returns null when checkout is valid; otherwise a short human reason.
String? validateCheckout({
  required PosCart cart,
  required PosSettings settings,
  required CheckoutDraft draft,
}) {
  if (cart.isEmpty) return 'Add at least one product.';
  if (settings.requireCustomer && cart.customerId == null) {
    return 'Duka is required.';
  }
  if (!settings.enabledPaymentMethods.contains(draft.method)) {
    return 'Payment method is not enabled.';
  }
  if (draft.amountPaid + 1e-9 < cart.total) {
    return 'Amount paid is less than total.';
  }
  if (draft.method.requiresReference && draft.paymentReference.trim().isEmpty) {
    return 'Payment reference is required.';
  }
  return null;
}

bool canSubmitCheckout({
  required PosCart cart,
  required PosSettings settings,
  required CheckoutDraft draft,
}) => validateCheckout(cart: cart, settings: settings, draft: draft) == null;
