import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../sales_history/domain/payment_status.dart';
import '../data/daily_sales_api.dart';
import '../domain/daily_report.dart';

final dailySalesApiProvider = Provider<DailySalesApi>((ref) {
  return DailySalesApi(ref.watch(apiClientProvider));
});

class DailySalesState {
  DailySalesState({
    DateTime? day,
    this.statusFilter,
    this.search = '',
    this.report,
    this.loading = false,
    this.error,
  }) : day = day ?? DateTime.now();

  final DateTime day;
  final PaymentStatusDisplay? statusFilter;
  final String search;
  final DailySalesReport? report;
  final bool loading;
  final String? error;

  String get dateApi => formatApiDate(day);

  DailySalesState copyWith({
    DateTime? day,
    PaymentStatusDisplay? statusFilter,
    bool clearStatusFilter = false,
    String? search,
    DailySalesReport? report,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearReport = false,
  }) {
    return DailySalesState(
      day: day ?? this.day,
      statusFilter: clearStatusFilter
          ? null
          : (statusFilter ?? this.statusFilter),
      search: search ?? this.search,
      report: clearReport ? null : (report ?? this.report),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DailySalesController extends StateNotifier<DailySalesState> {
  DailySalesController(this._api, {DateTime? initialDay})
    : super(DailySalesState(day: initialDay));

  final DailySalesApi _api;

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    final result = await _api.load(
      date: state.dateApi,
      paymentStatus: state.statusFilter,
      search: state.search,
    );
    result.when(
      success: (report) =>
          state = state.copyWith(report: report, loading: false),
      failure: (e, _) => state = state.copyWith(
        loading: false,
        error: e.toString(),
        clearReport: true,
      ),
    );
  }

  Future<void> goToPreviousDay() async {
    state = state.copyWith(day: previousDay(state.day));
    await load();
  }

  Future<void> goToNextDay() async {
    state = state.copyWith(day: nextDay(state.day));
    await load();
  }

  Future<void> setStatusFilter(PaymentStatusDisplay? status) async {
    state = state.copyWith(
      statusFilter: status,
      clearStatusFilter: status == null,
    );
    await load();
  }

  Future<void> setSearch(String search) async {
    state = state.copyWith(search: search);
    await load();
  }
}

final dailySalesProvider =
    StateNotifierProvider.autoDispose<DailySalesController, DailySalesState>((
      ref,
    ) {
      final controller = DailySalesController(ref.watch(dailySalesApiProvider));
      // ignore: discarded_futures
      controller.load();
      return controller;
    });

class CustomerDayState {
  const CustomerDayState({this.detail, this.loading = false, this.error});

  final CustomerDayDetail? detail;
  final bool loading;
  final String? error;

  CustomerDayState copyWith({
    CustomerDayDetail? detail,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return CustomerDayState(
      detail: detail ?? this.detail,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CustomerDayController extends StateNotifier<CustomerDayState> {
  CustomerDayController(this._api) : super(const CustomerDayState());

  final DailySalesApi _api;

  Future<void> load({required int customerId, required String date}) async {
    state = state.copyWith(loading: true, clearError: true);
    final result = await _api.customerDay(customerId: customerId, date: date);
    result.when(
      success: (detail) =>
          state = state.copyWith(detail: detail, loading: false),
      failure: (e, _) =>
          state = state.copyWith(loading: false, error: e.toString()),
    );
  }
}

final customerDayProvider = StateNotifierProvider.autoDispose
    .family<
      CustomerDayController,
      CustomerDayState,
      ({int customerId, String date})
    >((ref, key) {
      final controller = CustomerDayController(
        ref.watch(dailySalesApiProvider),
      );
      // ignore: discarded_futures
      controller.load(customerId: key.customerId, date: key.date);
      return controller;
    });
