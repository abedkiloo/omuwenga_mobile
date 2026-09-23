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
    this.showCollections = false,
    this.collectionDate = '',
    this.collections,
    this.collectionsLoading = false,
    this.collectionsError,
  });

  final DebtSummary? summary;
  final List<DebtorRow> debtors;
  final String search;
  final String agingBucket;
  final bool loading;
  final String? error;
  final bool showCollections;
  final String collectionDate;
  final DebtCollections? collections;
  final bool collectionsLoading;
  final String? collectionsError;

  DebtManagementState copyWith({
    DebtSummary? summary,
    List<DebtorRow>? debtors,
    String? search,
    String? agingBucket,
    bool? loading,
    String? error,
    bool clearError = false,
    bool? showCollections,
    String? collectionDate,
    DebtCollections? collections,
    bool? collectionsLoading,
    String? collectionsError,
    bool clearCollectionsError = false,
  }) {
    return DebtManagementState(
      summary: summary ?? this.summary,
      debtors: debtors ?? this.debtors,
      search: search ?? this.search,
      agingBucket: agingBucket ?? this.agingBucket,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      showCollections: showCollections ?? this.showCollections,
      collectionDate: collectionDate ?? this.collectionDate,
      collections: collections ?? this.collections,
      collectionsLoading: collectionsLoading ?? this.collectionsLoading,
      collectionsError: clearCollectionsError
          ? null
          : (collectionsError ?? this.collectionsError),
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
    if (state.showCollections) {
      await loadCollections();
    }
  }

  Future<void> setSearch(String value) async {
    state = state.copyWith(search: value);
    await load(quiet: true);
  }

  Future<void> setAgingBucket(String value) async {
    state = state.copyWith(agingBucket: value);
    await load(quiet: true);
  }

  Future<void> openCollections({String? date}) async {
    final nextDate = (date == null || date.isEmpty)
        ? (state.collectionDate.isEmpty
              ? localDateString()
              : state.collectionDate)
        : date;
    state = state.copyWith(showCollections: true, collectionDate: nextDate);
    await loadCollections();
  }

  void closeCollections() {
    state = state.copyWith(showCollections: false);
  }

  Future<void> shiftCollectionDate(int offsetDays) async {
    final current = state.collectionDate.isEmpty
        ? localDateString()
        : state.collectionDate;
    final next = shiftDateString(current, offsetDays);
    final today = localDateString();
    if (offsetDays > 0 && next.compareTo(today) > 0) return;
    state = state.copyWith(collectionDate: next);
    await loadCollections();
  }

  Future<void> jumpCollectionDateToToday() async {
    state = state.copyWith(collectionDate: localDateString());
    await loadCollections();
  }

  Future<void> loadCollections() async {
    final date = state.collectionDate.isEmpty
        ? localDateString()
        : state.collectionDate;
    if (state.collectionDate.isEmpty) {
      state = state.copyWith(collectionDate: date);
    }
    state = state.copyWith(
      collectionsLoading: true,
      clearCollectionsError: true,
    );
    final result = await _api.listCollections(date: date);
    result.when(
      success: (value) => state = state.copyWith(
        collections: value,
        collectionsLoading: false,
        clearCollectionsError: true,
      ),
      failure: (e, _) => state = state.copyWith(
        collectionsLoading: false,
        collectionsError: e.toString(),
      ),
    );
  }
}

final debtManagementControllerProvider =
    NotifierProvider<DebtManagementController, DebtManagementState>(
      DebtManagementController.new,
    );
