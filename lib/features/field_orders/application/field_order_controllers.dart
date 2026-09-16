import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/notifications/push_notifier.dart';
import '../../../core/result/result.dart';
import '../../pos/domain/cart.dart';
import '../../pos/domain/product_variant.dart';
import '../data/field_orders_api.dart';
import '../domain/field_order.dart';

final pushNotifierProvider = Provider<PushNotifier>(
  (ref) => FakePushNotifier(),
);

final fieldOrdersApiProvider = Provider<FieldOrdersApi>((ref) {
  return FieldOrdersApi(ref.watch(apiClientProvider));
});

class FieldOrderCartState {
  const FieldOrderCartState({
    this.cart = const FieldOrderCart(siteId: 0),
    this.submitting = false,
    this.error,
    this.submittedOrderId,
  });

  final FieldOrderCart cart;
  final bool submitting;
  final String? error;
  final int? submittedOrderId;

  bool get canSubmit => cart.canSubmit && !submitting;

  FieldOrderCartState copyWith({
    FieldOrderCart? cart,
    bool? submitting,
    String? error,
    int? submittedOrderId,
    bool clearError = false,
  }) {
    return FieldOrderCartState(
      cart: cart ?? this.cart,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
      submittedOrderId: submittedOrderId ?? this.submittedOrderId,
    );
  }
}

class FieldOrderCartController extends StateNotifier<FieldOrderCartState> {
  FieldOrderCartController(this._api, this._push)
    : super(const FieldOrderCartState());

  final FieldOrdersApi _api;
  final PushNotifier _push;

  void bindSite({
    required int siteId,
    String label = '',
    List<String> photoUrls = const [],
    double? latitude,
    double? longitude,
  }) {
    state = state.copyWith(
      cart: state.cart.copyWith(
        siteId: siteId,
        siteLabel: label,
        photoUrls: photoUrls,
        latitude: latitude,
        longitude: longitude,
      ),
      clearError: true,
    );
  }

  void addProduct(
    CatalogProduct product, {
    ProductVariant? variant,
    double qty = 1,
  }) {
    state = state.copyWith(
      cart: state.cart.addProduct(product, variant: variant, qty: qty),
      clearError: true,
    );
  }

  void setNotes(String notes) {
    state = state.copyWith(cart: state.cart.copyWith(notes: notes));
  }

  Future<bool> submit() async {
    if (!state.canSubmit) return false;
    state = state.copyWith(submitting: true, clearError: true);
    final created = await _api.create(state.cart);
    if (created.isFailure) {
      final f = created as Failure;
      state = state.copyWith(submitting: false, error: f.error.toString());
      return false;
    }
    final order = created.getOrThrow();
    final submitted = await _api.submit(order.id);
    if (submitted.isFailure) {
      final f = submitted as Failure;
      state = state.copyWith(
        submitting: false,
        error: 'Created #${order.id} but submit failed: ${f.error}',
        submittedOrderId: order.id,
      );
      return false;
    }
    final done = submitted.getOrThrow();
    await _push.notify(
      title: 'Order submitted',
      body: 'Field order #${done.id} sent to store',
      data: {'field_order_id': '${done.id}'},
    );
    state = state.copyWith(
      submitting: false,
      submittedOrderId: done.id,
      cart: FieldOrderCart(
        siteId: state.cart.siteId,
        siteLabel: state.cart.siteLabel,
        photoUrls: state.cart.photoUrls,
        latitude: state.cart.latitude,
        longitude: state.cart.longitude,
      ),
    );
    return true;
  }
}

final fieldOrderCartProvider =
    StateNotifierProvider.autoDispose<
      FieldOrderCartController,
      FieldOrderCartState
    >(
      (ref) => FieldOrderCartController(
        ref.watch(fieldOrdersApiProvider),
        ref.watch(pushNotifierProvider),
      ),
    );
