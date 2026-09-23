import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/notifications/push_notifier.dart';
import '../../../core/result/result.dart';
import '../../field_orders/application/field_order_controllers.dart';
import '../../field_orders/domain/field_order.dart';
import '../data/dispatch_api.dart';

final dispatchApiProvider = Provider<DispatchApi>((ref) {
  return DispatchApi(ref.watch(apiClientProvider));
});

class DispatchQueueState {
  const DispatchQueueState({
    this.orders = const [],
    this.drivers = const [],
    this.loading = false,
    this.error,
    this.selectedDeliveryDriverId,
    this.acting = false,
    this.creatingDriver = false,
    this.lastCreatedTempPassword,
  });

  final List<FieldOrderSummary> orders;
  final List<DeliveryDriverOption> drivers;
  final bool loading;
  final String? error;
  final int? selectedDeliveryDriverId;
  final bool acting;
  final bool creatingDriver;
  final String? lastCreatedTempPassword;

  bool get canAssign => selectedDeliveryDriverId != null && !acting;

  DispatchQueueState copyWith({
    List<FieldOrderSummary>? orders,
    List<DeliveryDriverOption>? drivers,
    bool? loading,
    String? error,
    int? selectedDeliveryDriverId,
    bool? acting,
    bool? creatingDriver,
    String? lastCreatedTempPassword,
    bool clearError = false,
    bool clearDriver = false,
    bool clearTempPassword = false,
  }) {
    return DispatchQueueState(
      orders: orders ?? this.orders,
      drivers: drivers ?? this.drivers,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      selectedDeliveryDriverId: clearDriver
          ? null
          : (selectedDeliveryDriverId ?? this.selectedDeliveryDriverId),
      acting: acting ?? this.acting,
      creatingDriver: creatingDriver ?? this.creatingDriver,
      lastCreatedTempPassword: clearTempPassword
          ? null
          : (lastCreatedTempPassword ?? this.lastCreatedTempPassword),
    );
  }
}

class DispatchQueueController extends StateNotifier<DispatchQueueState> {
  DispatchQueueController(this._api, this._push)
    : super(const DispatchQueueState());

  final DispatchApi _api;
  final PushNotifier _push;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    final queueResult = await _api.queue();
    final driversResult = await _api.drivers();

    if (queueResult.isFailure) {
      final f = queueResult as Failure;
      state = state.copyWith(loading: false, error: f.error.toString());
      return;
    }

    final drivers = driversResult.isSuccess
        ? driversResult.getOrThrow()
        : const <DeliveryDriverOption>[];
    final selected = state.selectedDeliveryDriverId;
    final stillValid =
        selected != null && drivers.any((d) => d.id == selected);

    state = state.copyWith(
      orders: queueResult.getOrThrow(),
      drivers: drivers,
      loading: false,
      clearDriver: selected != null && !stillValid,
      error: driversResult.isFailure
          ? 'Could not load drivers — ${ (driversResult as Failure).error}'
          : null,
      clearError: driversResult.isSuccess,
    );
  }

  void selectDeliveryDriver(int? id) {
    state = state.copyWith(
      selectedDeliveryDriverId: id,
      clearDriver: id == null,
      clearError: true,
    );
  }

  Future<bool> pack(int orderId) async {
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.pack(orderId);
    if (result.isFailure) {
      final f = result as Failure;
      state = state.copyWith(acting: false, error: f.error.toString());
      return false;
    }
    await _push.notify(
      title: 'Packed',
      body: 'Order #$orderId ready',
      data: {'field_order_id': '$orderId'},
    );
    state = state.copyWith(acting: false);
    await load();
    return true;
  }

  Future<bool> assign(int orderId) async {
    final driverId = state.selectedDeliveryDriverId;
    if (driverId == null) {
      state = state.copyWith(error: 'Select a delivery driver');
      return false;
    }
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.assign(
      orderId: orderId,
      deliveryDriverId: driverId,
    );
    if (result.isFailure) {
      final f = result as Failure;
      state = state.copyWith(acting: false, error: f.error.toString());
      return false;
    }
    await _push.notify(
      title: 'Assigned',
      body: 'Order #$orderId assigned',
      data: {'field_order_id': '$orderId', 'driver_id': '$driverId'},
    );
    state = state.copyWith(acting: false);
    await load();
    return true;
  }

  Future<CreatedDeliveryDriver?> createDriver({
    required String displayName,
    required String phone,
  }) async {
    if (displayName.trim().isEmpty) {
      state = state.copyWith(error: "Enter the driver's name");
      return null;
    }
    if (phone.trim().isEmpty) {
      state = state.copyWith(error: 'Enter a phone number');
      return null;
    }
    state = state.copyWith(creatingDriver: true, clearError: true);
    final result = await _api.createDriver(
      displayName: displayName,
      phone: phone,
    );
    if (result.isFailure) {
      final f = result as Failure;
      state = state.copyWith(
        creatingDriver: false,
        error: f.error.toString(),
      );
      return null;
    }
    final driver = result.getOrThrow();
    state = state.copyWith(
      creatingDriver: false,
      drivers: [...state.drivers, driver],
      selectedDeliveryDriverId: driver.id,
      lastCreatedTempPassword: driver.temporaryPassword,
    );
    return driver;
  }
}

final dispatchQueueProvider =
    StateNotifierProvider.autoDispose<
      DispatchQueueController,
      DispatchQueueState
    >(
      (ref) => DispatchQueueController(
        ref.watch(dispatchApiProvider),
        ref.watch(pushNotifierProvider),
      ),
    );
