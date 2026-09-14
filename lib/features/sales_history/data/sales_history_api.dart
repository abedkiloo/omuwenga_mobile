import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/sale.dart';

class SalesHistoryApi {
  SalesHistoryApi(this._client);

  final ApiClient _client;

  Future<Result<List<SaleSummary>>> list(SalesHistoryFilters filters) async {
    final params = filters.toQuery();
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}').join('&')}';
    final response = await _client.get('sales/$query');
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(SalesHistoryApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    final list = <dynamic>[];
    if (decoded is List) {
      list.addAll(decoded);
    } else if (decoded is Map && decoded['results'] is List) {
      list.addAll(decoded['results'] as List);
    }
    return Success([
      for (final item in list)
        if (item is Map) SaleSummary.fromJson(Map<String, dynamic>.from(item)),
    ]);
  }

  Future<Result<SaleDetail>> detail(int id) async {
    final response = await _client.get('sales/$id/');
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(SalesHistoryApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure(SalesHistoryApiException('Unexpected sale detail.'));
    }
    return Success(SaleDetail.fromJson(Map<String, dynamic>.from(decoded)));
  }

  Future<Result<void>> refund({
    required int saleId,
    required String reason,
    bool full = true,
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      'sales/$saleId/refund/',
      body: {
        'reason': reason.trim(),
        'full': full,
      },
      idempotencyKey: idempotencyKey,
    );
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode == 202) {
      return const Success(null);
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(SalesHistoryApiException(_safeError(res.body)));
    }
    return const Success(null);
  }

  static String _safeError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'] ?? decoded['detail'] ?? decoded['reason'];
        if (err != null) return err.toString();
      }
    } on Object {
      // fall through
    }
    return 'Something went wrong. Please try again.';
  }
}

class SalesHistoryApiException implements Exception {
  SalesHistoryApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
