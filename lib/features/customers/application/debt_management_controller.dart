import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../data/debt_management_api.dart';
import '../domain/debt_management.dart';

final debtManagementApiProvider = Provider<DebtManagementApi>((ref) {
  return DebtManagementApi(ref.watch(apiClientProvider));
});

class DebtManagementState {
  const DebtManagementState({
    this.summary,
    this.debtors = const [],
    this.search = '',
    this.agingBucket = '',
    this.loading = false,
    this.error,
  });

  final DebtSummary? summary;
  final List<DebtorRow> debtors;
  final String search;
  final String agingBucket;
  final bool loading;
  final String? error;

  DebtManagementState copyWith({
    DebtSummary? summary,
    List<DebtorRow>? debtors,
    String? search,
    String? agingBucket,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return DebtManagementState(
      summary: summary ?? this.summary,
      debtors: debtors ?? this.debtors,
      search: search ?? this.search,
      agingBucket: agingBucket ?? this.agingBucket,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DebtManagementController extends Notifier<DebtManagementState> {
  @override
  DebtManagementState build() => const DebtManagementState();

  DebtManagementApi get _api => ref.read(debtManagementApiProvider);

  Future<void> load({bool quiet = false}) async {
    if (!quiet) {
      state = state.copyWith(loading: true, clearError: true);
    }
    final summaryResult = await _api.fetchSummary();
    final debtorsResult = await _api.listDebtors(
      search: state.search,
      agingBucket: state.agingBucket,
    );

    String? error;
    DebtSummary? summary = state.summary;
    var debtors = state.debtors;

    summaryResult.when(
      success: (value) => summary = value,
      failure: (e, _) => error = e.toString(),
    );
    debtorsResult.when(
      success: (value) => debtors = value,
      failure: (e, _) => error ??= e.toString(),
    );

    state = state.copyWith(
      summary: summary,
      debtors: debtors,
      loading: false,
      error: error,
      clearError: error == null,
    );
  }

  Future<void> setSearch(String value) async {
    state = state.copyWith(search: value);
    await load(quiet: true);
  }

  Future<void> setAgingBucket(String value) async {
    state = state.copyWith(agingBucket: value);
    await load(quiet: true);
  }
}

final debtManagementControllerProvider =
    NotifierProvider<DebtManagementController, DebtManagementState>(
      DebtManagementController.new,
    );
