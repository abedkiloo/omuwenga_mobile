import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const product = CatalogProduct(
    id: 1,
    name: 'Cement 50kg',
    price: 150,
    sku: 'CEM-50',
    stockQuantity: 10,
  );

  group('PosCart', () {
    test('totals add update remove', () {
      var cart = const PosCart().addProduct(product).addProduct(product);
      expect(cart.lines, hasLength(1));
      expect(cart.lines.single.quantity, 2);
      expect(cart.subtotal, 300);
      expect(cart.total, 300);

      cart = cart.updateQuantity('1', 3);
      expect(cart.total, 450);

      cart = cart.copyWith(taxAmount: 10, discountAmount: 5);
      expect(cart.total, 455);

      cart = cart.removeProduct(1);
      expect(cart.isEmpty, isTrue);
      expect(cart.isDirty, isFalse);
    });

    test('customer attach and sale items json', () {
      final cart = const PosCart()
          .addProduct(product)
          .attachCustomer(id: 9, name: 'Ada');
      expect(cart.customerId, 9);
      expect(cart.clearCustomer().customerId, isNull);
      expect(cart.toSaleItemsJson().single['product_id'], 1);
    });
  });

  group('checkout validation', () {
    test('pay disabled until valid', () {
      const settings = PosSettings();
      const empty = PosCart();
      expect(
        canSubmitCheckout(
          cart: empty,
          settings: settings,
          draft: const CheckoutDraft(
            method: PosPaymentMethod.cash,
            amountPaid: 0,
          ),
        ),
        isFalse,
      );

      final cart = const PosCart().addProduct(product);
      expect(
        canSubmitCheckout(
          cart: cart,
          settings: settings,
          draft: CheckoutDraft(
            method: PosPaymentMethod.cash,
            amountPaid: cart.total,
          ),
        ),
        isTrue,
      );
      expect(
        canSubmitCheckout(
          cart: cart,
          settings: settings,
          draft: const CheckoutDraft(
            method: PosPaymentMethod.mpesa,
            amountPaid: 150,
          ),
        ),
        isTrue,
      );
      expect(
        canSubmitCheckout(
          cart: cart,
          settings: settings,
          draft: const CheckoutDraft(
            method: PosPaymentMethod.mpesa,
            amountPaid: 150,
            paymentReference: 'QHX1',
          ),
        ),
        isTrue,
      );
      expect(
        canSubmitCheckout(
          cart: cart,
          settings: settings,
          draft: const CheckoutDraft(
            method: PosPaymentMethod.card,
            amountPaid: 150,
          ),
        ),
        isFalse,
      );
    });

    test('require customer and settings parse', () {
      final settings = PosSettings.fromApis(
        sales: {'require_customer': true, 'show_tax': true},
        store: {
          'enabled_payment_methods': ['cash', 'wallet', 'mpesa', 'crypto'],
        },
      );
      expect(settings.requireCustomer, isTrue);
      expect(settings.showTax, isTrue);
      expect(settings.enabledPaymentMethods, [
        PosPaymentMethod.cash,
        PosPaymentMethod.mpesa,
      ]);
      expect(PosPaymentMethod.card.label, 'Card');
      expect(PosPaymentMethodX.tryParse('other'), PosPaymentMethod.other);
    });
  });
}
