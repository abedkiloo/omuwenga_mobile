import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/application/daily_sales_controllers.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/data/daily_sales_api.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/domain/daily_report.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/presentation/customer_day_page.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/presentation/daily_sales_page.dart';
import 'package:completebyte_pos_mobile/features/sales_history/application/sales_history_controllers.dart';
import 'package:completebyte_pos_mobile/features/sales_history/data/sales_history_api.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/payment_status.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/sale.dart';
import 'package:completebyte_pos_mobile/features/sales_history/presentation/sale_detail_page.dart';
import 'package:completebyte_pos_mobile/features/sales_history/presentation/sales_history_page.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/domain/client_uuid.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'auth/auth_fixtures.dart';

List<Override> base(MockClient client) {
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
  test('domain parsers and filters', () {
    final summary = SaleSummary.fromJson({
      'id': 1,
      'sale_number': 'S1',
      'total': '10',
      'amount_paid': '0',
    });
    expect(summary.debtAmount, 10);
    expect(summary.paymentStatus, PaymentStatusDisplay.debt);

    final detail = SaleDetail.fromJson({
      'id': 1,
      'sale_number': 'S1',
      'total': 10,
      'amount_paid': 10,
      'can_refund': true,
      'status': 'completed',
      'customer_name': 'A',
      'payment_method': 'cash',
      'cashier_name': 'c',
      'occurred_at': 't',
      'refund_status': 'none',
      'subtotal': '12',
      'tax_amount': '1',
      'discount_amount': '3',
      'change': '2',
      'served_by_name': 'Grace',
      'sale_type': 'pos',
      'items': [
        {
          'product_name': 'X',
          'product_sku': 'SKU-X',
          'quantity': 2,
          'unit_price': 5,
        },
      ],
    });
    expect(detail.items.single.lineTotal, 10);
    expect(detail.items.single.sku, 'SKU-X');
    expect(detail.discountAmount, 3);

    final filters = const SalesHistoryFilters(
      search: 'a',
    ).copyWith(dateFrom: '2026-01-01', paymentMethod: 'cash');
    expect(filters.toQuery()['date_from'], '2026-01-01');
    expect(filters.copyWith(clearDates: true).dateFrom, isNull);

    final report = DailySalesReport.fromJson({
      'date': '2026-09-14',
      'summary': {'total_sales': '1', 'orders_count': 1},
      'orders': [
        {
          'id': 1,
          'sale_number': 'S',
          'total': '1',
          'amount_paid': '1',
          'payment_status': 'paid',
        },
        {'id': 2, 'sale_number': 'S2', 'total': '10', 'amount_paid': '4'},
      ],
    });
    expect(report.orders[1].paymentStatus, PaymentStatusDisplay.partial);

    final day = CustomerDayDetail.fromJson({
      'customer': {'id': 1, 'name': 'A', 'standing': 'good'},
      'orders': [
        {
          'id': 1,
          'sale_number': 'S',
          'total': '1',
          'amount_paid': '1',
          'payment_status': 'paid',
        },
      ],
    });
    expect(day.ordersCount, 1);
    expect(day.standing, 'good');
  });

  test('controllers load refund and daily navigation', () async {
    var refunded = false;
    final client = MockClient((request) async {
      if (request.url.path.contains('/refund/')) {
        refunded = true;
        return http.Response('{}', 202);
      }
      if (request.url.path.contains('/daily/customer/')) {
        return http.Response(
          jsonEncode({
            'customer': {'id': 9, 'name': 'D'},
            'day_summary': {'day_standing': 'debt', 'orders_count': 1},
            'orders': [
              {
                'id': 3,
                'sale_number': 'S',
                'total': '1',
                'amount_paid': '0',
                'payment_status': 'debt',
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path.contains('/sales/daily/')) {
        return http.Response(
          jsonEncode({
            'date': request.url.queryParameters['date'],
            'summary': {
              'total_sales': '1',
              'orders_count': 1,
              'total_paid': '0',
              'paid_orders_count': 0,
              'total_debt_incurred': '1',
              'debt_orders_count': 1,
              'partial_orders_count': 0,
              'total_debt_collected': '0',
              'total_collected': '0',
            },
            'orders': [],
          }),
          200,
        );
      }
      if (request.url.path.contains('/sales/') &&
          request.url.pathSegments.length > 2) {
        return http.Response(
          jsonEncode({
            'id': 1,
            'sale_number': 'S-1',
            'total': '10',
            'amount_paid': '10',
            'status': 'completed',
            'can_refund': true,
            'items': [],
          }),
          200,
        );
      }
      return http.Response(jsonEncode([]), 200);
    });

    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final historyApi = SalesHistoryApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: client,
      ),
    );
    final dailyApi = DailySalesApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: client,
      ),
    );

    final history = SalesHistoryController(historyApi);
    await history.load();
    expect(history.state.items, isEmpty);

    final detail = SaleDetailController(historyApi, ClientUuid());
    expect(await detail.refund(reason: 'x'), isFalse);
    await detail.load(1);
    expect(await detail.refund(reason: 'wrong item'), isTrue);
    expect(refunded, isTrue);

    final daily = DailySalesController(
      dailyApi,
      initialDay: DateTime(2026, 9, 14),
    );
    await daily.load();
    await daily.goToPreviousDay();
    await daily.goToNextDay();
    await daily.setStatusFilter(PaymentStatusDisplay.paid);
    await daily.setStatusFilter(null);
    await daily.setSearch('x');
    expect(daily.state.report, isNotNull);

    final customerDay = CustomerDayController(dailyApi);
    await customerDay.load(customerId: 9, date: '2026-09-14');
    expect(customerDay.state.detail!.customerName, 'D');

    expect(
      PermissionSet([
        const PermissionGrant(module: 'sales', action: 'refund'),
      ]).canRefundSales,
      isTrue,
    );
  });

  testWidgets('history list and sale detail refund UI', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/refund/')) {
        return http.Response(jsonEncode({'id': 1}), 201);
      }
      if (RegExp(r'/sales/\d+/?$').hasMatch(request.url.path)) {
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
            'payment_reference': 'CASH-1',
            'cashier_name': 'sam',
            'occurred_at': '2026-09-14',
            'subtotal': '100',
            'tax_amount': '0',
            'discount_amount': '0',
            'change': '0',
            'items': [
              {
                'product_name': 'Item',
                'product_sku': 'ITEM-1',
                'quantity': 1,
                'unit_price': 100,
              },
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'sale_number': 'S-1',
            'total': '100',
            'amount_paid': '100',
            'customer_name': 'Ann',
          },
        ]),
        200,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: base(client),
        child: const MaterialApp(home: SalesHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sale_row_1')), findsOneWidget);
    expect(find.byKey(const Key('sales_shift_total')), findsOneWidget);
    expect(find.text('SALES (1)'), findsOneWidget);
    expect(find.byKey(const Key('sales_method_card')), findsNothing);
    expect(find.byKey(const Key('sales_export_shift')), findsNothing);

    await tester.pumpWidget(
      ProviderScope(
        overrides: base(client),
        child: const MaterialApp(home: SaleDetailPage(saleId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sale_refund')), findsOneWidget);
    expect(find.byKey(const Key('sale_print_receipt')), findsOneWidget);
    expect(find.byKey(const Key('sale_share_receipt')), findsOneWidget);
    expect(find.text('Financial Accounting'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('Tender & Gateway Audit'), findsOneWidget);
    await tester.tap(find.byKey(const Key('sale_refund')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('refund_reason')), 'Damaged');
    await tester.tap(find.byKey(const Key('refund_confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('daily page empty', (tester) async {
    final client = MockClient((request) async {
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
        overrides: base(client),
        child: const MaterialApp(home: DailySalesPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_empty')), findsOneWidget);
  });

  testWidgets('customer day page', (tester) async {
    final client = MockClient((request) async {
      if (RegExp(r'/sales/\d+/?$').hasMatch(request.url.path)) {
        return http.Response(
          jsonEncode({
            'id': 3,
            'sale_number': 'S-DEBT',
            'total': '40',
            'amount_paid': '0',
            'status': 'completed',
            'can_refund': false,
            'items': [],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'customer': {'id': 9, 'name': 'Debtor'},
          'day_summary': {'day_standing': 'debt', 'orders_count': 1},
          'orders': [
            {
              'id': 3,
              'sale_number': 'S-DEBT',
              'total': '40',
              'amount_paid': '0',
              'payment_status': 'debt',
            },
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: base(client),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) =>
                    const CustomerDayPage(customerId: 9, date: '2026-09-14'),
              ),
              GoRoute(
                path: '/sales/:id',
                builder: (_, state) => SaleDetailPage(
                  saleId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_day_standing')), findsOneWidget);
    expect(find.byKey(const Key('customer_day_order_3')), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer_day_order_3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sale_status_hero')), findsOneWidget);
  });

  test('api failure branches', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final throwClient = MockClient((_) async => throw Exception('down'));
    final api = SalesHistoryApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: throwClient,
      ),
    );
    expect((await api.list(const SalesHistoryFilters())).isFailure, isTrue);
    expect((await api.detail(1)).isFailure, isTrue);
    expect(
      (await api.refund(saleId: 1, reason: 'x', idempotencyKey: 'k')).isFailure,
      isTrue,
    );

    final weird = SalesHistoryApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/refund/')) {
            return http.Response('[]', 201);
          }
          if (request.url.path.contains('/sales/') &&
              RegExp(r'/sales/\d+').hasMatch(request.url.path)) {
            return http.Response('[]', 200);
          }
          return http.Response('[]', 500);
        }),
      ),
    );
    expect((await weird.detail(1)).isFailure, isTrue);
    expect((await weird.list(const SalesHistoryFilters())).isFailure, isTrue);
    expect(
      (await weird.refund(
        saleId: 1,
        reason: 'x',
        idempotencyKey: 'k2',
      )).isSuccess,
      isTrue,
    );

    final daily = DailySalesApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient(
          (_) async => http.Response(jsonEncode({'error': 'bad'}), 400),
        ),
      ),
    );
    expect((await daily.load(date: '2026-09-14')).isFailure, isTrue);
    expect(
      (await daily.customerDay(customerId: 1, date: '2026-09-14')).isFailure,
      isTrue,
    );

    final dailyThrow = DailySalesApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: throwClient,
      ),
    );
    expect((await dailyThrow.load(date: '2026-09-14')).isFailure, isTrue);
    expect(
      (await dailyThrow.customerDay(
        customerId: 1,
        date: '2026-09-14',
      )).isFailure,
      isTrue,
    );

    final dailyWeird = DailySalesApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient((_) async => http.Response('[]', 200)),
      ),
    );
    expect((await dailyWeird.load(date: '2026-09-14')).isFailure, isTrue);
    expect(
      (await dailyWeird.customerDay(
        customerId: 1,
        date: '2026-09-14',
      )).isFailure,
      isTrue,
    );
    expect(DailySalesApiException('x').toString(), 'x');
  });

  testWidgets('history filters error empty and date chips', (tester) async {
    var mode = 'error';
    final client = MockClient((request) async {
      if (mode == 'error') {
        return http.Response(jsonEncode({'error': 'down'}), 500);
      }
      return http.Response(jsonEncode([]), 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: base(client),
        child: const MaterialApp(home: SalesHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    mode = 'empty';
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sales_empty')), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('sales_search')), 'x');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sales_method_mpesa')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sales_filter_from')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sales_filter_to')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  });

  test('provider wiring and copyWith branches', () async {
    final client = MockClient((_) async => http.Response(jsonEncode([]), 200));
    final container = ProviderContainer(overrides: base(client));
    addTearDown(container.dispose);
    container.read(salesHistoryApiProvider);
    container.read(dailySalesApiProvider);
    container.read(salesHistoryProvider);
    await container
        .read(salesHistoryProvider.notifier)
        .load(
          filters: const SalesHistoryFilters(
            dateFrom: '2026-01-01',
          ).copyWith(dateTo: '2026-01-02', search: 'q'),
        );
    final s = const SalesHistoryState(error: 'e');
    expect(s.copyWith(loading: true).error, 'e');
    expect(s.copyWith(clearError: true).error, isNull);
  });

  testWidgets('sale not found empty state', (tester) async {
    final client = MockClient((_) async => http.Response('{}', 200));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base(client),
          saleDetailProvider(99).overrideWith((ref) {
            return SaleDetailController(
              SalesHistoryApi(
                ApiClient(
                  env: const AppEnv(
                    flavor: AppFlavor.dev,
                    apiBaseUrl: 'http://example.com/api',
                  ),
                  tokenStore: InMemoryTokenStore(),
                  httpClient: client,
                ),
              ),
              ClientUuid(),
            );
          }),
        ],
        child: const MaterialApp(home: SaleDetailPage(saleId: 99)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sale not found'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
  });

  testWidgets('history row opens detail', (tester) async {
    final client = MockClient((request) async {
      if (RegExp(r'/sales/\d+/?$').hasMatch(request.url.path)) {
        return http.Response(
          jsonEncode({
            'id': 1,
            'sale_number': 'S-1',
            'total': '10',
            'amount_paid': '10',
            'status': 'completed',
            'can_refund': false,
            'items': [],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode([
          {
            'id': 1,
            'sale_number': 'S-1',
            'total': '10',
            'amount_paid': '10',
            'customer_name': 'A',
          },
          {'id': 2, 'sale_number': 'S-2', 'total': '20', 'amount_paid': '0'},
        ]),
        200,
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: base(client),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const SalesHistoryPage()),
              GoRoute(
                path: '/sales/:id',
                builder: (_, state) => SaleDetailPage(
                  saleId: int.parse(state.pathParameters['id']!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('sale_row_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sale_status_hero')), findsOneWidget);
  });

  testWidgets('customer day empty after failed load without detail', (
    tester,
  ) async {
    final client = MockClient((_) async => http.Response('{}', 200));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base(client),
          customerDayProvider((customerId: 9, date: '2026-09-14')).overrideWith(
            (ref) => CustomerDayController(
              DailySalesApi(
                ApiClient(
                  env: const AppEnv(
                    flavor: AppFlavor.dev,
                    apiBaseUrl: 'http://example.com/api',
                  ),
                  tokenStore: InMemoryTokenStore(),
                  httpClient: client,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: CustomerDayPage(customerId: 9, date: '2026-09-14'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No day data'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
  });
}
