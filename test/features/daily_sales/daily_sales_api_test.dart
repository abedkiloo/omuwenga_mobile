import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/data/daily_sales_api.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/payment_status.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late InMemoryTokenStore tokens;

  setUp(() async {
    tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
  });

  DailySalesApi apiWith(MockClient client) {
    return DailySalesApi(
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

  test('load report and debt filter query', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/sales/daily/'));
        expect(request.url.queryParameters['date'], '2026-09-14');
        expect(request.url.queryParameters['payment_status'], 'debt');
        return http.Response(
          jsonEncode({
            'date': '2026-09-14',
            'summary': {
              'total_sales': '500',
              'orders_count': 2,
              'total_paid': '100',
              'paid_orders_count': 0,
              'total_debt_incurred': '400',
              'debt_orders_count': 2,
              'partial_orders_count': 1,
              'total_debt_collected': '0',
              'total_collected': '100',
            },
            'orders': [
              {
                'id': 3,
                'sale_number': 'S-DEBT',
                'total': '400',
                'amount_paid': '0',
                'payment_status': 'debt',
                'customer': {'id': 9, 'name': 'Debtor'},
              },
            ],
          }),
          200,
        );
      }),
    );
    final report = (await api.load(
      date: '2026-09-14',
      paymentStatus: PaymentStatusDisplay.debt,
    )).getOrThrow();
    expect(report.summary.debtOrdersCount, 2);
    expect(report.orders.single.customerName, 'Debtor');
    expect(report.orders.single.paymentStatus, PaymentStatusDisplay.debt);
  });

  test('customer day detail', () async {
    final api = apiWith(
      MockClient((request) async {
        expect(request.url.path, contains('/daily/customer/9/'));
        return http.Response(
          jsonEncode({
            'customer': {'id': 9, 'name': 'Debtor', 'standing': 'debt'},
            'day_summary': {'orders_count': 1, 'day_standing': 'debt'},
            'orders': [
              {
                'id': 3,
                'sale_number': 'S-DEBT',
                'total': '400',
                'amount_paid': '0',
                'payment_status': 'debt',
              },
            ],
          }),
          200,
        );
      }),
    );
    final day = (await api.customerDay(
      customerId: 9,
      date: '2026-09-14',
    )).getOrThrow();
    expect(day.customerName, 'Debtor');
    expect(day.ordersCount, 1);
  });
}
