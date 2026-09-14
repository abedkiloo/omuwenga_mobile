import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agents/domain/site_visit.dart';
import '../../customers/domain/customer.dart';
import '../../pos/domain/cart.dart';
import '../../pos/domain/product_variant.dart';
import '../data/field_orders_api.dart';
import 'field_order_controllers.dart';

enum VisitOrderStep { customer, products, location, review }

class VisitOrderState {
  const VisitOrderState({
    this.step = VisitOrderStep.customer,
    this.customer,
    this.lines = const [],
    this.pin,
    this.landmark = '',
    this.notes = '',
    this.submitting = false,
    this.error,
    this.placedOrderId,
  });

  final VisitOrderStep step;
  final CustomerSummary? customer;
  final List<CartLine> lines;
  final SitePin? pin;
  final String landmark;
  final String notes;
  final bool submitting;
  final String? error;
  final int? placedOrderId;

  bool get hasCustomer => customer != null;
  bool get hasProducts => lines.isNotEmpty;
  bool get hasPin => pin != null;
  bool get canPlace =>
      hasCustomer && hasProducts && hasPin && !submitting && placedOrderId == null;

  double get subtotal =>
      lines.fold(0, (sum, line) => sum + line.lineTotal);

  VisitOrderState copyWith({
    VisitOrderStep? step,
    CustomerSummary? customer,
    List<CartLine>? lines,
    SitePin? pin,
    String? landmark,
    String? notes,
    bool? submitting,
    String? error,
    int? placedOrderId,
    bool clearCustomer = false,
    bool clearPin = false,
    bool clearError = false,
    bool clearPlaced = false,
  }) {
    return VisitOrderState(
      step: step ?? this.step,
      customer: clearCustomer ? null : (customer ?? this.customer),
      lines: lines ?? this.lines,
      pin: clearPin ? null : (pin ?? this.pin),
      landmark: landmark ?? this.landmark,
      notes: notes ?? this.notes,
      submitting: submitting ?? this.submitting,
      error: clearError ? null : (error ?? this.error),
      placedOrderId: clearPlaced ? null : (placedOrderId ?? this.placedOrderId),
    );
  }
}

class VisitOrderController extends StateNotifier<VisitOrderState> {
  VisitOrderController(this._api) : super(const VisitOrderState());

  final FieldOrdersApi _api;

  void goTo(VisitOrderStep step) {
    state = state.copyWith(step: step, clearError: true);
  }

  void selectCustomer(CustomerSummary customer) {
    state = state.copyWith(
      customer: customer,
      step: VisitOrderStep.products,
      clearError: true,
    );
  }

  void clearCustomer() {
    state = state.copyWith(clearCustomer: true, step: VisitOrderStep.customer);
  }

  void addProduct(CatalogProduct product, {ProductVariant? variant, double qty = 1}) {
    final variantId = variant?.id;
    final lineKey =
        variantId == null ? '${product.id}' : '${product.id}-$variantId';
    final existing = state.lines.indexWhere((l) => l.lineKey == lineKey);
    final next = [...state.lines];
    if (existing >= 0) {
      next[existing] = next[existing].copyWith(
        quantity: next[existing].quantity + qty,
      );
    } else {
      next.add(
        CartLine(
          productId: product.id,
          name: product.name,
          unitPrice: variant?.effectivePrice ?? product.price,
          quantity: qty,
          sku: variant?.sku ?? product.sku,
          stockQuantity: variant?.stockQuantity ?? product.stockQuantity,
          variantId: variantId,
          variantLabel: variant?.displayLabel,
        ),
      );
    }
    state = state.copyWith(lines: next, clearError: true);
  }

  void setQuantity(String lineKey, double quantity) {
    if (quantity <= 0) {
      state = state.copyWith(
        lines: state.lines.where((l) => l.lineKey != lineKey).toList(),
      );
      return;
    }
    state = state.copyWith(
      lines: [
        for (final l in state.lines)
          if (l.lineKey == lineKey) l.copyWith(quantity: quantity) else l,
      ],
    );
  }

  void removeLine(String lineKey) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.lineKey != lineKey).toList(),
    );
  }

  void setPin(SitePin pin) {
    state = state.copyWith(pin: pin, clearError: true);
  }

  void setLandmark(String value) {
    state = state.copyWith(landmark: value);
  }

  void setNotes(String value) {
    state = state.copyWith(notes: value);
  }

  Future<bool> placeOrder() async {
    final customer = state.customer;
    final pin = state.pin;
    if (customer == null || pin == null || state.lines.isEmpty) {
      state = state.copyWith(
        error: 'Customer, products, and location are required.',
      );
      return false;
    }
    state = state.copyWith(submitting: true, clearError: true);
    final lines = [
      for (final line in state.lines)
        {
          'product_id': line.productId,
          'quantity': line.quantity.toString(),
          'unit_price': line.unitPrice.toStringAsFixed(2),
          if (line.variantId != null) 'variant_id': line.variantId,
        },
    ];
    final result = await _api.place(
      customerId: customer.id,
      latitude: pin.latitude,
      longitude: pin.longitude,
      accuracy: pin.accuracy,
      landmark: state.landmark,
      label: pin.label.isNotEmpty ? pin.label : '${customer.name} delivery',
      notes: state.notes,
      lines: lines,
    );
    return result.when(
      success: (order) {
        state = state.copyWith(
          submitting: false,
          placedOrderId: order.id,
          lines: const [],
        );
        return true;
      },
      failure: (e, _) {
        state = state.copyWith(submitting: false, error: e.toString());
        return false;
      },
    );
  }

  void reset() {
    state = const VisitOrderState();
  }
}

final visitOrderProvider =
    StateNotifierProvider.autoDispose<VisitOrderController, VisitOrderState>(
  (ref) => VisitOrderController(ref.watch(fieldOrdersApiProvider)),
);
