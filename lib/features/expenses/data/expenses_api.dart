import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_message.dart';
import '../../../core/result/result.dart';
import '../domain/expense.dart';

class ExpensesApiException implements Exception {
  ExpensesApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ExpensesApi {
  ExpensesApi(this._client);
  final ApiClient _client;

  Future<Result<List<Expense>>> list({
    ExpenseListFilters filters = const ExpenseListFilters(),
    int page = 1,
    int pageSize = 50,
  }) async {
    final query = filters.toQuery(page: page, pageSize: pageSize);
    final qs = query.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return _getList('expenses/?$qs', Expense.fromJson);
  }

  Future<Result<Expense>> get(int id) {
    return _getOne('expenses/$id/', Expense.fromJson);
  }

  Future<Result<Expense>> create(Map<String, dynamic> body) {
    return _sendMap('expenses/', body, Expense.fromJson, 'Could not save expense');
  }

  Future<Result<Expense>> update(int id, Map<String, dynamic> body) {
    return _sendMap(
      'expenses/$id/',
      body,
      Expense.fromJson,
      'Could not update expense',
      put: true,
    );
  }

  Future<Result<void>> delete(int id) async {
    final res = await _client.delete('expenses/$id/');
    return _voidResult(res, 'Could not delete expense');
  }

  Future<Result<Expense>> voidExpense(int id, String reason) {
    return _sendMap(
      'expenses/$id/void/',
      {'reason': reason.trim()},
      Expense.fromJson,
      'Could not void expense',
    );
  }

  Future<Result<Expense>> approve(int id) {
    return _sendMap(
      'expenses/$id/approve/',
      const {},
      Expense.fromJson,
      'Could not approve expense',
    );
  }

  Future<Result<Expense>> reject(int id, String reason) {
    return _sendMap(
      'expenses/$id/reject/',
      {'rejection_reason': reason.trim()},
      Expense.fromJson,
      'Could not return expense',
    );
  }

  Future<Result<Expense>> resubmit(int id) {
    return _sendMap(
      'expenses/$id/resubmit/',
      const {},
      Expense.fromJson,
      'Could not resubmit expense',
    );
  }

  Future<Result<List<ExpenseCategory>>> listCategories({
    bool activeOnly = true,
  }) {
    final q = activeOnly ? '?is_active=true&page_size=100' : '?page_size=100';
    return _getList('expenses/categories/$q', ExpenseCategory.fromJson);
  }

  Future<Result<ExpenseCategory>> createCategory({
    required String name,
    String description = '',
  }) {
    return _sendMap(
      'expenses/categories/',
      {'name': name.trim(), 'description': description.trim(), 'is_active': true},
      ExpenseCategory.fromJson,
      'Could not create category',
    );
  }

  Future<Result<bool>> makerCheckerEnabled() async {
    final res = await _client.get('settings/store-settings/');
    if (res.isFailure) return const Success(false);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return const Success(false);
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Success(decoded['maker_checker_enabled'] == true);
      }
    } on Object {
      // ignore
    }
    return const Success(false);
  }

  Future<Result<List<T>>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final res = await _client.get(path);
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        ExpensesApiException(_errorMessage(response.body, 'Load failed')),
      );
    }
    try {
      final data = jsonDecode(response.body);
      final rows = data is Map ? data['results'] : data;
      if (rows is! List) {
        return Failure(ExpensesApiException('Invalid expenses payload'));
      }
      return Success([
        for (final row in rows)
          if (row is Map) parse(Map<String, dynamic>.from(row)),
      ]);
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<T>> _getOne<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final res = await _client.get(path);
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        ExpensesApiException(_errorMessage(response.body, 'Load failed')),
      );
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return Failure(ExpensesApiException('Invalid expense payload'));
      }
      return Success(parse(Map<String, dynamic>.from(decoded)));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<T>> _sendMap<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) parse,
    String label, {
    bool put = false,
  }) async {
    final res = put
        ? await _client.put(path, body: body)
        : await _client.post(path, body: body);
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(ExpensesApiException(_errorMessage(response.body, label)));
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        return Failure(ExpensesApiException(label));
      }
      return Success(parse(Map<String, dynamic>.from(decoded)));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Result<void> _voidResult(Result response, String label) {
    if (response.isFailure) {
      return Failure((response as Failure).error);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(ExpensesApiException(_errorMessage(res.body, label)));
    }
    return const Success(null);
  }

  static String _errorMessage(String body, String fallback) =>
      apiErrorMessage(body, fallback: fallback);
}
