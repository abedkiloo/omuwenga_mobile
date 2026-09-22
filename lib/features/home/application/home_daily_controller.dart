import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_session.dart';
import '../../auth/domain/persona.dart';
import '../../daily_sales/data/daily_sales_api.dart';
import '../../daily_sales/domain/daily_report.dart';
import '../../sales_history/data/sales_history_api.dart';
import '../../sales_history/domain/payment_status.dart';
import '../../sales_history/domain/sale.dart';

class HomeDailySummary {
  const HomeDailySummary({
    required this.dateLabel,
    required this.scopeAll,
    required this.summary,
    required this.orders,
  });

  final String dateLabel;
  final bool scopeAll;
  final DailySummary summary;
  final List<DailyOrder> orders;
}

class HomeDailyState {
  const HomeDailyState({this.summary, this.loading = false, this.error});

  final HomeDailySummary? summary;
  final bool loading;
  final String? error;

  HomeDailyState copyWith({
    HomeDailySummary? summary,
    bool? loading,
    String? error,
    bool clearError = false,
    bool clearSummary = false,
  }) {
    return HomeDailyState(
      summary: clearSummary ? null : (summary ?? this.summary),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Store-wide today totals: admin / superuser, or roles with sales.view_all.
bool homeShowsAllSales(AuthSession session) {
  if (session.user.isSuperuser || session.profile.isSuperAdmin) {
    return true;
  }
  if (session.persona == AppPersona.admin) {
    return true;
  }
  // Explicit grant from Roles UI (sales.view_all).
  if (session.permissions.canViewAllSales) {
    return true;
  }
  final role = session.profile.role;
  if (role == 'admin' || role == 'super_admin') {
    return true;
  }
  final display = (session.profile.roleDisplay ?? '').trim();
  if (display == 'Super Admin' ||
      display == 'Admin' ||
      display == 'Administrator') {
    return true;
  }
  return false;
}

class HomeDailyController extends StateNotifier<HomeDailyState> {
  HomeDailyController({
    required DailySalesApi dailyApi,
    required SalesHistoryApi salesApi,
    required AuthSession? session,
  }) : _dailyApi = dailyApi,
       _salesApi = salesApi,
       _session = session,
       super(const HomeDailyState());

  final DailySalesApi _dailyApi;
  final SalesHistoryApi _salesApi;
  final AuthSession? _session;

  Future<void> load() async {
    final session = _session;
    if (session == null) {
      state = const HomeDailyState();
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    final day = DateTime.now();
    final date = formatApiDate(day);
    final showAll = homeShowsAllSales(session);
    final cashierId = showAll ? null : session.user.id;

    if (session.permissions.canViewDailySales) {
      final result = await _dailyApi.load(date: date, cashierId: cashierId);
      if (result.isSuccess) {
        final report = result.getOrThrow();
        state = state.copyWith(
          loading: false,
          summary: HomeDailySummary(
            dateLabel: date,
            scopeAll: showAll,
            summary: report.summary,
            orders: report.orders.take(8).toList(),
          ),
        );
        return;
      }
      final err = (result as Failure).error.toString();
      await _loadFromSalesHistory(
        date: date,
        showAll: showAll,
        session: session,
        fallbackError: err,
      );
      return;
    }

    await _loadFromSalesHistory(date: date, showAll: showAll, session: session);
  }

  Future<void> _loadFromSalesHistory({
    required String date,
    required bool showAll,
    required AuthSession session,
    String? fallbackError,
  }) async {
    final result = await _salesApi.list(
      SalesHistoryFilters(dateFrom: date, dateTo: date),
    );
    result.when(
      success: (list) {
        var orders = [
          for (final s in list)
            DailyOrder(
              id: s.id,
              saleNumber: s.saleNumber,
              total: s.total,
              amountPaid: s.amountPaid,
              paymentStatus: s.paymentStatus,
              customerName: s.customerName,
              paymentMethod: s.paymentMethod,
              occurredAt: s.occurredAt,
              debtAmount: s.debtAmount,
              clientChannel: s.clientChannel,
            ),
        ];
        // List is server-scoped for non-admin users (own cashier/served_by only).
        state = state.copyWith(
          loading: false,
          summary: HomeDailySummary(
            dateLabel: date,
            scopeAll: showAll,
            summary: _summaryFromOrders(orders),
            orders: orders.take(8).toList(),
          ),
        );
      },
      failure: (e, _) => state = state.copyWith(
        loading: false,
        error: fallbackError ?? e.toString(),
        clearSummary: true,
      ),
    );
  }
}

DailySummary _summaryFromOrders(List<DailyOrder> orders) {
  var totalSales = 0.0;
  var totalPaid = 0.0;
  var totalDebt = 0.0;
  var paidCount = 0;
  var debtCount = 0;
  var partialCount = 0;
  for (final o in orders) {
    totalSales += o.total;
    totalPaid += o.amountPaid;
    totalDebt += o.debtAmount;
    switch (o.paymentStatus) {
      case PaymentStatusDisplay.paid:
        paidCount++;
      case PaymentStatusDisplay.debt:
        debtCount++;
      case PaymentStatusDisplay.partial:
        partialCount++;
        debtCount++;
    }
  }
  return DailySummary(
    totalSales: totalSales,
    ordersCount: orders.length,
    totalPaid: totalPaid,
    paidOrdersCount: paidCount,
    totalDebtIncurred: totalDebt,
    debtOrdersCount: debtCount,
    partialOrdersCount: partialCount,
    totalDebtCollected: 0,
    totalCollected: totalPaid,
  );
}

final homeDailyProvider =
    StateNotifierProvider.autoDispose<HomeDailyController, HomeDailyState>((
      ref,
    ) {
      final session = ref.watch(authControllerProvider).session;
      final controller = HomeDailyController(
        dailyApi: DailySalesApi(ref.watch(apiClientProvider)),
        salesApi: SalesHistoryApi(ref.watch(apiClientProvider)),
        session: session,
      );
      // ignore: discarded_futures
      controller.load();
      return controller;
    });
