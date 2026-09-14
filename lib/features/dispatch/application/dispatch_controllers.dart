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
    this.loading = false,
    this.error,
    this.selectedDeliveryAgentId,
    this.acting = false,
  });

  final List<FieldOrderSummary> orders;
  final bool loading;
  final String? error;
  final int? selectedDeliveryAgentId;
  final bool acting;

  bool get canAssign => selectedDeliveryAgentId != null && !acting;

  DispatchQueueState copyWith({
    List<FieldOrderSummary>? orders,
    bool? loading,
    String? error,
    int? selectedDeliveryAgentId,
    bool? acting,
    bool clearError = false,
    bool clearAgent = false,
  }) {
    return DispatchQueueState(
      orders: orders ?? this.orders,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      selectedDeliveryAgentId: clearAgent
          ? null
          : (selectedDeliveryAgentId ?? this.selectedDeliveryAgentId),
      acting: acting ?? this.acting,
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
    final result = await _api.queue();
    result.when(
      success: (orders) =>
          state = state.copyWith(orders: orders, loading: false),
      failure: (e, _) =>
          state = state.copyWith(loading: false, error: e.toString()),
    );
  }

  void selectDeliveryAgent(int? id) {
    state = state.copyWith(
      selectedDeliveryAgentId: id,
      clearAgent: id == null,
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
    final agentId = state.selectedDeliveryAgentId;
    if (agentId == null) {
      state = state.copyWith(error: 'Select a delivery agent');
      return false;
    }
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.assign(orderId: orderId, deliveryAgentId: agentId);
    if (result.isFailure) {
      final f = result as Failure;
      state = state.copyWith(acting: false, error: f.error.toString());
      return false;
    }
    await _push.notify(
      title: 'Assigned',
      body: 'Order #$orderId assigned',
      data: {'field_order_id': '$orderId', 'agent_id': '$agentId'},
    );
    state = state.copyWith(acting: false);
    await load();
    return true;
  }
}

final dispatchQueueProvider =
    StateNotifierProvider.autoDispose<DispatchQueueController, DispatchQueueState>(
  (ref) => DispatchQueueController(
    ref.watch(dispatchApiProvider),
    ref.watch(pushNotifierProvider),
  ),
);
