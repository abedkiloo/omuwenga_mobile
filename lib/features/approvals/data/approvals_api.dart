import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../expenses/domain/expense.dart';
import '../../sales_history/domain/sale.dart';
import '../domain/approval_details.dart';

class PendingDebtCollection {
  const PendingDebtCollection({
    required this.id,
    required this.customerName,
    required this.amount,
    this.paymentMethod,
    this.madeByName,
    this.createdAt,
    this.reason,
    this.details = const ApprovalDetails(),
  });

  final int id;
  final String customerName;
  final double amount;
  final String? paymentMethod;
  final String? madeByName;
  final String? createdAt;
  final String? reason;
  final ApprovalDetails details;

  factory PendingDebtCollection.fromJson(Map<String, dynamic> json) {
    final apply = json['apply_payload'];
    final proposed = json['proposed_values'];
    final applyMap = apply is Map ? Map<String, dynamic>.from(apply) : const {};
    final proposedMap =
        proposed is Map ? Map<String, dynamic>.from(proposed) : const {};
    final amountRaw =
        applyMap['amount'] ?? proposedMap['amount'] ?? json['amount'];
    final method =
        (applyMap['payment_method'] ?? proposedMap['payment_method'] ?? 'cash')
            ?.toString();
    final customer =
        json['entity_repr'] ??
        json['entity_label'] ??
        json['customer_name'] ??
        applyMap['customer_name'] ??
        'Customer';
    final madeBy =
        json['made_by_username'] ?? json['made_by_name'] ?? json['made_by'];
    return PendingDebtCollection(
      id: int.tryParse('${json['id']}') ?? 0,
      customerName: customer.toString(),
      amount: double.tryParse('$amountRaw') ?? 0,
      paymentMethod: method,
      madeByName: madeBy?.toString(),
      createdAt:
          json['made_at']?.toString() ?? json['created_at']?.toString(),
      reason: json['reason']?.toString(),
      details: ApprovalDetails.fromJson(json['details']),
    );
  }
}

class ApprovalsApi {
  ApprovalsApi(this._client);

  final ApiClient _client;

  Future<Result<SaleDetail>> saleDetail(int saleId) async {
    final response = await _client.get('sales/$saleId/');
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(ApprovalsApiException(_safeError(res.body)));
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return Failure(ApprovalsApiException('Could not read sale detail.'));
      }
      return Success(SaleDetail.fromJson(Map<String, dynamic>.from(decoded)));
    } on Object catch (_, st) {
      return Failure(
        ApprovalsApiException('Could not read sale detail.'),
        st,
      );
    }
  }

  Future<Result<List<SaleSummary>>> listPendingSales() async {
    final response = await _client.get(
      'sales/?status=pending_approval&page_size=100',
    );
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(ApprovalsApiException(_safeError(res.body)));
    }
    try {
      return Success([
        for (final item in _asList(res.body))
          if (item is Map)
            SaleSummary.fromJson(Map<String, dynamic>.from(item)),
      ]);
    } on Object catch (_, st) {
      return Failure(
        ApprovalsApiException('Could not read pending sales.'),
        st,
      );
    }
  }

  Future<Result<List<Expense>>> listPendingExpenses() async {
    final response = await _client.get(
      'expenses/?status=pending&show_all=true&page_size=100',
    );
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(ApprovalsApiException(_safeError(res.body)));
    }
    try {
      return Success([
        for (final item in _asList(res.body))
          if (item is Map) Expense.fromJson(Map<String, dynamic>.from(item)),
      ]);
    } on Object catch (_, st) {
      return Failure(
        ApprovalsApiException('Could not read pending expenses.'),
        st,
      );
    }
  }

  Future<Result<Expense>> approveExpense(int expenseId) async {
    final response = await _client.post(
      'expenses/$expenseId/approve/',
      body: const {},
    );
    return _parseExpense(response);
  }

  Future<Result<Expense>> rejectExpense({
    required int expenseId,
    required String reason,
  }) async {
    final response = await _client.post(
      'expenses/$expenseId/reject/',
      body: {'rejection_reason': reason.trim()},
    );
    return _parseExpense(response);
  }

  Result<Expense> _parseExpense(Result response) {
    if (response.isFailure) {
      final f = response as Failure;
      return Failure<Expense>(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure<Expense>(ApprovalsApiException(_safeError(res.body)));
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return Failure<Expense>(ApprovalsApiException('Could not read expense.'));
      }
      return Success(Expense.fromJson(Map<String, dynamic>.from(decoded)));
    } on Object catch (_, st) {
      return Failure<Expense>(
        ApprovalsApiException('Could not read expense.'),
        st,
      );
    }
  }

  Future<Result<List<PendingDebtCollection>>> listPendingCollections() async {
    final response = await _client.get(
      'approvals/pending-changes/pending/?action_type=debt_collection',
    );
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(ApprovalsApiException(_safeError(res.body)));
    }
    try {
      return Success([
        for (final item in _asList(res.body))
          if (item is Map)
            PendingDebtCollection.fromJson(Map<String, dynamic>.from(item)),
      ]);
    } on Object catch (_, st) {
      return Failure(
        ApprovalsApiException('Could not read pending collections.'),
        st,
      );
    }
  }

  Future<Result<void>> approveSale(
    int saleId, {
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      'sales/$saleId/complete/',
      body: const {},
      idempotencyKey: idempotencyKey,
    );
    return _voidResult(response);
  }

  Future<Result<void>> rejectSale({
    required int saleId,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      'sales/$saleId/reject-complete/',
      body: {'rejection_reason': reason.trim()},
      idempotencyKey: idempotencyKey,
    );
    return _voidResult(response);
  }

  Future<Result<void>> approveChange(
    int changeId, {
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      'approvals/pending-changes/$changeId/approve/',
      body: const {},
      idempotencyKey: idempotencyKey,
    );
    return _voidResult(response);
  }

  Future<Result<void>> rejectChange({
    required int changeId,
    required String reason,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      'approvals/pending-changes/$changeId/reject/',
      body: {'rejection_reason': reason.trim()},
      idempotencyKey: idempotencyKey,
    );
    return _voidResult(response);
  }

  Result<void> _voidResult(Result response) {
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(ApprovalsApiException(_safeError(res.body)));
    }
    return const Success(null);
  }

  List<dynamic> _asList(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) return decoded;
    if (decoded is Map && decoded['results'] is List) {
      return decoded['results'] as List;
    }
    return const [];
  }

  static String _safeError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err =
            decoded['error'] ??
            decoded['detail'] ??
            decoded['rejection_reason'];
        if (err != null) return err.toString();
      }
    } on Object {
      // fall through
    }
    return 'Something went wrong. Please try again.';
  }
}

class ApprovalsApiException implements Exception {
  ApprovalsApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
