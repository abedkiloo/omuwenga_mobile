import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/customers/application/customers_controllers.dart';
import 'package:completebyte_pos_mobile/features/customers/data/customers_api.dart';
import 'package:completebyte_pos_mobile/sync/domain/client_uuid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FixedUuid extends ClientUuid {
  @override
  String next() => 'fixed-idem';
}

void main() {
  test('receive payment success refreshes detail balance', () async {
    var detailCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('/receive-wallet-payment/')) {
        return http.Response(
          jsonEncode({
            'wallet_balance': '0.00',
            'transaction': {'id': 1},
          }),
          201,
        );
      }
      if (request.url.path.contains('/detail/')) {
        detailCalls++;
        final wallet = detailCalls == 1 ? '-100.00' : '0.00';
        return http.Response(
          jsonEncode({
            'customer': {
              'id': 5,
              'name': 'Pat',
              'wallet_balance': wallet,
            },
            'standing_summary': {
              'standing': detailCalls == 1 ? 'debt' : 'good',
            },
            'orders': [],
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });

    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final api = CustomersApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: client,
      ),
    );
    final controller = CustomerDetailController(api, _FixedUuid());
    await controller.load(5);
    expect(controller.state.detail!.debtAmount, 100);

    final ok = await controller.receivePayment(
      amount: 100,
      paymentMethod: 'cash',
    );
    expect(ok, isTrue);
    expect(controller.state.detail!.debtAmount, 0);
    expect(controller.state.settling, isFalse);
    expect(detailCalls, 2);
  });

  test('list controller loads and surfaces error', () async {
    var n = 0;
    final client = MockClient((request) async {
      n++;
      if (n == 1) {
        return http.Response(jsonEncode({'error': 'down'}), 500);
      }
      return http.Response(
        jsonEncode([
          {'id': 1, 'name': 'A', 'wallet_balance': '0'},
        ]),
        200,
      );
    });
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final api = CustomersApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: client,
      ),
    );
    final list = CustomersListController(api);
    await list.load(search: 'a');
    expect(list.state.error, isNotNull);
    await list.load(search: 'a');
    expect(list.state.items.single.name, 'A');
    expect(list.state.error, isNull);
  });
}
