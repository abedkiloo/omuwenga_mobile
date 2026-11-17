import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../data/field_loads_api.dart';
import '../domain/field_load.dart';

final fieldLoadsApiProvider = Provider<FieldLoadsApi>((ref) {
  return FieldLoadsApi(ref.watch(apiClientProvider));
});

/// Screen state for the agent's current loads.
class FieldLoadsState {
  const FieldLoadsState({
    this.book,
    this.loading = false,
    this.error,
    this.selectedId,
  });

  final FieldLoadBook? book;
  final bool loading;

  /// Staff-facing sentence. Never a phone number.
  final String? error;

  /// Load currently open on the screen. Null uses the first result.
  final int? selectedId;

  FieldLoad? get selected {
    final loads = book?.loads ?? const <FieldLoad>[];
    if (loads.isEmpty) return null;
    for (final load in loads) {
      if (load.id == selectedId) return load;
    }
    for (final load in loads) {
      if (load.isOpen || load.isPending) return load;
    }
    return loads.first;
  }
}

/// Loads the book and posts sales, returns, and manager decisions.
class FieldLoadsController extends Notifier<FieldLoadsState> {
  @override
  FieldLoadsState build() {
    Future.microtask(load);
    return const FieldLoadsState(loading: true);
  }

  FieldLoadsApi get _api => ref.read(fieldLoadsApiProvider);

  /// Replace the book from the server. Keeps the selected load when it remains.
  Future<void> load() async {
    final current = state.selectedId;
    state = FieldLoadsState(book: state.book, loading: true, selectedId: current);
    final result = await _api.list();
    state = result.when(
      success: (book) => FieldLoadsState(book: book, selectedId: current),
      failure: (error, _) => FieldLoadsState(
        book: state.book,
        error: '$error',
        selectedId: current,
      ),
    );
  }

  void select(int loadId) {
    state = FieldLoadsState(book: state.book, selectedId: loadId);
  }

  /// Record a sale. Returns an error sentence, or null on success.
  ///
  /// [quantity] is 1–100000 and cannot exceed what is still unsold. The
  /// server does not take the units off the shop shelf again.
  Future<String?> sell({
    required int loadId,
    required int productId,
    int? variantId,
    required int quantity,
    int? customerId,
    required String amountPaid,
    String paymentMethod = 'cash',
  }) {
    return _mutate(
      _api.sell(
        loadId,
        fieldLoadSellBody(
          productId: productId,
          variantId: variantId,
          quantity: quantity,
          customerId: customerId,
          amountPaid: amountPaid,
          paymentMethod: paymentMethod,
        ),
      ),
    );
  }

  /// Submit a returned quantity for every line. Does not restock.
  Future<String?> submitReturn({
    required int loadId,
    required List<FieldLoadLine> lines,
    required Map<int, int> returned,
  }) {
    return _mutate(
      _api.submitReturn(loadId, [
        for (final line in lines)
          {'line_id': line.id, 'quantity_returned': returned[line.id] ?? 0},
      ]),
    );
  }

  /// Approve a written load. The server removes shop stock.
  Future<String?> approveIssue(int loadId) => _mutate(_api.approveIssue(loadId));

  /// Send a written load back. The server does not move stock.
  Future<String?> declineIssue(int loadId) => _mutate(_api.declineIssue(loadId));

  Future<String?> accept(int loadId) => _mutate(_api.accept(loadId));

  Future<String?> reject(int loadId) => _mutate(_api.reject(loadId));

  Future<String?> _mutate(Future<Result<FieldLoad>> call) async {
    final result = await call;
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (error, _) => '$error',
      );
    }
    await load();
    return null;
  }
}

final fieldLoadsProvider =
    NotifierProvider<FieldLoadsController, FieldLoadsState>(FieldLoadsController.new);
