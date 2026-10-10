import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/result/result.dart';
import '../../auth/domain/auth_session.dart';
import '../data/expenses_api.dart';
import '../domain/expense.dart';

final expensesApiProvider = Provider<ExpensesApi>((ref) {
  return ExpensesApi(ref.watch(apiClientProvider));
});

bool sessionCanApproveExpenses(AuthSession? session) {
  if (session == null) return false;
  if (session.user.isSuperuser) return true;
  final profile = session.profile;
  return profile.isAdmin ||
      profile.isSuperAdmin ||
      profile.role == 'admin' ||
      profile.role == 'super_admin';
}

class ExpensesState {
  const ExpensesState({
    this.items = const [],
    this.categories = const [],
    this.filters = const ExpenseListFilters(),
    this.loading = false,
    this.saving = false,
    this.makerCheckerEnabled = false,
    this.error,
  });

  final List<Expense> items;
  final List<ExpenseCategory> categories;
  final ExpenseListFilters filters;
  final bool loading;
  final bool saving;
  final bool makerCheckerEnabled;
  final String? error;

  ExpensesState copyWith({
    List<Expense>? items,
    List<ExpenseCategory>? categories,
    ExpenseListFilters? filters,
    bool? loading,
    bool? saving,
    bool? makerCheckerEnabled,
    String? error,
    bool clearError = false,
  }) {
    return ExpensesState(
      items: items ?? this.items,
      categories: categories ?? this.categories,
      filters: filters ?? this.filters,
      loading: loading ?? this.loading,
      saving: saving ?? this.saving,
      makerCheckerEnabled: makerCheckerEnabled ?? this.makerCheckerEnabled,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ExpensesController extends StateNotifier<ExpensesState> {
  ExpensesController(this._ref) : super(const ExpensesState());

  final Ref _ref;
  ExpensesApi get _api => _ref.read(expensesApiProvider);

  Future<void> load({ExpenseListFilters? filters}) async {
    state = state.copyWith(
      loading: true,
      clearError: true,
      filters: filters ?? state.filters,
    );
    final listResult = await _api.list(filters: state.filters);
    final catsResult = await _api.listCategories();
    final mcResult = await _api.makerCheckerEnabled();

    String? error;
    var items = <Expense>[];
    var categories = <ExpenseCategory>[];
    if (listResult.isFailure) {
      error = listResult.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    } else {
      items = listResult.getOrThrow();
    }
    if (catsResult.isSuccess) {
      categories = catsResult.getOrThrow();
    }
    final makerChecker = mcResult.isSuccess ? mcResult.getOrThrow() : false;

    state = state.copyWith(
      items: items,
      categories: categories,
      makerCheckerEnabled: makerChecker,
      loading: false,
      error: error,
    );
  }

  Future<String?> save({
    required Expense draft,
    int? existingId,
    String? proposalReason,
  }) async {
    if (draft.description.trim().isEmpty) {
      return 'Enter a description, e.g. Shop rent for September';
    }
    if (draft.categoryId == null || draft.categoryId == 0) {
      return 'Choose a category';
    }
    if (draft.amount <= 0) return 'Enter a valid amount';
    if (draft.expenseDate.trim().isEmpty) return 'Choose the expense date';
    if (state.makerCheckerEnabled &&
        (proposalReason == null || proposalReason.trim().isEmpty)) {
      return 'A reason is required when maker-checker is enabled.';
    }

    state = state.copyWith(saving: true, clearError: true);
    final body = draft.toWriteBody(proposalReason: proposalReason);
    final result = existingId == null
        ? await _api.create(body)
        : await _api.update(existingId, body);
    state = state.copyWith(saving: false);
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    }
    await load();
    return null;
  }

  Future<String?> createCategory(String name, {String description = ''}) async {
    if (name.trim().isEmpty) return 'Enter a category name';
    final result = await _api.createCategory(
      name: name,
      description: description,
    );
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    }
    final created = result.getOrThrow();
    final next = [...state.categories];
    final idx = next.indexWhere((c) => c.id == created.id);
    if (idx >= 0) {
      next[idx] = created;
    } else {
      next.add(created);
    }
    next.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    state = state.copyWith(categories: next);
    return null;
  }

  Future<String?> deleteOrVoid(Expense expense, {String reason = ''}) async {
    state = state.copyWith(saving: true, clearError: true);
    final Result result;
    if (expense.isPosted) {
      if (reason.trim().isEmpty) {
        state = state.copyWith(saving: false);
        return 'Say why you are voiding this expense';
      }
      result = await _api.voidExpense(expense.id, reason);
    } else {
      result = await _api.delete(expense.id);
    }
    state = state.copyWith(saving: false);
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    }
    await load();
    return null;
  }

  Future<String?> approve(int id) async {
    state = state.copyWith(saving: true, clearError: true);
    final result = await _api.approve(id);
    state = state.copyWith(saving: false);
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    }
    await load();
    return null;
  }

  Future<String?> reject(int id, String reason) async {
    if (reason.trim().isEmpty) {
      return 'Please say why you are returning this expense';
    }
    state = state.copyWith(saving: true, clearError: true);
    final result = await _api.reject(id, reason);
    state = state.copyWith(saving: false);
    if (result.isFailure) {
      return result.when(
        success: (_) => null,
        failure: (e, _) => e.toString(),
      );
    }
    await load();
    return null;
  }

  Future<String?> resubmit(int id) async {
    state = state.copyWith(saving: true, clearError: true);
    final result = await _api.resubmit(id);
    state = state.copyWith(saving: false);
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

final expensesProvider =
    StateNotifierProvider<ExpensesController, ExpensesState>((ref) {
      return ExpensesController(ref);
    });
