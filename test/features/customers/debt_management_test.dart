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
import 'package:completebyte_pos_mobile/features/customers/application/customers_controllers.dart';
import 'package:completebyte_pos_mobile/features/customers/application/debt_management_controller.dart';
import 'package:completebyte_pos_mobile/features/customers/data/debt_management_api.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/customer.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/debt_management.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/wallet_debt.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/customer_detail_page.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/debt_collection_list.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/debt_management_page.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/receive_payment_page.dart';
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

Map<String, dynamic> _summaryJson() => {
  'customers_with_debt': 2,
  'total_debt': '150.00',
  'average_debt': '75.00',
  'collected_today': '40.00',
  'aging': {
    '0_7': {'count': 1, 'amount': '50.00'},
    '8_30': {'count': 1, 'amount': '100.00'},
    '31_60': {'count': 0, 'amount': '0.00'},
    '60_plus': {'count': 0, 'amount': '0.00'},
  },
};

Map<String, dynamic> _debtorJson({
  int id = 7,
  String name = 'Debtor Shop',
  String debt = '80.00',
  String bucket = '0_7',
}) => {
  'id': id,
  'name': name,
  'phone': '0700123456',
  'customer_code': 'D$id',
  'wallet_balance': '-$debt',
  'debt_amount': debt,
  'debt_age_days': 3,
  'aging_bucket': bucket,
  'last_sale_at': '2026-09-10T10:00:00Z',
  'last_payment_at': null,
};

Map<String, dynamic> _collectionJson({
  int id = 44,
  String amount = '40.00',
  String balanceAfter = '-40.00',
}) => {
  'id': id,
  'customer_id': 7,
  'customer_name': 'Debtor Shop',
  'customer_phone': '0700123456',
  'customer_code': 'D7',
  'amount': amount,
  'balance_after': balanceAfter,
  'reference': 'MPESA',
  'notes': 'Partial',
  'sale_number': null,
  'received_by': 'Col Lect',
  'created_at': '2026-09-23T10:15:00Z',
};

Map<String, dynamic> _collectionsJson({
  String date = '2026-09-23',
  List<Map<String, dynamic>>? results,
}) {
  final rows = results ?? [_collectionJson()];
  return {
    'date': date,
    'count': rows.length,
    'total': rows.fold<double>(
      0,
      (sum, row) => sum + double.parse(row['amount'].toString()),
    ).toStringAsFixed(2),
    'results': rows,
  };
}

AuthSession _debtSession({bool canUpdate = true, bool canView = true}) {
  return AuthSession(
    user: const AuthUser(
      id: 1,
      username: 'collector',
      firstName: 'Col',
      lastName: 'Lect',
    ),
    profile: const UserProfileSnapshot(
      role: 'cashier',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
    ),
    permissions: PermissionSet([
      const PermissionGrant(module: 'customers', action: 'view'),
      if (canView)
        const PermissionGrant(module: 'debt_management', action: 'view'),
      if (canUpdate)
        const PermissionGrant(module: 'debt_management', action: 'update'),
    ]),
    persona: AppPersona.cashier,
  );
}

List<Override> _overrides({
  required AuthSession session,
  required MockClient httpClient,
}) {
  final tokens = InMemoryTokenStore();
  return [
    tokenStoreProvider.overrideWithValue(tokens),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
    authSessionSeedProvider.overrideWithValue(session),
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
    customersSettingsProvider.overrideWith(
      (ref) async => const CustomersModuleSettings(),
    ),
  ];
}

MockClient _debtHttpClient({
  Map<String, dynamic>? summary,
  List<Map<String, dynamic>>? debtors,
  int debtorsStatus = 200,
  bool settleOk = true,
}) {
  return MockClient((request) async {
    final path = request.url.path;
    if (path.contains('settings/customers')) {
      return http.Response(
        jsonEncode({
          'module': 'customers',
          'settings': {
            'enable_wallet_payment': {'value': true},
            'show_wallet_balance': {'value': true},
          },
        }),
        200,
      );
    }
    if (path.contains('debt-summary')) {
      return http.Response(jsonEncode(summary ?? _summaryJson()), 200);
    }
    if (path.contains('debt-collections')) {
      return http.Response(jsonEncode(_collectionsJson()), 200);
    }
    if (path.contains('debtors')) {
      return http.Response(
        jsonEncode({
          'count': (debtors ?? [_debtorJson()]).length,
          'results': debtors ?? [_debtorJson()],
        }),
        debtorsStatus,
      );
    }
    if (path.contains('/detail/')) {
      return http.Response(
        jsonEncode({
          'customer': {
            'id': 7,
            'name': 'Debtor Shop',
            'phone': '0700123456',
            'wallet_balance': '-80.00',
          },
          'standing_summary': {'standing': 'debt'},
          'orders': <dynamic>[],
          'ledger': <dynamic>[],
        }),
        200,
      );
    }
    if (path.contains('receive-wallet-payment')) {
      if (!settleOk) {
        return http.Response(jsonEncode({'error': 'Rejected'}), 400);
      }
      return http.Response(
        jsonEncode({
          'wallet_balance': '0',
          'transaction': {'id': 11},
        }),
        201,
      );
    }
    return http.Response('{}', 200);
  });
}

void main() {
  group('DebtManagement domain', () {
    test('parses summary and debtor rows', () {
      final summary = DebtSummary.fromJson(_summaryJson());
      expect(summary.customersWithDebt, 2);
      expect(summary.totalDebt, 150);
      expect(summary.collectedToday, 40);
      expect(summary.aging['8_30']?.count, 1);
      expect(summary.aging['8_30']?.amount, 100);

      final row = DebtorRow.fromJson(_debtorJson());
      expect(row.id, 7);
      expect(row.debtAmount, 80);
      expect(row.standing, CustomerStanding.debt);
      expect(row.agingLabel, '0–7 days');
    });

    test('parses collections remaining vs settled', () {
      final remaining = DebtCollectionRow.fromJson(_collectionJson());
      expect(remaining.stillOwes, isTrue);
      expect(remaining.remainingDebt, 40);
      expect(remaining.remainingLabel, 'Remains');
      expect(remaining.subtitle, contains('0700123456'));

      final settled = DebtCollectionRow.fromJson(
        _collectionJson(balanceAfter: '5.00'),
      );
      expect(settled.stillOwes, isFalse);
      expect(settled.remainingDebt, 0);
      expect(settled.remainingLabel, 'Settled');

      final payload = DebtCollections.fromJson(_collectionsJson());
      expect(payload.count, 1);
      expect(payload.results.single.amount, 40);
      expect(shiftDateString('2026-09-23', -1), '2026-09-22');
      expect(localDateString(DateTime(2026, 9, 23, 15, 4)), '2026-09-23');
      expect(formatCollectionTime(''), '');
      expect(formatCollectionTime('not-a-date'), 'not-a-date');
      expect(formatCollectionTime('2026-09-23T10:15:00Z'), contains(':'));
      expect(formatCollectionDateLabel(localDateString()), 'Today');
      expect(
        formatCollectionDateLabel(shiftDateString(localDateString(), -1)),
        'Yesterday',
      );
      expect(formatCollectionDateLabel('2026-01-01'), '2026-01-01');
      expect(DebtCollections.fromJson(const {}).results, isEmpty);
      expect(shiftDateString('not-a-date', 1), localDateString());
    });

    test('handles missing aging map', () {
      final summary = DebtSummary.fromJson({
        'customers_with_debt': 0,
        'total_debt': 0,
      });
      expect(summary.aging, isEmpty);
      expect(DebtAgingBucket.fromJson(null).count, 0);
    });
  });

  testWidgets('collections panel empty error settled and date nav', (
    tester,
  ) async {
    var retried = false;
    var jumped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              DebtCollectionsPanel(
                date: '2026-01-01',
                collections: const DebtCollections(),
                loading: false,
                error: 'Could not read collections.',
                onRetry: () => retried = true,
                onPreviousDay: () {},
                onNextDay: () {},
                onJumpToday: () => jumped = true,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not read collections.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    await tester.tap(find.byKey(const Key('debt_collections_today')));
    expect(jumped, isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DebtCollectionsPanel(
            date: localDateString(),
            collections: const DebtCollections(count: 0, total: 0, results: []),
            loading: false,
            showDateNav: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('No collections on this day'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DebtCollectionsPanel(
            date: localDateString(),
            collections: DebtCollections.fromJson(
              _collectionsJson(
                date: localDateString(),
                results: [_collectionJson(balanceAfter: '0.00')],
              ),
            ),
            loading: false,
            onOpenCustomer: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Settled'), findsOneWidget);
    expect(find.textContaining('Received by'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DebtCollectionsPanel(
            date: '2026-09-23',
            collections: null,
            loading: true,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('DebtManagementApi', () {
    late InMemoryTokenStore tokens;

    setUp(() async {
      tokens = InMemoryTokenStore();
      await tokens.writeTokens(access: 'a', refresh: 'r');
    });

    DebtManagementApi apiWith(MockClient client) {
      return DebtManagementApi(
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

    test('fetchSummary and listDebtors map payloads', () async {
      String? search;
      String? bucket;
      final api = apiWith(
        MockClient((request) async {
          if (request.url.path.contains('debt-summary')) {
            return http.Response(jsonEncode(_summaryJson()), 200);
          }
          search = request.url.queryParameters['search'];
          bucket = request.url.queryParameters['aging_bucket'];
          return http.Response(
            jsonEncode({
              'count': 1,
              'results': [_debtorJson()],
            }),
            200,
          );
        }),
      );

      final summary = (await api.fetchSummary()).getOrThrow();
      expect(summary.totalDebt, 150);

      final rows = (await api.listDebtors(
        search: 'shop',
        agingBucket: '0_7',
      )).getOrThrow();
      expect(search, 'shop');
      expect(bucket, '0_7');
      expect(rows.single.name, 'Debtor Shop');
    });

    test('returns failure on error status', () async {
      final api = apiWith(
        MockClient(
          (_) async => http.Response(jsonEncode({'error': 'Nope'}), 403),
        ),
      );
      expect((await api.fetchSummary()).isFailure, isTrue);
      expect((await api.listDebtors()).isFailure, isTrue);
      expect(
        (await api.listCollections(date: '2026-09-23')).isFailure,
        isTrue,
      );
    });

    test('listCollections maps who paid and remaining', () async {
      String? queriedDate;
      final api = apiWith(
        MockClient((request) async {
          queriedDate = request.url.queryParameters['date'];
          expect(request.url.path, contains('debt-collections'));
          return http.Response(jsonEncode(_collectionsJson()), 200);
        }),
      );
      final payload = (await api.listCollections(date: '2026-09-23'))
          .getOrThrow();
      expect(queriedDate, '2026-09-23');
      expect(payload.results.single.customerName, 'Debtor Shop');
      expect(payload.results.single.stillOwes, isTrue);
      expect(payload.results.single.remainingDebt, 40);
    });

    test('listCollections rejects non-object payloads', () async {
      final api = apiWith(
        MockClient((_) async => http.Response('[]', 200)),
      );
      expect(
        (await api.listCollections(date: '2026-09-23')).isFailure,
        isTrue,
      );
    });
  });

  group('DebtManagementController', () {
    test('load search and aging bucket', () async {
      var lastSearch = '';
      var lastBucket = '';
      final client = MockClient((request) async {
        if (request.url.path.contains('debt-summary')) {
          return http.Response(jsonEncode(_summaryJson()), 200);
        }
        lastSearch = request.url.queryParameters['search'] ?? '';
        lastBucket = request.url.queryParameters['aging_bucket'] ?? '';
        return http.Response(
          jsonEncode({
            'results': [
              _debtorJson(
                name: lastSearch.isEmpty ? 'All' : 'Filtered',
                bucket: lastBucket.isEmpty ? '0_7' : lastBucket,
              ),
            ],
          }),
          200,
        );
      });

      final container = ProviderContainer(
        overrides: _overrides(
          session: _debtSession(),
          httpClient: client,
        ),
      );
      addTearDown(container.dispose);

      final notifier = container.read(debtManagementControllerProvider.notifier);
      await notifier.load();
      var state = container.read(debtManagementControllerProvider);
      expect(state.loading, isFalse);
      expect(state.summary?.customersWithDebt, 2);
      expect(state.debtors, isNotEmpty);
      expect(state.error, isNull);

      await notifier.setSearch('Ada');
      expect(lastSearch, 'Ada');
      state = container.read(debtManagementControllerProvider);
      expect(state.search, 'Ada');
      expect(state.debtors.single.name, 'Filtered');

      await notifier.setAgingBucket('8_30');
      expect(lastBucket, '8_30');
      expect(
        container.read(debtManagementControllerProvider).agingBucket,
        '8_30',
      );
    });

    test('openCollections loads who paid and remaining', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('debt-summary')) {
          return http.Response(jsonEncode(_summaryJson()), 200);
        }
        if (request.url.path.contains('debt-collections')) {
          return http.Response(
            jsonEncode(
              _collectionsJson(date: request.url.queryParameters['date'] ?? ''),
            ),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'results': [_debtorJson()],
          }),
          200,
        );
      });
      final container = ProviderContainer(
        overrides: _overrides(session: _debtSession(), httpClient: client),
      );
      addTearDown(container.dispose);
      final notifier = container.read(debtManagementControllerProvider.notifier);
      await notifier.load();
      await notifier.openCollections(date: '2026-09-23');
      var state = container.read(debtManagementControllerProvider);
      expect(state.showCollections, isTrue);
      expect(state.collections?.results.single.customerName, 'Debtor Shop');
      expect(state.collections?.results.single.remainingDebt, 40);

      await notifier.shiftCollectionDate(-1);
      expect(
        container.read(debtManagementControllerProvider).collectionDate,
        '2026-09-22',
      );
      await notifier.jumpCollectionDateToToday();
      expect(
        container.read(debtManagementControllerProvider).collectionDate,
        localDateString(),
      );
      await notifier.shiftCollectionDate(1);
      expect(
        container.read(debtManagementControllerProvider).collectionDate,
        localDateString(),
      );
      notifier.closeCollections();
      expect(
        container.read(debtManagementControllerProvider).showCollections,
        isFalse,
      );
    });

    test('loadCollections surfaces API errors', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('debt-summary')) {
          return http.Response(jsonEncode(_summaryJson()), 200);
        }
        if (request.url.path.contains('debt-collections')) {
          return http.Response(jsonEncode({'error': 'Nope'}), 500);
        }
        return http.Response(
          jsonEncode({
            'results': [_debtorJson()],
          }),
          200,
        );
      });
      final container = ProviderContainer(
        overrides: _overrides(session: _debtSession(), httpClient: client),
      );
      addTearDown(container.dispose);
      final notifier = container.read(debtManagementControllerProvider.notifier);
      await notifier.openCollections(date: '2026-09-23');
      expect(
        container.read(debtManagementControllerProvider).collectionsError,
        isNotNull,
      );
    });

    test('surfaces error when debtors fail', () async {
      final client = MockClient((request) async {
        if (request.url.path.contains('debt-summary')) {
          return http.Response(jsonEncode(_summaryJson()), 200);
        }
        return http.Response(jsonEncode({'error': 'Blocked'}), 500);
      });
      final container = ProviderContainer(
        overrides: _overrides(
          session: _debtSession(),
          httpClient: client,
        ),
      );
      addTearDown(container.dispose);

      await container.read(debtManagementControllerProvider.notifier).load();
      final state = container.read(debtManagementControllerProvider);
      expect(state.error, isNotNull);
      expect(state.summary?.totalDebt, 150);
    });
  });

  group('DebtManagement UI', () {
    testWidgets('More shows Debtors when permitted', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: seedOverrides(cashierSession()),
          child: const MaterialApp(home: MorePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('more_debtors')), findsOneWidget);
    });

    testWidgets('More hides Debtors without view permission', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: seedOverrides(salesSession()),
          child: const MaterialApp(home: MorePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('more_debtors')), findsNothing);
    });

    testWidgets('router redirects away from debtors without permission', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: seedOverrides(salesSession()),
      );
      addTearDown(container.dispose);
      final router = createAppRouter(
        readAuth: () => container.read(authControllerProvider),
        initialLocation: AppRoutes.debtors,
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

    testWidgets('lists debtors and Collect opens settle', (tester) async {
      final client = _debtHttpClient();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(
            session: _debtSession(),
            httpClient: client,
          ),
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/debtors',
              routes: [
                GoRoute(
                  path: '/debtors',
                  builder: (_, _) => const DebtManagementPage(),
                ),
                GoRoute(
                  path: '/customers/:id/settle',
                  builder: (context, state) {
                    final id =
                        int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                    return ReceivePaymentPage(customerId: id);
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_stat_count')), findsOneWidget);
      expect(find.byKey(const Key('debtor_row_7')), findsOneWidget);
      expect(find.byKey(const Key('debtor_amount_7')), findsOneWidget);
      expect(find.text('Debtor Shop'), findsOneWidget);
      expect(find.byKey(const Key('debtor_collect_7')), findsOneWidget);

      await tester.tap(find.byKey(const Key('debtor_collect_7')));
      await tester.pumpAndSettle();

      expect(find.byType(ReceivePaymentPage), findsOneWidget);
      expect(find.byKey(const Key('settle_amount')), findsOneWidget);
      expect(find.text('Collect payment'), findsOneWidget);

      await tester.tap(find.byKey(const Key('settle_confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Proceed with this payment?'), findsOneWidget);
      expect(
        find.textContaining('Do you really want to continue with this transaction'),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('settle_commit_cancel')));
      await tester.pumpAndSettle();
      expect(find.byType(ReceivePaymentPage), findsOneWidget);

      await tester.tap(find.byKey(const Key('settle_confirm')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settle_commit_confirm')));
      await tester.pumpAndSettle();
      expect(find.byType(DebtManagementPage), findsOneWidget);
    });

    testWidgets('Collected today opens who paid amount and remaining', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(
            session: _debtSession(),
            httpClient: _debtHttpClient(),
          ),
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/debtors',
              routes: [
                GoRoute(
                  path: '/debtors',
                  builder: (_, _) => const DebtManagementPage(),
                ),
                GoRoute(
                  path: '/customers/:id',
                  builder: (context, state) {
                    final id =
                        int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                    return CustomerDetailPage(
                      customerId: id,
                      initialTab: state.uri.queryParameters['tab'],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('debt_stat_collected')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('debt_collections_panel')), findsOneWidget);
      expect(find.byKey(const Key('collection_row_44')), findsOneWidget);
      expect(find.byKey(const Key('collection_amount_44')), findsOneWidget);
      expect(find.text('KES 40.00'), findsWidgets);
      expect(find.textContaining('Remains'), findsOneWidget);
      expect(find.text('Debtor Shop'), findsWidgets);

      await tester.tap(find.byKey(const Key('collection_customer_44')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('customer_tab_ledger')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('debt_collections_close')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debt_collections_panel')), findsNothing);
    });

    testWidgets('hides Collect without update permission', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(
            session: _debtSession(canUpdate: false),
            httpClient: _debtHttpClient(),
          ),
          child: const MaterialApp(home: DebtManagementPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('debtor_row_7')), findsOneWidget);
      expect(find.byKey(const Key('debtor_collect_7')), findsNothing);
      expect(find.byKey(const Key('debtor_history_7')), findsOneWidget);
    });

    testWidgets('empty debtors and aging filter', (tester) async {
      final client = _debtHttpClient(debtors: const []);
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(
            session: _debtSession(),
            httpClient: client,
          ),
          child: const MaterialApp(home: DebtManagementPage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No customers with debt'), findsOneWidget);

      await tester.tap(find.byKey(const Key('debt_aging_8_30')));
      await tester.pumpAndSettle();
    });

    testWidgets('settle validates amount greater than zero', (tester) async {
      final client = _debtHttpClient();
      await tester.pumpWidget(
        ProviderScope(
          overrides: _overrides(
            session: _debtSession(),
            httpClient: client,
          ),
          child: const MaterialApp(
            home: ReceivePaymentPage(customerId: 7),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('settle_amount')), '0');
      await tester.tap(find.byKey(const Key('settle_confirm')));
      await tester.pump();
      expect(find.textContaining('greater than zero'), findsOneWidget);
      expect(find.byType(ReceivePaymentPage), findsOneWidget);
    });
  });
}
