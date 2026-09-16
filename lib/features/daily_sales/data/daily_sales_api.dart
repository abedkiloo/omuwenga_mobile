import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../../sales_history/domain/payment_status.dart';
import '../domain/daily_report.dart';

class DailySalesApi {
  DailySalesApi(this._client);

  final ApiClient _client;

  Future<Result<DailySalesReport>> load({
    required String date,
    PaymentStatusDisplay? paymentStatus,
    String search = '',
    int? cashierId,
    int pageSize = 50,
  }) async {
    final params = <String, String>{'date': date, 'page_size': '$pageSize'};
    if (paymentStatus != null) {
      params['payment_status'] = paymentStatus.name;
    }
    if (search.trim().isNotEmpty) {
      params['search'] = search.trim();
    }
    if (cashierId != null) {
      params['cashier_id'] = '$cashierId';
    }
    final query = params.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    final response = await _client.get('sales/daily/?$query');
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(DailySalesApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure(
        DailySalesApiException('Unexpected daily sales response.'),
      );
    }
    return Success(
      DailySalesReport.fromJson(Map<String, dynamic>.from(decoded)),
    );
  }

  Future<Result<CustomerDayDetail>> customerDay({
    required int customerId,
    required String date,
  }) async {
    final response = await _client.get(
      'sales/daily/customer/$customerId/?date=${Uri.encodeQueryComponent(date)}',
    );
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(DailySalesApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure(
        DailySalesApiException('Unexpected customer day response.'),
      );
    }
    return Success(
      CustomerDayDetail.fromJson(Map<String, dynamic>.from(decoded)),
    );
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

class DailySalesApiException implements Exception {
  DailySalesApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
