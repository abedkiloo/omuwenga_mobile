import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/pos/application/barcode_scan_lookup.dart';
import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/barcode_scan.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const product = CatalogProduct(
    id: 1,
    name: 'Soap',
    price: 10,
    sku: 'S1',
    barcode: '6281001234567',
  );

  test('blank code returns empty without calling search', () async {
    var called = false;
    final pick = await lookupScanProduct(
      (query, {int limit = 8}) async {
        called = true;
        return const Success([]);
      },
      '  ',
    );
    expect(pick.reason, ScanPickReason.empty);
    expect(called, isFalse);
  });

  test('exact barcode hit returns product', () async {
    final pick = await lookupScanProduct(
      (query, {int limit = 8}) async {
        expect(query, '6281001234567');
        expect(limit, 8);
        return const Success([product]);
      },
      '6281001234567',
    );
    expect(pick.reason, ScanPickReason.exact);
    expect(pick.product, product);
  });

  test('api failure maps to none', () async {
    final pick = await lookupScanProduct(
      (query, {int limit = 8}) async => Failure(Exception('offline')),
      '999',
    );
    expect(pick.reason, ScanPickReason.none);
    expect(pick.product, isNull);
  });

  test('lookupScanProductWithApi uses PosApi.searchProducts', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final api = PosApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          expect(request.url.path, contains('/products/search/'));
          expect(request.url.queryParameters['q'], '6281001234567');
          return http.Response(
            jsonEncode([
              {
                'id': 1,
                'name': 'Soap',
                'sku': 'S1',
                'barcode': '6281001234567',
                'selling_price': 10,
                'stock_quantity': 5,
              },
            ]),
            200,
          );
        }),
      ),
    );
    final pick = await lookupScanProductWithApi(api, '6281001234567');
    expect(pick.reason, ScanPickReason.exact);
    expect(pick.product?.id, 1);
  });
}
