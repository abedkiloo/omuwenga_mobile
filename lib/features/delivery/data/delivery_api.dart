import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/delivery_stop.dart';

class DeliveryApiException implements Exception {
  DeliveryApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DeliveryApi {
  DeliveryApi(this._client);
  final ApiClient _client;

  Future<Result<DeliveryConfig>> config() async {
    final res = await _client.get('delivery/config/');
    return _parse(res, (data) {
      if (data is! Map) throw DeliveryApiException('Invalid config');
      return DeliveryConfig.fromJson(Map<String, dynamic>.from(data));
    }, 'Config failed');
  }

  Future<Result<DeliveryRoute>> todayRoute({bool requirePod = true}) async {
    final res = await _client.get('delivery/routes/today/');
    return _parse(res, (data) {
      if (data is! Map) throw DeliveryApiException('Invalid route');
      return DeliveryRoute.fromJson(
        Map<String, dynamic>.from(data),
        requirePod: requirePod,
      );
    }, 'Route failed');
  }

  Future<Result<DeliveryStop>> retrieve(int id, {bool requirePod = true}) async {
    final res = await _client.get('delivery/stops/$id/');
    return _parseStop(res, requirePod: requirePod);
  }

  Future<Result<DeliveryStop>> arrive(int id) =>
      _postStop('delivery/stops/$id/arrive/');

  Future<Result<DeliveryStop>> start(int id) =>
      _postStop('delivery/stops/$id/start/');

  Future<Result<DeliveryStop>> updateLines(int id, List<DeliveryLine> lines) {
    return _postStop(
      'delivery/stops/$id/lines/',
      body: {
        'lines': [
          for (final l in lines)
            {
              'product_id': l.productId,
              'delivered_quantity': l.deliveredQuantity.toString(),
              'returned_quantity': l.returnedQuantity.toString(),
            },
        ],
      },
    );
  }

  Future<Result<DeliveryStop>> collect(
    int id, {
    required String method,
    double? amount,
    String notes = '',
  }) {
    return _postStop(
      'delivery/stops/$id/collect/',
      body: {
        'method': method,
        if (amount != null) 'amount': amount.toStringAsFixed(2),
        'notes': notes,
      },
    );
  }

  Future<Result<DeliveryStop>> submitPod(
    int id, {
    required PodDraft draft,
    List<int> signatureBytes = const [1, 2, 3],
    List<int> photoBytes = const [4, 5, 6],
  }) async {
    final res = await _client.post(
      'delivery/stops/$id/pod/',
      body: {
        'latitude': '${draft.latitude}',
        'longitude': '${draft.longitude}',
        'notes': draft.notes,
        'signature_b64': base64Encode(signatureBytes),
        'photo_b64': base64Encode(photoBytes),
      },
    );
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(DeliveryApiException('POD failed (${response.statusCode})'));
    }
    return retrieve(id);
  }

  Future<Result<DeliveryStop>> complete(int id) =>
      _postStop('delivery/stops/$id/complete/');

  Future<Result<DeliveryStop>> _postStop(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final res = await _client.post(path, body: body);
    return _parseStop(res);
  }

  Future<Result<T>> _parse<T>(
    Result responseResult,
    T Function(Object? data) map,
    String label,
  ) async {
    if (responseResult.isFailure) {
      return Failure((responseResult as Failure).error);
    }
    final response = responseResult.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(DeliveryApiException('$label (${response.statusCode})'));
    }
    try {
      return Success(map(jsonDecode(response.body)));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<DeliveryStop>> _parseStop(
    Result responseResult, {
    bool requirePod = true,
  }) async {
    return _parse(responseResult, (data) {
      if (data is! Map) throw DeliveryApiException('Invalid stop payload');
      return DeliveryStop.fromJson(
        Map<String, dynamic>.from(data),
        requirePod: requirePod,
      );
    }, 'Request failed');
  }
}
