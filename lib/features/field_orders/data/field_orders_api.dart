import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/field_order.dart';

class FieldOrdersApiException implements Exception {
  FieldOrdersApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class FieldOrdersApi {
  FieldOrdersApi(this._client);
  final ApiClient _client;

  Future<Result<FieldOrderSummary>> create(FieldOrderCart cart) async {
    final res = await _client.post(
      'agents/field-orders/',
      body: {
        'site_id': cart.siteId,
        'notes': cart.notes,
        'lines': cart.toLinesJson(),
      },
    );
    return _parseOrder(res, 'Create failed');
  }

  /// One-shot visit order: customer + products + map pin → submitted to office.
  Future<Result<FieldOrderSummary>> place({
    required int customerId,
    required double latitude,
    required double longitude,
    required List<Map<String, dynamic>> lines,
    double? accuracy,
    String landmark = '',
    String label = '',
    String notes = '',
  }) async {
    final res = await _client.post(
      'agents/field-orders/place/',
      body: {
        'customer_id': customerId,
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'accuracy': accuracy,
        'landmark': landmark,
        'label': label,
        'notes': notes,
        'lines': lines,
      },
    );
    return _parseOrder(res, 'Place order failed');
  }

  Future<Result<FieldOrderSummary>> submit(int orderId) async {
    final res = await _client.post('agents/field-orders/$orderId/submit/');
    return _parseOrder(res, 'Submit failed');
  }

  Future<Result<List<FieldOrderSummary>>> listMine() async {
    final res = await _client.get('agents/field-orders/?mine=1');
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(FieldOrdersApiException('List failed (${response.statusCode})'));
    }
    try {
      final data = jsonDecode(response.body);
      final rows = data is List
          ? data
          : (data is Map && data['results'] is List ? data['results'] : null);
      if (rows is! List) {
        return Failure(FieldOrdersApiException('Invalid list payload'));
      }
      return Success([
        for (final row in rows)
          if (row is Map)
            FieldOrderSummary.fromJson(Map<String, dynamic>.from(row)),
      ]);
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<FieldOrderSummary>> _parseOrder(
    Result responseResult,
    String label,
  ) async {
    if (responseResult.isFailure) {
      return Failure((responseResult as Failure).error);
    }
    final response = responseResult.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        FieldOrdersApiException(
          '$label (${response.statusCode}): ${_errorBody(response.body)}',
        ),
      );
    }
    try {
      final data = jsonDecode(response.body);
      if (data is! Map) {
        return Failure(FieldOrdersApiException('Invalid order payload'));
      }
      return Success(FieldOrderSummary.fromJson(Map<String, dynamic>.from(data)));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }
}

String _errorBody(String body) {
  final trimmed = body.trim();
  if (trimmed.isEmpty) return 'Request failed';
  if (trimmed.startsWith('<!DOCTYPE') || trimmed.startsWith('<html')) {
    return 'Endpoint not found. Restart the API server with the latest code.';
  }
  try {
    final data = jsonDecode(trimmed);
    if (data is Map) {
      final detail = data['detail'] ?? data['error'] ?? data['message'];
      if (detail != null) return detail.toString();
    }
  } on Object {
    // fall through
  }
  if (trimmed.length <= 180) return trimmed;
  return '${trimmed.substring(0, 180)}…';
}
