import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/debt_management.dart';

class DebtManagementApi {
  DebtManagementApi(this._client);

  final ApiClient _client;

  Future<Result<DebtSummary>> fetchSummary() async {
    final response = await _client.get('sales/customers/debt-summary/');
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(DebtManagementApiException(_safeError(res.body)));
    }
    try {
      final decoded = jsonDecode(res.body);
      if (decoded is! Map) {
        return Failure(
          DebtManagementApiException('Unexpected response from server.'),
        );
      }
      return Success(
        DebtSummary.fromJson(Map<String, dynamic>.from(decoded)),
      );
    } on Object catch (_, st) {
      return Failure(
        DebtManagementApiException('Could not read debt summary.'),
        st,
      );
    }
  }

  Future<Result<List<DebtorRow>>> listDebtors({
    String search = '',
    String agingBucket = '',
    String ordering = '-debt_amount',
  }) async {
    final params = <String, String>{};
    final q = search.trim();
    if (q.isNotEmpty) params['search'] = q;
    if (agingBucket.trim().isNotEmpty) {
      params['aging_bucket'] = agingBucket.trim();
    }
    if (ordering.trim().isNotEmpty) params['ordering'] = ordering.trim();
    final qs = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    final path = qs.isEmpty
        ? 'sales/customers/debtors/'
        : 'sales/customers/debtors/?$qs';

    final response = await _client.get(path);
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(DebtManagementApiException(_safeError(res.body)));
    }
    try {
      final decoded = jsonDecode(res.body);
      final list = decoded is List
          ? decoded
          : (decoded is Map && decoded['results'] is List)
          ? decoded['results'] as List
          : const [];
      return Success([
        for (final item in list)
          if (item is Map)
            DebtorRow.fromJson(Map<String, dynamic>.from(item)),
      ]);
    } on Object catch (_, st) {
      return Failure(
        DebtManagementApiException('Could not read debtors list.'),
        st,
      );
    }
  }

  static String _safeError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'] ?? decoded['detail'];
        if (err != null) return err.toString();
      }
    } on Object {
      // fall through
    }
    return 'Something went wrong. Please try again.';
  }
}

class DebtManagementApiException implements Exception {
  DebtManagementApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
