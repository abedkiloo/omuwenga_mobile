import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/sales_history/data/sales_history_api.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/payment_status.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/sale.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late InMemoryTokenStore tokens;

  setUp(() async {
    tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
  });

  SalesHistoryApi apiWith(MockClient client) {
    return SalesHistoryApi(
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

  test('list maps results and filters', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/sales/'));
        expect(request.url.queryParameters['search'], 'ann');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 1,
                'sale_number': 'S-1',
                'total': '100',
                'amount_paid': '40',
                'customer_name': 'Ann',
                'payment_method': 'cash',
              },
            ],
          }),
          200,
        );
      }),
    );
    final list = (await api.list(
      const SalesHistoryFilters(search: 'ann'),
    )).getOrThrow();
    expect(list.single.paymentStatus, PaymentStatusDisplay.partial);
  });

  test('detail and refund success', () async {
    var n = 0;
    final api = apiWith(
      MockClient((request) async {
        n++;
        if (request.url.path.endsWith('/refund/')) {
          expect(request.headers['Idempotency-Key'], 'k1');
          return http.Response(jsonEncode({'id': 9}), 201);
        }
        return http.Response(
          jsonEncode({
            'id': '1',
            'sale_number': 'S-1',
            'total': '100',
            'amount_paid': '100',
            'status': 'completed',
            'can_refund': true,
            'customer': {'id': '4'},
            'items': [
              {
                'product': {'id': '7'},
                'product_name': 'Cement',
                'quantity': 1,
                'unit_price': 100,
              },
            ],
          }),
          200,
        );
      }),
    );
    final detail = (await api.detail(1)).getOrThrow();
    expect(detail.id, 1);
    expect(detail.customerId, 4);
    expect(detail.items.single.productId, 7);
    expect(detail.items.single.productName, 'Cement');
    expect(
      (await api.refund(
        saleId: 1,
        reason: 'Wrong',
        idempotencyKey: 'k1',
      )).isSuccess,
      isTrue,
    );
    expect(n, 2);
  });

  test('api errors', () async {
    final api = apiWith(
      MockClient(
        (_) async => http.Response(jsonEncode({'error': 'Nope'}), 400),
      ),
    );
    expect((await api.list(const SalesHistoryFilters())).isFailure, isTrue);
    expect(SalesHistoryApiException('x').toString(), 'x');

    final malformed = apiWith(
      MockClient((_) async => http.Response('{not-json', 200)),
    );
    expect(
      (await malformed.list(const SalesHistoryFilters())).isFailure,
      isTrue,
    );
    expect((await malformed.detail(1)).isFailure, isTrue);
  });
}
