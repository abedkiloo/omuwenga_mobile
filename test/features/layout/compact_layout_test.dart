import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/debt_management.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/debt_collection_list.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/data/daily_sales_api.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/domain/daily_report.dart';
import 'package:completebyte_pos_mobile/features/home/application/home_daily_controller.dart';
import 'package:completebyte_pos_mobile/features/home/presentation/store_home_dashboard.dart';
import 'package:completebyte_pos_mobile/features/pos/application/pos_controllers.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/payment.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/pos_page.dart';
import 'package:completebyte_pos_mobile/features/sales_history/application/sales_history_controllers.dart';
import 'package:completebyte_pos_mobile/features/sales_history/data/sales_history_api.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/payment_status.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/sale.dart';
import 'package:completebyte_pos_mobile/features/sales_history/presentation/sales_history_page.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _phones = <Size>[
  Size(320, 568),
  Size(375, 667),
  Size(414, 896),
];

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _expectNoOverflow(WidgetTester tester) async {
  await tester.pump();
  expect(tester.takeException(), isNull);
}

DebtCollections _longCollections() {
  return DebtCollections(
    date: '2026-01-02',
    count: 1,
    total: 1234567.89,
    results: [
      DebtCollectionRow(
        id: 9,
        customerId: 3,
        customerName: 'Very Long Customer Name For Overflow Layout Check',
        customerPhone: '070012345678901',
        customerCode: 'CUST-CODE-OVERFLOW',
        amount: 9876543.21,
        balanceAfter: -4444444.44,
        reference: 'MPESA-VERY-LONG-RECEIPT-XYZ',
        notes: 'Field collection after a long visit with extra notes',
        receivedBy: 'Salesperson With A Long Name',
        createdAt: '2026-01-02T07:15:00.000Z',
      ),
    ],
  );
}

void main() {
  testWidgets('debt collections stay inside 320–414 widths', (tester) async {
    for (final size in _phones) {
      _setSize(tester, size);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DebtCollectionsPanel(
                date: '2026-01-02',
                collections: _longCollections(),
                loading: false,
                onClose: () {},
                onPreviousDay: () {},
                onNextDay: () {},
                onJumpToday: () {},
                onOpenCustomer: (_) {},
              ),
            ),
          ),
        ),
      );
      await _expectNoOverflow(tester);
      expect(find.byKey(const Key('debt_collections_panel')), findsOneWidget);
      expect(find.byKey(const Key('collection_amount_9')), findsOneWidget);
    }
  });

  testWidgets('home dashboard tiles stay inside 320–414 widths', (tester) async {
    final tokens = InMemoryTokenStore();
    final httpClient = MockClient((request) async => http.Response('{}', 200));
    final api = ApiClient(
      env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
      tokenStore: tokens,
      httpClient: httpClient,
    );
    final controller = HomeDailyController(
      dailyApi: DailySalesApi(api),
      salesApi: SalesHistoryApi(api),
      session: null,
    );
    controller.state = const HomeDailyState(
      summary: HomeDailySummary(
        dateLabel: 'Today',
        scopeAll: false,
        summary: DailySummary(
          totalSales: 9999999.99,
          ordersCount: 12,
          totalPaid: 8888888.88,
          paidOrdersCount: 9,
          totalDebtIncurred: 1111111.11,
          debtOrdersCount: 3,
          partialOrdersCount: 0,
          totalDebtCollected: 0,
          totalCollected: 8888888.88,
        ),
        orders: [
          DailyOrder(
            id: 1,
            saleNumber: 'SALE-VERY-LONG-NUMBER-12345',
            total: 1234567.89,
            amountPaid: 100,
            paymentStatus: PaymentStatusDisplay.debt,
            customerName: 'Very Long Customer Name For Overflow Check',
            paymentMethod: 'M-PESA',
          ),
        ],
      ),
    );

    for (final size in _phones) {
      _setSize(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [homeDailyProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(
            home: Scaffold(
              body: StoreHomeDashboard(
                title: 'Very Long Store Home Title For Overflow',
                canAccessPos: true,
                canViewCustomers: true,
                canViewDailySales: true,
                canViewSales: true,
                canViewDebtors: true,
                canDispatch: true,
                canPlaceVisitOrders: true,
                canAccessDelivery: true,
                canViewDeliveryHistory: true,
              ),
            ),
          ),
        ),
      );
      await _expectNoOverflow(tester);
      expect(find.byKey(const Key('home_daily_summary')), findsOneWidget);
    }
  });

  testWidgets('POS empty catalog stays inside a 320px till', (tester) async {
    _setSize(tester, const Size(320, 568));
    final tokens = InMemoryTokenStore();
    final httpClient = MockClient((request) async {
      return http.Response('{"count":0,"results":[]}', 200);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          appEnvProvider.overrideWithValue(
            const AppEnv(
              flavor: AppFlavor.dev,
              apiBaseUrl: 'http://example.com/api',
            ),
          ),
          httpClientProvider.overrideWithValue(httpClient),
          apiClientProvider.overrideWith((ref) {
            return ApiClient(
              env: ref.watch(appEnvProvider),
              tokenStore: tokens,
              httpClient: httpClient,
            );
          }),
          outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
          connectivityMonitorProvider.overrideWithValue(
            FakeConnectivityMonitor(online: true),
          ),
          posSettingsProvider.overrideWith((ref) async => const PosSettings()),
        ],
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sales history awaiting cards stay inside 320–414 widths', (
    tester,
  ) async {
    final tokens = InMemoryTokenStore();
    final httpClient = MockClient((request) async => http.Response('{}', 200));
    final api = ApiClient(
      env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
      tokenStore: tokens,
      httpClient: httpClient,
    );
    final history = _FrozenSalesHistory(SalesHistoryApi(api));

    for (final size in _phones) {
      _setSize(tester, size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            salesHistoryProvider.overrideWith((ref) => history),
          ],
          child: const MaterialApp(home: SalesHistoryPage()),
        ),
      );
      await tester.pump();
      await tester.pump();
      await _expectNoOverflow(tester);
      expect(find.text('Needs salesperson action'), findsWidgets);
      expect(find.byKey(const Key('sale_row_1')), findsOneWidget);
    }
  });

  testWidgets('POS proceed stays docked above the tab bar on phone sizes', (
    tester,
  ) async {
    final sizes = <Size>[
      const Size(320, 568),
      const Size(375, 667),
      const Size(568, 320),
    ];
    for (final size in sizes) {
      _setSize(tester, size);
      final tokens = InMemoryTokenStore();
      final httpClient = MockClient((request) async {
        return http.Response('{"count":0,"results":[]}', 200);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            tokenStoreProvider.overrideWithValue(tokens),
            appEnvProvider.overrideWithValue(
              const AppEnv(
                flavor: AppFlavor.dev,
                apiBaseUrl: 'http://example.com/api',
              ),
            ),
            httpClientProvider.overrideWithValue(httpClient),
            apiClientProvider.overrideWith((ref) {
              return ApiClient(
                env: ref.watch(appEnvProvider),
                tokenStore: tokens,
                httpClient: httpClient,
              );
            }),
            outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
            connectivityMonitorProvider.overrideWithValue(
              FakeConnectivityMonitor(online: true),
            ),
            posSettingsProvider.overrideWith((ref) async => const PosSettings()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: const PosPage(),
              bottomNavigationBar: NavigationBar(
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.point_of_sale_outlined),
                    label: 'POS',
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
      final pay = tester.getRect(find.byKey(const Key('pos_pay')));
      final nav = tester.getRect(find.byType(NavigationBar));
      expect(pay.bottom, lessThanOrEqualTo(nav.top + 1));
      expect(pay.top, greaterThan(0));
    }
  });
}

class _FrozenSalesHistory extends SalesHistoryController {
  _FrozenSalesHistory(super.api) {
    state = const SalesHistoryState(
      loading: false,
      items: [
        SaleSummary(
          id: 1,
          saleNumber: 'SALE-VERY-LONG-NUMBER-12345',
          total: 1234567.89,
          amountPaid: 1234567.89,
          customerName: 'Very Long Customer Name For Overflow Layout Check',
          cashierName: 'Cashier With A Long Name',
          status: 'holding',
          needsSalespersonAction: true,
          rejectionReason:
              'Wrong prices and a very long manager comment that should wrap without overflowing the card',
          occurredAt: '2026-01-02T07:15:00.000Z',
        ),
      ],
    );
  }

  @override
  Future<void> load({SalesHistoryFilters? filters}) async {}
}
