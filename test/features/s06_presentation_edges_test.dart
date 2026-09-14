import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/presentation/customer_day_page.dart';
import 'package:completebyte_pos_mobile/features/sales_history/presentation/sale_detail_page.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth/auth_fixtures.dart';

List<Override> _base(MockClient client) {
  final tokens = InMemoryTokenStore();
  return [
    tokenStoreProvider.overrideWithValue(tokens),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
    authSessionSeedProvider.overrideWithValue(managerSession(dailySales: true)),
    httpClientProvider.overrideWithValue(client),
    apiClientProvider.overrideWith((ref) {
      return ApiClient(
        env: ref.watch(appEnvProvider),
        tokenStore: tokens,
        httpClient: client,
      );
    }),
    outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
    connectivityMonitorProvider.overrideWithValue(
      FakeConnectivityMonitor(online: true),
    ),
  ];
}

void main() {
  testWidgets('sale detail error, refund cancel, then refund error banner',
      (tester) async {
    var detailCalls = 0;
    final client = MockClient((request) async {
      if (request.url.path.contains('/refund/')) {
        return http.Response(jsonEncode({'error': 'blocked'}), 400);
      }
      detailCalls += 1;
      if (detailCalls == 1) {
        return http.Response(jsonEncode({'error': 'down'}), 500);
      }
      return http.Response(
        jsonEncode({
          'id': 1,
          'sale_number': 'S-1',
          'total': '100',
          'amount_paid': '100',
          'status': 'completed',
          'can_refund': true,
          'customer_name': 'Ann',
          'payment_method': 'cash',
          'cashier_name': 'sam',
          'occurred_at': '2026-09-14',
          'refund_status': 'partial',
          'items': [
            {'product_name': 'Item', 'quantity': 1, 'unit_price': 100},
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: const MaterialApp(home: SaleDetailPage(saleId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sale_refund')), findsOneWidget);
    expect(find.text('partial'), findsOneWidget);

    await tester.tap(find.byKey(const Key('sale_refund')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('refund_reason')), findsNothing);

    await tester.tap(find.byKey(const Key('sale_refund')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('refund_reason')), 'Damaged');
    await tester.tap(find.byKey(const Key('refund_confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sale_detail_error')), findsOneWidget);
  });

  testWidgets('customer day shows error and retries', (tester) async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      if (calls == 1) {
        return http.Response(jsonEncode({'error': 'down'}), 500);
      }
      return http.Response(
        jsonEncode({
          'customer': {'id': 9, 'name': 'Debtor'},
          'day_summary': {'day_standing': 'debt', 'orders_count': 0},
          'orders': [],
        }),
        200,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: const MaterialApp(
          home: CustomerDayPage(customerId: 9, date: '2026-09-14'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_day_standing')), findsOneWidget);
  });
}
