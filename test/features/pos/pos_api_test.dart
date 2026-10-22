import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/payment.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late InMemoryTokenStore tokens;

  setUp(() async {
    tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
  });

  PosApi apiWith(MockClient client) {
    return PosApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: client,
      ),
    );
  }

  test('search products maps catalog', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/products/search/'));
        return http.Response(
          jsonEncode([
            {
              'id': 12,
              'name': 'Cement 50kg',
              'sku': 'CEM-50',
              'selling_price': '150.00',
              'stock_quantity': 40,
              'has_variants': false,
            },
          ]),
          200,
        );
      }),
    );
    final result = await api.searchProducts('cem');
    final list = result.getOrThrow();
    expect(list.single.id, 12);
    expect(list.single.price, 150);
    expect(list.single.hasVariants, isFalse);
  });

  test('list products maps paginated page', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/products/'));
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['page_size'], '10');
        expect(request.url.queryParameters['is_active'], 'true');
        return http.Response(
          jsonEncode({
            'count': 12,
            'next': 'http://example.com/api/products/?page=2',
            'previous': null,
            'results': [
              {
                'id': 1,
                'name': 'Oil',
                'selling_price': '100.00',
                'has_variants': false,
              },
            ],
          }),
          200,
        );
      }),
    );
    final page = (await api.listProducts()).getOrThrow();
    expect(page.results.single.id, 1);
    expect(page.count, 12);
    expect(page.hasNext, isTrue);
    expect(page.page, 1);
  });

  test('list products passes stock and subcategory filters', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.queryParameters['low_stock'], 'true');
        expect(request.url.queryParameters['subcategory'], '9');
        expect(request.url.queryParameters.containsKey('category'), isFalse);
        return http.Response(
          jsonEncode({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [
              {
                'id': 2,
                'name': 'Low oil',
                'selling_price': '50.00',
                'stock_quantity': 2,
                'is_low_stock': true,
                'has_out_of_stock': false,
                'track_stock': true,
              },
            ],
          }),
          200,
        );
      }),
    );
    final page = (await api.listProducts(
      subcategoryId: 9,
      stockFilter: CatalogStockFilter.lowStock,
    )).getOrThrow();
    expect(page.results.single.isLowStock, isTrue);
    expect(page.results.single.stockQuantity, 2);
  });

  test('fetchVariants maps paginated results', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/products/variants/'));
        expect(request.url.queryParameters['product'], '12');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 101,
                'product': 12,
                'size_name': 'Large',
                'color_name': 'White',
                'effective_price': '22.00',
                'sku': 'T-L-W',
                'stock_quantity': 3,
                'is_active': true,
              },
            ],
          }),
          200,
        );
      }),
    );
    final list = (await api.fetchVariants(12)).getOrThrow();
    expect(list.single.id, 101);
    expect(list.single.displayLabel, 'Large / White');
    expect(list.single.effectivePrice, 22);
  });

  test('checkout success and insufficient stock', () async {
    var call = 0;
    final api = apiWith(
      MockClient((request) async {
        call++;
        expect(request.headers['Idempotency-Key'], isNotEmpty);
        expect(request.headers['X-Client-Channel'], 'mobile');
        if (call == 1) {
          return http.Response(
            jsonEncode({
              'id': 99,
              'sale_number': 'S-99',
              'total': '150.00',
              'payment_method': 'cash',
              'amount_paid': '150.00',
              'change': '0',
              'items': [
                {
                  'product_id': 12,
                  'product_name': 'Cement 50kg',
                  'quantity': 1,
                  'unit_price': 150,
                },
              ],
            }),
            201,
          );
        }
        return http.Response(
          jsonEncode({
            'error': 'Insufficient stock for Cement 50kg. Available: 0',
          }),
          400,
        );
      }),
    );

    final cart = const PosCart().addProduct(
      const CatalogProduct(id: 12, name: 'Cement 50kg', price: 150),
    );
    final ok = await api.createSale(
      cart: cart,
      draft: const CheckoutDraft(
        method: PosPaymentMethod.cash,
        amountPaid: 150,
      ),
      idempotencyKey: 'k1',
    );
    expect(ok.isSuccess, isTrue);
    expect(ok.getOrThrow().saleNumber, 'S-99');

    final bad = await api.createSale(
      cart: cart,
      draft: const CheckoutDraft(
        method: PosPaymentMethod.cash,
        amountPaid: 150,
      ),
      idempotencyKey: 'k2',
    );
    expect(bad.isFailure, isTrue);
    expect(
      bad.when(success: (_) => '', failure: (e, _) => e.toString()),
      contains('Insufficient'),
    );
  });

  test('loadSettings falls back safely', () async {
    final api = apiWith(MockClient((_) async => http.Response('nope', 500)));
    final settings = (await api.loadSettings()).getOrThrow();
    expect(settings.enabledPaymentMethods, isNotEmpty);
  });

  test('fetchActiveHolding maps returned-for-correction cart', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/sales/active-holding/'));
        return http.Response(
          jsonEncode({
            'holding': {
              'id': 77,
              'status': 'holding',
              'needs_salesperson_action': true,
              'rejection_reason': 'Wrong customer',
              'items': [
                {
                  'product_id': 3,
                  'product_name': 'Nail',
                  'quantity': 2,
                  'unit_price': '50.00',
                },
              ],
            },
          }),
          200,
        );
      }),
    );
    final holding = (await api.fetchActiveHolding()).getOrThrow();
    expect(holding, isNotNull);
    expect(holding!['id'], 77);
    expect(holding['needs_salesperson_action'], isTrue);
  });

  test('fetchActiveHolding returns null when no draft', () async {
    final api = apiWith(
      MockClient(
        (_) async => http.Response(jsonEncode({'holding': null}), 200),
      ),
    );
    expect((await api.fetchActiveHolding()).getOrThrow(), isNull);
  });
}
