import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../../sync/domain/client_uuid.dart';
import '../../auth/application/auth_controller.dart';
import '../data/customers_api.dart';
import '../domain/customer.dart';
import 'customer_list_paging.dart';

final customersApiProvider = Provider<CustomersApi>((ref) {
  return CustomersApi(ref.watch(apiClientProvider));
});

final customersSettingsProvider = FutureProvider<CustomersModuleSettings>((
  ref,
) async {
  final result = await ref.watch(customersApiProvider).loadSettings();
  return result.getOrNull() ?? const CustomersModuleSettings();
});

class CustomersListState {
  const CustomersListState({
    this.items = const [],
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.count = 0,
    this.query = '',
    this.error,
  });

  final List<CustomerSummary> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final int count;
  final String query;
  final String? error;

  CustomersListState copyWith({
    List<CustomerSummary>? items,
    bool? loading,
    bool? loadingMore,
    bool? hasMore,
    int? count,
    String? query,
    String? error,
    bool clearError = false,
  }) {
    return CustomersListState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      count: count ?? this.count,
      query: query ?? this.query,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CustomersListController extends StateNotifier<CustomersListState> {
  CustomersListController(this._api) : super(const CustomersListState());

  final CustomersApi _api;
  final _paging = CustomerListPaging();

  void _sync() {
    state = CustomersListState(
      items: _paging.items,
      loading: _paging.loading,
      loadingMore: _paging.loadingMore,
      hasMore: _paging.hasMore,
      count: _paging.count,
      query: _paging.query,
      error: _paging.error,
    );
  }

  Future<void> load({String? search}) {
    return _paging.refresh(_api, search: search, onUpdate: _sync);
  }

  Future<void> loadMore() {
    return _paging.loadMore(_api, onUpdate: _sync);
  }
}

final customersListProvider =
    StateNotifierProvider<CustomersListController, CustomersListState>((ref) {
      return CustomersListController(ref.watch(customersApiProvider));
    });

class CustomerDetailState {
  const CustomerDetailState({
    this.detail,
    this.loading = false,
    this.error,
    this.settling = false,
  });

  final CustomerDetail? detail;
  final bool loading;
  final String? error;
  final bool settling;

  CustomerDetailState copyWith({
    CustomerDetail? detail,
    bool? loading,
    String? error,
    bool? settling,
    bool clearError = false,
  }) {
    return CustomerDetailState(
      detail: detail ?? this.detail,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      settling: settling ?? this.settling,
    );
  }
}

class CustomerDetailController extends StateNotifier<CustomerDetailState> {
  CustomerDetailController(this._api, this._ids)
    : super(const CustomerDetailState());

  final CustomersApi _api;
  final ClientUuid _ids;

  Future<void> load(int id) async {
    state = state.copyWith(loading: true, clearError: true);
    final result = await _api.detail(id);
    result.when(
      success: (detail) =>
          state = state.copyWith(detail: detail, loading: false),
      failure: (e, _) =>
          state = state.copyWith(loading: false, error: e.toString()),
    );
  }

  Future<bool> receivePayment({
    required double amount,
    required String paymentMethod,
    String reference = '',
    String notes = '',
  }) async {
    final detail = state.detail;
    if (detail == null) return false;
    state = state.copyWith(settling: true, clearError: true);
    final result = await _api.receiveWalletPayment(
      customerId: detail.id,
      amount: amount,
      paymentMethod: paymentMethod,
      reference: reference,
      notes: notes,
      idempotencyKey: _ids.next(),
    );
    if (result.isFailure) {
      final f = result as Failure;
      state = state.copyWith(settling: false, error: f.error.toString());
      return false;
    }
    await load(detail.id);
    state = state.copyWith(settling: false);
    return true;
  }
}

final customerDetailProvider = StateNotifierProvider.autoDispose
    .family<CustomerDetailController, CustomerDetailState, int>((ref, id) {
      final controller = CustomerDetailController(
        ref.watch(customersApiProvider),
        ClientUuid(),
      );
      // ignore: discarded_futures
      controller.load(id);
      return controller;
    });

bool canSettleCustomerDebt({
  required AuthState auth,
  required CustomersModuleSettings settings,
  required double debtAmount,
}) {
  final perms = auth.session?.permissions;
  if (perms == null || !perms.canUpdateDebtManagement) return false;
  if (debtAmount <= 0) return false;
  return settings.canSettleDebt(hasUpdatePermission: true);
}
