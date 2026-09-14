import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/cart.dart';
import '../domain/payment.dart';
import '../domain/product_variant.dart';

class SaleReceipt {
  const SaleReceipt({
    required this.id,
    required this.saleNumber,
    required this.total,
    required this.paymentMethod,
    required this.amountPaid,
    required this.change,
    required this.items,
    this.customerName,
    this.queuedOffline = false,
  });

  final int? id;
  final String saleNumber;
  final double total;
  final String paymentMethod;
  final double amountPaid;
  final double change;
  final List<CartLine> items;
  final String? customerName;
  final bool queuedOffline;

  factory SaleReceipt.fromJson(Map<String, dynamic> json) {
    double asDouble(Object? v) {
      if (v is num) return v.toDouble();
      return double.tryParse(v?.toString() ?? '') ?? 0;
    }

    final rawItems = json['items'];
    final items = <CartLine>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        items.add(
          CartLine(
            productId: (map['product_id'] as num?)?.toInt() ?? 0,
            name: (map['product_name'] ?? map['name'] ?? 'Item').toString(),
            sku: map['product_sku']?.toString(),
            unitPrice: asDouble(map['unit_price']),
            quantity: asDouble(map['quantity']),
          ),
        );
      }
    }

    return SaleReceipt(
      id: (json['id'] as num?)?.toInt(),
      saleNumber: (json['sale_number'] ?? json['id'] ?? '').toString(),
      total: asDouble(json['total']),
      paymentMethod: (json['payment_method'] ?? '').toString(),
      amountPaid: asDouble(json['amount_paid']),
      change: asDouble(json['change']),
      items: items,
      customerName: json['customer_name']?.toString(),
    );
  }
}

class PosApi {
  PosApi(this._client);

  final ApiClient _client;

  Future<Result<List<CatalogProduct>>> searchProducts(String query, {int limit = 20}) async {
    final q = query.trim();
    if (q.isEmpty) return const Success([]);
    final response = await _client.get(
      'products/search/?q=${Uri.encodeQueryComponent(q)}&limit=$limit',
    );
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(PosApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return const Success([]);
    return Success([
      for (final item in decoded)
        if (item is Map) CatalogProduct.fromJson(Map<String, dynamic>.from(item)),
    ]);
  }

  /// Active variants for a parent product (`GET /products/variants/?product=`).
  Future<Result<List<ProductVariant>>> fetchVariants(int productId) async {
    final response = await _client.get(
      'products/variants/?product=$productId&is_active=true',
    );
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(PosApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    final rows = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map) rows.add(Map<String, dynamic>.from(item));
      }
    } else if (decoded is Map) {
      final results = decoded['results'];
      if (results is List) {
        for (final item in results) {
          if (item is Map) rows.add(Map<String, dynamic>.from(item));
        }
      }
    }
    return Success([
      for (final row in rows)
        ProductVariant.fromJson(row),
    ].where((v) => v.isActive).toList());
  }

  Future<Result<PosSettings>> loadSettings() async {
    try {
      Map<String, dynamic>? sales;
      Map<String, dynamic>? store;

      final salesRes = await _client.get('settings/sales/');
      if (salesRes.isSuccess) {
        final r = salesRes.getOrThrow();
        if (r.statusCode >= 200 && r.statusCode < 300) {
          final d = jsonDecode(r.body);
          if (d is Map) sales = Map<String, dynamic>.from(d);
        }
      }

      final storeRes = await _client.get('settings/store-settings/');
      if (storeRes.isSuccess) {
        final r = storeRes.getOrThrow();
        if (r.statusCode >= 200 && r.statusCode < 300) {
          final d = jsonDecode(r.body);
          if (d is Map) store = Map<String, dynamic>.from(d);
        }
      }

      return Success(PosSettings.fromApis(sales: sales, store: store));
    } on Object catch (e, st) {
      return Failure(e, st);
    }
  }

  Future<Result<SaleReceipt>> createSale({
    required PosCart cart,
    required CheckoutDraft draft,
    required String idempotencyKey,
  }) async {
    final body = <String, dynamic>{
      'sale_type': 'pos',
      'items': cart.toSaleItemsJson(),
      'payment_method': draft.method.apiValue,
      'amount_paid': draft.amountPaid,
      'tax_amount': cart.taxAmount,
      'discount_amount': cart.discountAmount,
      'allow_partial_payment': false,
      'excess_payment_choice': 'change',
      if (cart.customerId != null) 'customer_id': cart.customerId,
      if (draft.paymentReference.trim().isNotEmpty)
        'payment_reference': draft.paymentReference.trim(),
    };

    final response = await _client.post(
      'sales/',
      body: body,
      idempotencyKey: idempotencyKey,
    );
    if (response.isFailure) {
      final f = response as Failure;
      return Failure(f.error, f.stackTrace);
    }
    final res = response.getOrThrow();
    if (res.statusCode == 400 || res.statusCode == 422) {
      return Failure(PosApiException(_safeError(res.body)));
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return Failure(PosApiException(_safeError(res.body)));
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! Map) {
      return Failure(PosApiException('Unexpected sale response.'));
    }
    return Success(SaleReceipt.fromJson(Map<String, dynamic>.from(decoded)));
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
    return 'Could not complete sale. Please try again.';
  }
}

class PosApiException implements Exception {
  PosApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
