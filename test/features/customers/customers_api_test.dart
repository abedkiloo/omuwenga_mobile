import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/customers/data/customers_api.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/customer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late InMemoryTokenStore tokens;

  setUp(() async {
    tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
  });

  CustomersApi apiWith(MockClient client) {
    return CustomersApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: client,
      ),
    );
  }

  test('list maps results and search query', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/sales/customers/'));
        expect(request.url.queryParameters['search'], 'ann');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 3,
                'name': 'Ann',
                'phone': '0700',
                'wallet_balance': '-40.00',
              },
            ],
          }),
          200,
        );
      }),
    );
    final list = (await api.list(search: 'ann')).getOrThrow();
    expect(list.single.name, 'Ann');
    expect(list.single.debtAmount, 40);
  });

  test('detail parses standing and orders', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/detail/'));
        return http.Response(
          jsonEncode({
            'customer': {
              'id': 3,
              'name': 'Ann',
              'wallet_balance': '-100.00',
              'standing': 'debt',
            },
            'standing_summary': {'standing': 'debt'},
            'orders': [
              {
                'id': 9,
                'sale_number': 'S-9',
                'total': '50.00',
                'created_at': '2026-01-01',
              },
            ],
          }),
          200,
        );
      }),
    );
    final detail = (await api.detail(3)).getOrThrow();
    expect(detail.debtAmount, 100);
    expect(detail.recentOrders.single.saleNumber, 'S-9');
  });

  test('receive wallet payment success', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/receive-wallet-payment/'));
        expect(request.headers['Idempotency-Key'], 'idem-1');
        final body = jsonDecode(request.body) as Map;
        expect(body['amount'], 40);
        expect(body['payment_method'], 'cash');
        return http.Response(
          jsonEncode({
            'wallet_balance': '-60.00',
            'transaction': {'id': 12},
          }),
          201,
        );
      }),
    );
    final result = await api.receiveWalletPayment(
      customerId: 3,
      amount: 40,
      paymentMethod: 'cash',
      idempotencyKey: 'idem-1',
    );
    expect(result.getOrThrow().walletBalance, -60);
    expect(result.getOrThrow().transactionId, 12);
  });

  test('create and update and settings nested', () async {
    var calls = 0;
    final api = apiWith(
      MockClient((request) async {
        calls++;
        if (request.method == 'POST') {
          return http.Response(jsonEncode({'id': 8, 'name': 'New'}), 201);
        }
        if (request.method == 'PUT') {
          return http.Response(jsonEncode({'id': 8, 'name': 'Updated'}), 200);
        }
        return http.Response(
          jsonEncode({
            'module': 'customers',
            'settings': {
              'enable_wallet_payment': {'value': false},
              'show_wallet_balance': {'value': true},
            },
          }),
          200,
        );
      }),
    );
    expect((await api.create(const CustomerDraft(name: 'New'))).getOrThrow().id, 8);
    expect(
      (await api.update(8, const CustomerDraft(name: 'Updated'))).getOrThrow().name,
      'Updated',
    );
    final settings = (await api.loadSettings()).getOrThrow();
    expect(settings.enableWalletPayment, isFalse);
    expect(settings.showWalletBalance, isTrue);
    expect(calls, 3);
  });

  test('api errors surface message', () async {
    final api = apiWith(
      MockClient((_) async => http.Response(jsonEncode({'error': 'Nope'}), 400)),
    );
    final fail = await api.list();
    expect(fail.isFailure, isTrue);
    expect(fail.when(success: (_) => '', failure: (e, _) => e.toString()), 'Nope');
  });
}
