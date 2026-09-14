import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart' as app;
import '../../../sync/application/connectivity_monitor.dart';
import '../../../sync/data/outbox_store.dart';
import '../../../sync/domain/client_uuid.dart';
import '../../../sync/domain/outbox_entry.dart';
import '../../../sync/providers.dart';
import '../data/pos_api.dart';
import '../domain/cart.dart';
import '../domain/payment.dart';
import '../domain/product_variant.dart';

final posApiProvider = Provider<PosApi>((ref) {
  return PosApi(ref.watch(app.apiClientProvider));
});

final posSettingsProvider = FutureProvider<PosSettings>((ref) async {
  final result = await ref.watch(posApiProvider).loadSettings();
  return result.when(
    success: (s) => s,
    failure: (_, _) => const PosSettings(),
  );
});

class CartController extends StateNotifier<PosCart> {
  CartController() : super(const PosCart());

  void addProduct(
    CatalogProduct product, {
    ProductVariant? variant,
    double qty = 1,
  }) {
    state = state.addProduct(product, variant: variant, qty: qty);
  }

  void setQuantity(String lineKey, double quantity) {
    state = state.updateQuantity(lineKey, quantity);
  }

  void removeProduct(String lineKey) {
    state = state.removeLine(lineKey);
  }

  void attachCustomer({required int id, required String name}) {
    state = state.attachCustomer(id: id, name: name);
  }

  void clearCustomer() {
    state = state.clearCustomer();
  }

  void clear() {
    state = state.clear();
  }
}

final cartControllerProvider =
    StateNotifierProvider<CartController, PosCart>((ref) => CartController());

enum CheckoutPhase { idle, submitting, success, queued, error }

class CheckoutState {
  const CheckoutState({
    this.phase = CheckoutPhase.idle,
    this.receipt,
    this.message,
    this.draft = const CheckoutDraft(
      method: PosPaymentMethod.cash,
      amountPaid: 0,
    ),
  });

  final CheckoutPhase phase;
  final SaleReceipt? receipt;
  final String? message;
  final CheckoutDraft draft;

  CheckoutState copyWith({
    CheckoutPhase? phase,
    SaleReceipt? receipt,
    String? message,
    CheckoutDraft? draft,
    bool clearMessage = false,
    bool clearReceipt = false,
  }) {
    return CheckoutState(
      phase: phase ?? this.phase,
      receipt: clearReceipt ? null : (receipt ?? this.receipt),
      message: clearMessage ? null : (message ?? this.message),
      draft: draft ?? this.draft,
    );
  }
}

class CheckoutController extends StateNotifier<CheckoutState> {
  CheckoutController({
    required PosApi api,
    required OutboxStore outbox,
    required ConnectivityMonitor connectivity,
    required Ref ref,
    ClientUuid? ids,
  })  : _api = api,
        _outbox = outbox,
        _connectivity = connectivity,
        _ref = ref,
        _ids = ids ?? ClientUuid(),
        super(const CheckoutState());

  final PosApi _api;
  final OutboxStore _outbox;
  final ConnectivityMonitor _connectivity;
  final Ref _ref;
  final ClientUuid _ids;

  void setDraft(CheckoutDraft draft) {
    state = state.copyWith(draft: draft, clearMessage: true);
  }

  Future<bool> submit() async {
    final cart = _ref.read(cartControllerProvider);
    final settings = _ref.read(posSettingsProvider).maybeWhen(
          data: (s) => s,
          orElse: () => const PosSettings(),
        );
    final reason = validateCheckout(
      cart: cart,
      settings: settings,
      draft: state.draft,
    );
    if (reason != null) {
      state = state.copyWith(phase: CheckoutPhase.error, message: reason);
      return false;
    }

    state = state.copyWith(phase: CheckoutPhase.submitting, clearMessage: true);
    final key = _ids.next();
    final online = await _connectivity.isOnline;

    if (!online) {
      final body = <String, dynamic>{
        'sale_type': 'pos',
        'items': cart.toSaleItemsJson(),
        'payment_method': state.draft.method.apiValue,
        'amount_paid': state.draft.amountPaid,
        'tax_amount': cart.taxAmount,
        'discount_amount': cart.discountAmount,
        'allow_partial_payment': false,
        'excess_payment_choice': 'change',
        if (cart.customerId != null) 'customer_id': cart.customerId,
        if (state.draft.paymentReference.trim().isNotEmpty)
          'payment_reference': state.draft.paymentReference.trim(),
      };
      await _outbox.enqueue(
        EnqueueMutation(
          method: 'POST',
          path: 'sales/',
          bodyJson: jsonEncode(body),
          idempotencyKey: key,
          clientResourceId: key,
        ),
      );
      final queued = SaleReceipt(
        id: null,
        saleNumber: 'QUEUED',
        total: cart.total,
        paymentMethod: state.draft.method.apiValue,
        amountPaid: state.draft.amountPaid,
        change: (state.draft.amountPaid - cart.total).clamp(0, double.infinity),
        items: cart.lines,
        customerName: cart.customerName,
        queuedOffline: true,
      );
      state = state.copyWith(phase: CheckoutPhase.queued, receipt: queued);
      _ref.read(cartControllerProvider.notifier).clear();
      return true;
    }

    final result = await _api.createSale(
      cart: cart,
      draft: state.draft,
      idempotencyKey: key,
    );
    return result.when(
      success: (receipt) {
        state = state.copyWith(phase: CheckoutPhase.success, receipt: receipt);
        _ref.read(cartControllerProvider.notifier).clear();
        return true;
      },
      failure: (error, _) {
        state = state.copyWith(
          phase: CheckoutPhase.error,
          message: error.toString(),
        );
        return false;
      },
    );
  }

  void resetPhase() {
    state = state.copyWith(
      phase: CheckoutPhase.idle,
      clearMessage: true,
      clearReceipt: true,
    );
  }
}

final checkoutControllerProvider =
    StateNotifierProvider<CheckoutController, CheckoutState>((ref) {
  return CheckoutController(
    api: ref.watch(posApiProvider),
    outbox: ref.watch(outboxStoreProvider),
    connectivity: ref.watch(connectivityMonitorProvider),
    ref: ref,
  );
});
