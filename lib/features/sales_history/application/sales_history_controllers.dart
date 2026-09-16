import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../../sync/domain/client_uuid.dart';
import '../data/sales_history_api.dart';
import '../domain/sale.dart';

final salesHistoryApiProvider = Provider<SalesHistoryApi>((ref) {
  return SalesHistoryApi(ref.watch(apiClientProvider));
});

class SalesHistoryState {
  const SalesHistoryState({
    this.items = const [],
    this.loading = false,
    this.filters = const SalesHistoryFilters(),
    this.error,
  });

  final List<SaleSummary> items;
  final bool loading;
  final SalesHistoryFilters filters;
  final String? error;

  SalesHistoryState copyWith({
    List<SaleSummary>? items,
    bool? loading,
    SalesHistoryFilters? filters,
    String? error,
    bool clearError = false,
  }) {
    return SalesHistoryState(
      items: items ?? this.items,
      loading: loading ?? this.loading,
      filters: filters ?? this.filters,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SalesHistoryController extends StateNotifier<SalesHistoryState> {
  SalesHistoryController(this._api) : super(const SalesHistoryState());

  final SalesHistoryApi _api;

  Future<void> load({SalesHistoryFilters? filters}) async {
    final next = filters ?? state.filters;
    state = state.copyWith(loading: true, filters: next, clearError: true);
    final result = await _api.list(next);
    result.when(
      success: (items) => state = state.copyWith(items: items, loading: false),
      failure: (e, _) => state = state.copyWith(
        loading: false,
        error: e.toString(),
        items: const [],
      ),
    );
  }
}

final salesHistoryProvider =
    StateNotifierProvider<SalesHistoryController, SalesHistoryState>((ref) {
      return SalesHistoryController(ref.watch(salesHistoryApiProvider));
    });

class SaleDetailState {
  const SaleDetailState({
    this.detail,
    this.loading = false,
    this.error,
    this.refunding = false,
  });

  final SaleDetail? detail;
  final bool loading;
  final String? error;
  final bool refunding;

  SaleDetailState copyWith({
    SaleDetail? detail,
    bool? loading,
    String? error,
    bool? refunding,
    bool clearError = false,
  }) {
    return SaleDetailState(
      detail: detail ?? this.detail,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      refunding: refunding ?? this.refunding,
    );
  }
}

class SaleDetailController extends StateNotifier<SaleDetailState> {
  SaleDetailController(this._api, this._ids) : super(const SaleDetailState());

  final SalesHistoryApi _api;
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

  Future<bool> refund({required String reason, bool full = true}) async {
    final detail = state.detail;
    if (detail == null) return false;
    state = state.copyWith(refunding: true, clearError: true);
    final result = await _api.refund(
      saleId: detail.id,
      reason: reason,
      full: full,
      idempotencyKey: _ids.next(),
    );
    if (result.isFailure) {
      final f = result as Failure;
      state = state.copyWith(refunding: false, error: f.error.toString());
      return false;
    }
    await load(detail.id);
    state = state.copyWith(refunding: false);
    return true;
  }
}

final saleDetailProvider = StateNotifierProvider.autoDispose
    .family<SaleDetailController, SaleDetailState, int>((ref, id) {
      final controller = SaleDetailController(
        ref.watch(salesHistoryApiProvider),
        ClientUuid(),
      );
      // ignore: discarded_futures
      controller.load(id);
      return controller;
    });
