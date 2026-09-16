import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/payment_intent.dart';

class PaymentsApiException implements Exception {
  PaymentsApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PaymentsApi {
  PaymentsApi(this._client);
  final ApiClient _client;

  Future<Result<PaymentIntent>> create({
    required double amount,
    required String phone,
    required String purpose,
    int? customerId,
    String customerName = '',
    String? clientUuid,
  }) async {
    final res = await _client.post(
      'payments/intents/',
      body: {
        'amount': amount.toStringAsFixed(2),
        'phone': phone,
        'purpose': purpose,
        'customer_id': ?customerId,
        if (customerName.isNotEmpty) 'customer_name': customerName,
        'client_uuid': ?clientUuid,
      },
    );
    return _parse(res, 'Create failed');
  }

  Future<Result<PaymentIntent>> sendStk(int id) async {
    final res = await _client.post('payments/intents/$id/stk/');
    return _parse(res, 'STK failed');
  }

  Future<Result<PaymentIntent>> get(int id) async {
    final res = await _client.get('payments/intents/$id/');
    return _parse(res, 'Poll failed');
  }

  Future<Result<PaymentIntent>> query(int id) async {
    final res = await _client.post('payments/intents/$id/query/');
    return _parse(res, 'Query failed');
  }

  Future<Result<PaymentIntent>> _parse(
    Result responseResult,
    String label,
  ) async {
    if (responseResult.isFailure) {
      return Failure((responseResult as Failure).error);
    }
    final response = responseResult.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(PaymentsApiException('$label (${response.statusCode})'));
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(PaymentsApiException('Invalid intent payload'));
      }
      return Success(PaymentIntent.fromJson(Map<String, dynamic>.from(data)));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }
}
