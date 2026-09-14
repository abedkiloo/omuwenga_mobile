import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/application/daily_sales_controllers.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/data/daily_sales_api.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/domain/daily_navigation.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/domain/daily_report.dart';
import 'package:completebyte_pos_mobile/features/sales_history/application/sales_history_controllers.dart';
import 'package:completebyte_pos_mobile/features/sales_history/data/sales_history_api.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/payment_status.dart';
import 'package:completebyte_pos_mobile/sync/domain/client_uuid.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('dailyOrderRoute prefers customer day', () {
    final withCustomer = DailyOrder.fromJson({
      'id': 1,
      'sale_number': 'S',
      'total': '1',
      'amount_paid': '0',
      'payment_status': 'debt',
      'customer': {'id': 9, 'name': 'A'},
    });
    expect(dailyOrderRoute(withCustomer, date: '2026-09-14'), contains('/customer/9'));

    final walkIn = DailyOrder.fromJson({
      'id': 2,
      'sale_number': 'S2',
      'total': '1',
      'amount_paid': '1',
      'payment_status': 'paid',
    });
    expect(dailyOrderRoute(walkIn, date: '2026-09-14'), '/sales/2');
  });

  test('customer day detail standing without day_summary count', () {
    final day = CustomerDayDetail.fromJson({
      'customer': {'id': 1, 'name': 'A', 'standing': 'debt'},
      'orders': [
        {
          'id': 1,
          'sale_number': 'S',
          'total': '1',
          'amount_paid': '0',
          'payment_status': 'debt',
        },
      ],
    });
    expect(day.standing, 'debt');
    expect(day.ordersCount, 1);
  });

  test('api 202 refund and detail http failure bodies', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final api = SalesHistoryApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/refund/')) {
            return http.Response('{}', 202);
          }
          return http.Response('nope', 404);
        }),
      ),
    );
    expect((await api.detail(1)).isFailure, isTrue);
    expect(
      (await api.refund(saleId: 1, reason: 'x', idempotencyKey: 'k')).isSuccess,
      isTrue,
    );

    final detail = SaleDetailController(api, ClientUuid());
    expect(await detail.refund(reason: 'x'), isFalse);
    // load fails then refund without detail stays false
    await detail.load(1);
    expect(detail.state.error, isNotNull);
  });

  test('daily controller clear filter and customer day failure', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final api = DailySalesApi(
      ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/customer/')) {
            return http.Response(jsonEncode({'error': 'missing'}), 404);
          }
          return http.Response(
            jsonEncode({
              'date': '2026-09-14',
              'summary': {
                'total_sales': '0',
                'orders_count': 0,
                'total_paid': '0',
                'paid_orders_count': 0,
                'total_debt_incurred': '0',
                'debt_orders_count': 0,
                'partial_orders_count': 0,
                'total_debt_collected': '0',
                'total_collected': '0',
              },
              'orders': [],
            }),
            200,
          );
        }),
      ),
    );
    final daily = DailySalesController(api, initialDay: DateTime(2026, 9, 14));
    await daily.load();
    await daily.setStatusFilter(PaymentStatusDisplay.debt);
    await daily.setStatusFilter(null);
    expect(daily.state.statusFilter, isNull);

    final day = CustomerDayController(api);
    await day.load(customerId: 1, date: '2026-09-14');
    expect(day.state.error, isNotNull);
  });
}
