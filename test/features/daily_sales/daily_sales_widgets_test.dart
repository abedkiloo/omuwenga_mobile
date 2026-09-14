import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/app/router.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/store_shell.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/application/daily_sales_controllers.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/data/daily_sales_api.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/presentation/customer_day_page.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/presentation/daily_sales_page.dart';
import 'package:completebyte_pos_mobile/features/sales_history/domain/payment_status.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/auth_fixtures.dart';

AuthSession _manager({required bool dailySales, bool refund = false}) {
  return AuthSession(
    user: const AuthUser(id: 2, username: 'manager', firstName: 'Mo', lastName: 'Lead'),
    profile: const UserProfileSnapshot(
      role: 'manager',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: true,
    ),
    permissions: PermissionSet([
      const PermissionGrant(module: 'sales', action: 'view'),
      const PermissionGrant(module: 'customers', action: 'view'),
      if (refund) const PermissionGrant(module: 'sales', action: 'refund'),
      if (dailySales) const PermissionGrant(module: 'sales', action: 'daily_sales'),
    ]),
    persona: AppPersona.manager,
  );
}

List<Override> _overrides({
  required AuthSession session,
  required MockClient client,
}) {
  final tokens = InMemoryTokenStore();
  return [
    tokenStoreProvider.overrideWithValue(tokens),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
    authSessionSeedProvider.overrideWithValue(session),
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

Map<String, dynamic> _report({
  required String date,
  String status = 'debt',
}) {
  return {
    'date': date,
    'summary': {
      'total_sales': '400',
      'orders_count': 1,
      'total_paid': '0',
      'paid_orders_count': 0,
      'total_debt_incurred': '400',
      'debt_orders_count': 1,
      'partial_orders_count': 0,
      'total_debt_collected': '0',
      'total_collected': '0',
    },
    'orders': [
      {
        'id': 3,
        'sale_number': 'S-DEBT',
        'total': '400',
        'amount_paid': '0',
        'payment_status': status,
        'customer': {'id': 9, 'name': 'Debtor'},
      },
      {
        'id': 4,
        'sale_number': 'S-WALK',
        'total': '50',
        'amount_paid': '50',
        'payment_status': 'paid',
      },
    ],
  };
}

void main() {
  testWidgets('daily sales hidden on More without permission', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(_manager(dailySales: false)),
        child: const MaterialApp(home: MorePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more_daily_sales')), findsNothing);
    expect(find.byKey(const Key('more_sales_history')), findsOneWidget);
  });

  testWidgets('daily sales shown with permission', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(_manager(dailySales: true)),
        child: const MaterialApp(home: MorePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more_daily_sales')), findsOneWidget);
  });

  testWidgets('router redirects away from daily sales without permission',
      (tester) async {
    final container = ProviderContainer(
      overrides: seedOverrides(_manager(dailySales: false)),
    );
    addTearDown(container.dispose);
    final router = createAppRouter(
      readAuth: () => container.read(authControllerProvider),
      initialLocation: AppRoutes.dailySales,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), AppRoutes.home);
  });

  testWidgets('day chips previous next and debt filter tab', (tester) async {
    String? lastStatus;
    String? lastDate;
    final client = MockClient((request) async {
      lastDate = request.url.queryParameters['date'];
      lastStatus = request.url.queryParameters['payment_status'];
      return http.Response(
        jsonEncode(_report(date: lastDate ?? '2026-09-14', status: lastStatus ?? 'debt')),
        200,
      );
    });

    final controller = DailySalesController(
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
      initialDay: DateTime(2026, 9, 14),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._overrides(
            session: _manager(dailySales: true),
            client: client,
          ),
          dailySalesProvider.overrideWith((ref) => controller),
        ],
        child: const MaterialApp(home: DailySalesPage()),
      ),
    );
    await controller.load();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('daily_date_label')), findsOneWidget);
    expect(find.text('2026-09-14'), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily_prev_day')));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-13'), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily_next_day')));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-14'), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily_tab_debt')));
    await tester.pumpAndSettle();
    expect(lastStatus, 'debt');
    expect(find.byKey(const Key('daily_order_3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('daily_tab_paid')));
    await tester.pumpAndSettle();
    expect(lastStatus, 'paid');

    await tester.tap(find.byKey(const Key('daily_tab_partial')));
    await tester.pumpAndSettle();
    expect(lastStatus, 'partial');

    await tester.tap(find.byKey(const Key('daily_tab_all')));
    await tester.pumpAndSettle();
    expect(lastStatus, isNull);
  });

  testWidgets('daily order tap opens customer day', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/daily/customer/')) {
        return http.Response(
          jsonEncode({
            'customer': {'id': 9, 'name': 'Debtor'},
            'day_summary': {'day_standing': 'debt', 'orders_count': 1},
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
      }
      return http.Response(
        jsonEncode(_report(date: '2026-09-14')),
        200,
      );
    });

    final controller = DailySalesController(
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
      initialDay: DateTime(2026, 9, 14),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._overrides(
            session: _manager(dailySales: true),
            client: client,
          ),
          dailySalesProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const DailySalesPage(),
              ),
              GoRoute(
                path: '/daily-sales/customer/:customerId',
                builder: (_, state) => CustomerDayPage(
                  customerId: int.parse(state.pathParameters['customerId']!),
                  date: state.uri.queryParameters['date'] ?? '2026-09-14',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await controller.load();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('daily_order_3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_day_standing')), findsOneWidget);
  });
}
