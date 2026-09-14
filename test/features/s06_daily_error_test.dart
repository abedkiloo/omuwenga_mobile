import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/presentation/daily_sales_page.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth/auth_fixtures.dart';

void main() {
  testWidgets('daily sales error then empty refresh', (tester) async {
    var mode = 'error';
    final tokens = InMemoryTokenStore();
    final client = MockClient((request) async {
      if (mode == 'error') {
        return http.Response(jsonEncode({'error': 'down'}), 500);
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
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
        ],
        child: const MaterialApp(home: DailySalesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    mode = 'empty';
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_empty')), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
  });
}
