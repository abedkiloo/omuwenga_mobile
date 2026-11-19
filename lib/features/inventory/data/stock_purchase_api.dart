import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/network/api_client.dart';
import '../../../core/network/api_error_message.dart';
import '../../../core/result/result.dart';

class StockPurchaseApiException implements Exception {
  StockPurchaseApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class DeliveryLayer {
  const DeliveryLayer({
    required this.layerId,
    required this.quantity,
    required this.salePricePending,
    this.unitCost,
  });

  final int layerId;
  final int quantity;
  final bool salePricePending;
  final String? unitCost;

  factory DeliveryLayer.fromJson(Map<String, dynamic> json) {
    final qty = json['quantity'];
    return DeliveryLayer(
      layerId: (json['layer_id'] as num?)?.toInt() ?? 0,
      quantity: qty is num ? qty.toInt() : int.tryParse('$qty') ?? 0,
      salePricePending: json['sale_price_pending'] == true,
      unitCost: json['unit_cost']?.toString(),
    );
  }
}

class StockPurchaseApi {
  StockPurchaseApi(this._client);
  final ApiClient _client;

  /// Records a delivery. Cost is not sent; a Super Admin sets that later.
  ///
  /// [body] includes product id, quantity of at least 1, and price mode
  /// `new` or `old`. Returns nothing on success.
  Future<Result<void>> record(Map<String, dynamic> body) async {
    return _void(
      await _client.post('inventory/purchase/', body: body),
      'Could not record this delivery',
    );
  }

  /// Open deliveries for [productId], at most 20.
  Future<Result<List<DeliveryLayer>>> pendingPrices(int productId) async {
    final res = await _client.get(
      'inventory/pending-prices/?product_id=$productId',
    );
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(StockPurchaseApiException('Could not load deliveries'));
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const Success([]);
    return Success([
      for (final row in decoded)
        if (row is Map) DeliveryLayer.fromJson(Map<String, dynamic>.from(row)),
    ]);
  }

  /// Saves the selling price so the pieces on [layerId] can be sold.
  Future<Result<void>> setSalePrice({
    required int layerId,
    required String unitSellPrice,
  }) async {
    return _void(
      await _client.post(
        'inventory/set-sale-price/',
        body: {'layer_id': layerId, 'unit_sell_price': unitSellPrice.trim()},
      ),
      'Could not save the selling price',
    );
  }

  /// Super Admin cost for the pieces of [layerId] that are still in stock.
  Future<Result<void>> setLayerCost({
    required int layerId,
    required String unitCost,
  }) async {
    return _void(
      await _client.post(
        'inventory/set-layer-cost/',
        body: {'layer_id': layerId, 'unit_cost': unitCost.trim()},
      ),
      'Could not save the cost',
    );
  }

  Result<void> _void(Result<http.Response> res, String label) {
    if (res.isFailure) return Failure((res as Failure).error);
    final response = res.getOrThrow();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return Failure(
        StockPurchaseApiException(apiErrorMessage(response.body, fallback: label)),
      );
    }
    return const Success(null);
  }
}
