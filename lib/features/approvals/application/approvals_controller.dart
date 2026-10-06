import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../../sync/domain/client_uuid.dart';
import '../../auth/application/auth_controller.dart';
import '../../sales_history/domain/sale.dart';
import '../data/approvals_api.dart';

final approvalsApiProvider = Provider<ApprovalsApi>((ref) {
  return ApprovalsApi(ref.watch(apiClientProvider));
});

class ApprovalsState {
  const ApprovalsState({
    this.sales = const [],
    this.collections = const [],
    this.loading = false,
    this.acting = false,
    this.error,
  });

  final List<SaleSummary> sales;
  final List<PendingDebtCollection> collections;
  final bool loading;
  final bool acting;
  final String? error;

  int get totalCount => sales.length + collections.length;

  ApprovalsState copyWith({
    List<SaleSummary>? sales,
    List<PendingDebtCollection>? collections,
    bool? loading,
    bool? acting,
    String? error,
    bool clearError = false,
  }) {
    return ApprovalsState(
      sales: sales ?? this.sales,
      collections: collections ?? this.collections,
      loading: loading ?? this.loading,
      acting: acting ?? this.acting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ApprovalsController extends StateNotifier<ApprovalsState> {
  ApprovalsController(this._ref) : super(const ApprovalsState());

  final Ref _ref;
  final _uuid = ClientUuid();

  ApprovalsApi get _api => _ref.read(approvalsApiProvider);

  bool get canApproveSales {
    final perms = _ref.read(authControllerProvider).session?.permissions;
    return perms?.canApproveSales ?? false;
  }

  bool get canApproveCollections {
    final perms = _ref.read(authControllerProvider).session?.permissions;
    return perms?.canApproveDebtManagement ?? false;
  }

  bool get canOpen => canApproveSales || canApproveCollections;

  Future<void> load() async {
    if (!canOpen) {
      state = const ApprovalsState();
      return;
    }
    state = state.copyWith(loading: true, clearError: true);
    try {
      final salesFuture = canApproveSales
          ? _api.listPendingSales()
          : Future.value(const Success(<SaleSummary>[]));
      final collectionsFuture = canApproveCollections
          ? _api.listPendingCollections()
          : Future.value(const Success(<PendingDebtCollection>[]));
      final salesResult = await salesFuture;
      final collectionsResult = await collectionsFuture;

      String? error;
      var sales = <SaleSummary>[];
      var collections = <PendingDebtCollection>[];
      if (salesResult.isFailure) {
        error = salesResult.when(
          success: (_) => null,
          failure: (e, _) => e.toString(),
        );
      } else {
        sales = salesResult.getOrThrow();
      }
      if (collectionsResult.isFailure) {
        error ??= collectionsResult.when(
          success: (_) => null,
          failure: (e, _) => e.toString(),
        );
      } else {
        collections = collectionsResult.getOrThrow();
      }
      state = ApprovalsState(
        sales: sales,
        collections: collections,
        loading: false,
        error: error,
      );
    } on Object catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<String?> approveSale(int saleId) async {
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.approveSale(
      saleId,
      idempotencyKey: _uuid.next(),
    );
    state = state.copyWith(acting: false);
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    }
    await load();
    return null;
  }

  Future<String?> rejectSale(int saleId, String reason) async {
    if (reason.trim().isEmpty) return 'Please say why you are returning this sale';
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.rejectSale(
      saleId: saleId,
      reason: reason,
      idempotencyKey: _uuid.next(),
    );
    state = state.copyWith(acting: false);
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    }
    await load();
    return null;
  }

  Future<String?> approveCollection(int changeId) async {
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.approveChange(
      changeId,
      idempotencyKey: _uuid.next(),
    );
    state = state.copyWith(acting: false);
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    }
    await load();
    return null;
  }

  Future<String?> rejectCollection(int changeId, String reason) async {
    if (reason.trim().isEmpty) {
      return 'Please say why this collection should not apply';
    }
    state = state.copyWith(acting: true, clearError: true);
    final result = await _api.rejectChange(
      changeId: changeId,
      reason: reason,
      idempotencyKey: _uuid.next(),
    );
    state = state.copyWith(acting: false);
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    }
    await load();
    return null;
  }
}

final approvalsProvider =
    StateNotifierProvider<ApprovalsController, ApprovalsState>((ref) {
      return ApprovalsController(ref);
    });
