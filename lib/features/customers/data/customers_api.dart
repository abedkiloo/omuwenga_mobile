import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/customer.dart';

class ReceiveWalletPaymentResult {
  const ReceiveWalletPaymentResult({
    required this.walletBalance,
    this.transactionId,
  });

  final double walletBalance;
  final int? transactionId;

  factory ReceiveWalletPaymentResult.fromJson(Map<String, dynamic> json) {
    double asDouble(Object? v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    final tx = json['transaction'];
    return ReceiveWalletPaymentResult(
      walletBalance: asDouble(json['wallet_balance']),
      transactionId: tx is Map ? (tx['id'] as num?)?.toInt() : null,
    );
  }
}

class CustomersApi {
  CustomersApi(this._client);

  final ApiClient _client;

  Future<Result<List<CustomerSummary>>> list({String search = ''}) async {
    final q = search.trim().isEmpty
        ? 'sales/customers/'
        : 'sales/customers/?search=${Uri.encodeQueryComponent(search.trim())}';
    final response = await _client.get(q);
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(CustomersApiException(_safeError(res.body)));
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
        if (item is Map) CustomerSummary.fromJson(Map<String, dynamic>.from(item)),
    ]);
  }

  Future<Result<CustomerDetail>> detail(int id) async {
    final response = await _client.get('sales/customers/$id/detail/');
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(CustomersApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure(CustomersApiException('Unexpected customer detail.'));
    }
    return Success(CustomerDetail.fromDetailJson(Map<String, dynamic>.from(decoded)));
  }

  Future<Result<CustomerSummary>> create(CustomerDraft draft) async {
    final response = await _client.post('sales/customers/', body: draft.toJson());
    return _parseCustomerWrite(response);
  }

  Future<Result<CustomerSummary>> update(int id, CustomerDraft draft) async {
    final response = await _client.put('sales/customers/$id/', body: draft.toJson());
    return _parseCustomerWrite(response);
  }

  Future<Result<CustomerSummary>> _parseCustomerWrite(
    Result<http.Response> response,
  ) async {
    if (response.isFailure) {
      final f = response as Failure<http.Response>;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(CustomersApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure(CustomersApiException('Unexpected customer response.'));
    }
    return Success(CustomerSummary.fromJson(Map<String, dynamic>.from(decoded)));
  }

  Future<Result<ReceiveWalletPaymentResult>> receiveWalletPayment({
    required int customerId,
    required double amount,
    required String paymentMethod,
    String reference = '',
    String notes = '',
    required String idempotencyKey,
  }) async {
    final response = await _client.post(
      'sales/customers/$customerId/receive-wallet-payment/',
      body: {
        'amount': amount,
        'payment_method': paymentMethod,
        if (reference.trim().isNotEmpty) 'reference': reference.trim(),
        if (notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
      idempotencyKey: idempotencyKey,
    );
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(CustomersApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure(CustomersApiException('Unexpected payment response.'));
    }
    return Success(
      ReceiveWalletPaymentResult.fromJson(Map<String, dynamic>.from(decoded)),
    );
  }

  Future<Result<CustomersModuleSettings>> loadSettings() async {
    try {
      final response = await _client.get('settings/customers/');
      if (response.isFailure) {
        return const Success(CustomersModuleSettings());
      }
      final res = response.getOrThrow();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return const Success(CustomersModuleSettings());
      }
      final decoded = jsonDecode(res.body);
      if (decoded is Map) {
        return Success(
          CustomersModuleSettings.fromJson(Map<String, dynamic>.from(decoded)),
        );
      }
      return const Success(CustomersModuleSettings());
    } on Object {
      return const Success(CustomersModuleSettings());
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

class CustomersApiException implements Exception {
  CustomersApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
