import 'dart:async';
import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/customers/application/customers_controllers.dart';
import 'package:completebyte_pos_mobile/features/customers/data/customers_api.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/customer.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/customer_detail_page.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/customer_form_page.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/customer_picker_sheet.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/customers_list_page.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/receive_payment_page.dart';
import 'package:completebyte_pos_mobile/features/pos/application/pos_controllers.dart';
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

AuthSession _fullSession() {
  return AuthSession(
    user: const AuthUser(
      id: 1,
      username: 'sales',
      firstName: 'Sam',
      lastName: 'Cash',
    ),
    profile: const UserProfileSnapshot(
      role: 'cashier',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
    ),
    permissions: PermissionSet([
      const PermissionGrant(module: 'customers', action: 'view'),
      const PermissionGrant(module: 'customers', action: 'create'),
      const PermissionGrant(module: 'customers', action: 'update'),
      const PermissionGrant(module: 'debt_management', action: 'view'),
      const PermissionGrant(module: 'debt_management', action: 'update'),
      const PermissionGrant(module: 'pos', action: 'view'),
    ]),
    persona: AppPersona.cashier,
  );
}

List<Override> _base(MockClient client, {AuthSession? session}) {
  final tokens = InMemoryTokenStore();
  return [
    tokenStoreProvider.overrideWithValue(tokens),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
    authSessionSeedProvider.overrideWithValue(session ?? _fullSession()),
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

CustomersApi _api(MockClient client) {
  final tokens = InMemoryTokenStore();
  return CustomersApi(
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

void main() {
  test('domain edge parsers', () {
    final summary = CustomerSummary.fromJson({
      'id': 1,
      'name': 'X',
      'wallet_balance': '-3',
      'customer_code': 'C1',
    });
    expect(summary.standing, isNotNull);
    expect(summary.debtAmount, 3);

    final credit = CustomerDetail.fromDetailJson({
      'customer': {
        'id': 2,
        'name': 'Cred',
        'wallet_balance': '20',
        'customer_code': 'C2',
        'phone': '1',
        'email': 'a@b.c',
        'address': 'Street',
        'notes': 'n',
      },
      'standing_summary': {'standing': 'credit'},
      'orders': [
        {'id': 1, 'sale_number': 'S1', 'total': 9, 'created_at': 'd'},
        {'sale_number': 'S2', 'total': '1'},
      ],
    });
    expect(credit.creditAmount, 20);
    expect(credit.standingHeadline.contains('Credit'), isTrue);

    expect(
      CustomersModuleSettings.fromJson({
        'settings': {'enable_wallet_payment': false},
      }).enableWalletPayment,
      isFalse,
    );
    expect(CustomersModuleSettings.fromJson(null).enableCustomerCreate, isTrue);
    expect(
      const CustomersModuleSettings().canSettleDebt(hasUpdatePermission: false),
      isFalse,
    );
  });

  test('api failure branches and network errors', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');

    final throwApi = CustomersApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient((_) async => throw Exception('offline')),
      ),
    );
    expect((await throwApi.list()).isFailure, isTrue);
    expect((await throwApi.detail(1)).isFailure, isTrue);
    expect(
      (await throwApi.create(const CustomerDraft(name: 'A'))).isFailure,
      isTrue,
    );
    expect(
      (await throwApi.receiveWalletPayment(
        customerId: 1,
        amount: 1,
        paymentMethod: 'cash',
        idempotencyKey: 'k',
      )).isFailure,
      isTrue,
    );
    expect((await throwApi.loadSettings()).isSuccess, isTrue);

    var n = 0;
    final api = _api(
      MockClient((request) async {
        n++;
        if (request.url.path.contains('/detail/')) {
          if (n == 1) return http.Response('[]', 200);
          return http.Response('nope', 404);
        }
        if (request.url.path.contains('receive-wallet-payment')) {
          if (request.body.contains('"notes"')) {
            return http.Response('[]', 201);
          }
          return http.Response(jsonEncode({'error': 'bad'}), 400);
        }
        if (request.method == 'POST' || request.method == 'PUT') {
          if (n > 6) return http.Response('[]', 200);
          return http.Response(jsonEncode({'detail': 'denied'}), 403);
        }
        if (request.url.path.contains('settings/customers')) {
          return http.Response('not-json', 500);
        }
        return http.Response('[]', 200);
      }),
    );

    expect((await api.detail(1)).isFailure, isTrue);
    expect((await api.detail(1)).isFailure, isTrue);
    expect(
      (await api.create(const CustomerDraft(name: 'A'))).isFailure,
      isTrue,
    );
    expect(
      (await api.update(1, const CustomerDraft(name: 'A'))).isFailure,
      isTrue,
    );
    expect(
      (await api.receiveWalletPayment(
        customerId: 1,
        amount: 1,
        paymentMethod: 'cash',
        reference: 'r',
        notes: 'n',
        idempotencyKey: 'k2',
      )).isFailure,
      isTrue,
    );
    expect(
      (await api.receiveWalletPayment(
        customerId: 1,
        amount: 1,
        paymentMethod: 'cash',
        notes: 'n',
        idempotencyKey: 'k3',
      )).isFailure,
      isTrue,
    );
    expect((await api.loadSettings()).getOrThrow().enableWalletPayment, isTrue);
    expect(CustomersApiException('x').toString(), 'x');
  });

  test('controllers providers and receive failure', () async {
    final client = MockClient((request) async {
      if (request.url.path.contains('settings/customers')) {
        return http.Response(jsonEncode({'enable_wallet_payment': true}), 200);
      }
      if (request.url.path.contains('/detail/')) {
        return http.Response(
          jsonEncode({
            'customer': {'id': 9, 'name': 'Z', 'wallet_balance': '-5'},
            'standing_summary': {'standing': 'debt'},
            'orders': [],
          }),
          200,
        );
      }
      if (request.url.path.contains('receive-wallet-payment')) {
        return http.Response(jsonEncode({'error': 'no'}), 400);
      }
      return http.Response(jsonEncode([]), 200);
    });
    final container = ProviderContainer(overrides: _base(client));
    addTearDown(container.dispose);

    final settings = await container.read(customersSettingsProvider.future);
    expect(settings.enableWalletPayment, isTrue);
    container.read(customersListProvider);
    await container.read(customersListProvider.notifier).load();
    expect(container.read(customersListProvider).items, isEmpty);

    final api = _api(client);
    final detail = CustomerDetailController(api, ClientUuid());
    await detail.load(9);
    expect(
      await detail.receivePayment(amount: 1, paymentMethod: 'cash'),
      isFalse,
    );
    expect(detail.state.error, isNotNull);

    final empty = CustomerDetailController(api, ClientUuid());
    expect(
      await empty.receivePayment(amount: 1, paymentMethod: 'cash'),
      isFalse,
    );
  });

  testWidgets('list / form / settle / picker / rich detail', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('settings/customers')) {
        return http.Response(
          jsonEncode({
            'module': 'customers',
            'settings': {
              'enable_wallet_payment': {'value': true},
              'show_wallet_balance': {'value': true},
              'enable_customer_create': {'value': true},
              'enable_customer_edit': {'value': true},
              'allow_quick_add_at_pos': {'value': true},
            },
          }),
          200,
        );
      }
      if (request.url.path.contains('/detail/')) {
        return http.Response(
          jsonEncode({
            'customer': {
              'id': 7,
              'name': 'Debtor',
              'customer_code': 'D7',
              'phone': '0700',
              'email': 'd@x.com',
              'address': 'Nairobi',
              'wallet_balance': '-80.00',
            },
            'standing_summary': {'standing': 'debt'},
            'orders': [
              {
                'id': 1,
                'sale_number': 'S-1',
                'total': '10',
                'created_at': '2026-01-02',
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path.contains('receive-wallet-payment')) {
        return http.Response(
          jsonEncode({
            'wallet_balance': '0',
            'transaction': {'id': 1},
          }),
          201,
        );
      }
      if (request.method == 'POST' &&
          request.url.path.endsWith('/customers/')) {
        return http.Response(jsonEncode({'id': 99, 'name': 'New'}), 201);
      }
      if (request.method == 'PUT') {
        return http.Response(jsonEncode({'id': 7, 'name': 'Debtor'}), 200);
      }
      if (request.url.path.contains('/sales/customers')) {
        return http.Response(
          jsonEncode([
            {
              'id': 7,
              'name': 'Debtor',
              'phone': '0700',
              'customer_code': 'D7',
              'wallet_balance': '-80',
            },
          ]),
          200,
        );
      }
      return http.Response('{}', 200);
    });

    final router = GoRouter(
      initialLocation: '/customers',
      routes: [
        GoRoute(
          path: '/customers',
          builder: (_, _) => const CustomersListPage(),
        ),
        GoRoute(
          path: '/customers/new',
          builder: (_, _) => const CustomerFormPage(),
        ),
        GoRoute(
          path: '/customers/:id',
          builder: (_, state) => CustomerDetailPage(
            customerId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/customers/:id/edit',
          builder: (_, state) => CustomerFormPage(
            customerId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(
          path: '/customers/:id/settle',
          builder: (_, state) => ReceivePaymentPage(
            customerId: int.parse(state.pathParameters['id']!),
          ),
        ),
        GoRoute(path: '/pos', builder: (_, _) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Debtor'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('customers_search')), 'deb');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('customer_row_7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer_open_7')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_standing_hero')), findsOneWidget);
    expect(find.text('S-1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('customer_edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_form_name')), findsOneWidget);
    await tester.tap(find.byKey(const Key('customer_form_save')));
    await tester.pumpAndSettle();

    router.go('/customers/7');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer_settle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settle_amount')), findsOneWidget);
    await tester.tap(find.byKey(const Key('settle_method_card')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settle_reference')), 'ABC');
    await tester.tap(find.byKey(const Key('settle_confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settle_commit_confirm')));
    await tester.pumpAndSettle();

    router.go('/customers/new');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('customer_form_name')),
      'Fresh',
    );
    await tester.tap(find.byKey(const Key('customer_form_save')));
    await tester.pumpAndSettle();
  });

  testWidgets('detail error retry and picker sheet', (tester) async {
    var detailFails = true;
    final client = MockClient((request) async {
      if (request.url.path.contains('/detail/')) {
        if (detailFails) {
          return http.Response(jsonEncode({'error': 'gone'}), 404);
        }
        return http.Response(
          jsonEncode({
            'customer': {'id': 1, 'name': 'Ok', 'wallet_balance': '0'},
            'standing_summary': {'standing': 'good'},
            'orders': [],
          }),
          200,
        );
      }
      if (request.url.path.contains('/sales/customers')) {
        return http.Response(
          jsonEncode([
            {'id': 1, 'name': 'Ok', 'phone': '1'},
          ]),
          200,
        );
      }
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'id': 2, 'name': 'Made'}), 201);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: const MaterialApp(home: CustomerDetailPage(customerId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    detailFails = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Good standing'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const Key('open_picker'),
                    onPressed: () => showCustomerPickerSheet(context, ref),
                    child: const Text('open'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_picker')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pos_customer_search')), findsOneWidget);
    expect(find.text('Select customer'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pos_pick_customer_1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_picker')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('pos_customer_search')),
      'Made',
    );
    await tester.tap(find.byKey(const Key('pos_customer_create')));
    await tester.pumpAndSettle();
  });

  testWidgets('list empty and settle validation', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/detail/')) {
        return http.Response(
          jsonEncode({
            'customer': {'id': 3, 'name': 'A', 'wallet_balance': '-10'},
            'standing_summary': {'standing': 'debt'},
            'orders': [],
          }),
          200,
        );
      }
      return http.Response(jsonEncode([]), 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: const MaterialApp(home: CustomersListPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customers_empty')), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: const MaterialApp(home: ReceivePaymentPage(customerId: 3)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('up to 2 decimal places'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settle_method_mpesa')));
    await tester.pumpAndSettle();
    expect(find.text('Prompt payment'), findsOneWidget);
    expect(find.text('Add M-Pesa code'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settle_mpesa_capture_code')));
    await tester.pumpAndSettle();
    expect(find.text('M-Pesa code *'), findsOneWidget);
    expect(find.textContaining('At least 4 letters and numbers'), findsOneWidget);
    expect(find.byKey(const Key('settle_reference')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('settle_amount')), '0');
    await tester.ensureVisible(find.byKey(const Key('settle_confirm')));
    await tester.tap(find.byKey(const Key('settle_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('greater than zero'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('settle_amount')), '5');
    await tester.ensureVisible(find.byKey(const Key('settle_confirm')));
    await tester.tap(find.byKey(const Key('settle_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('at least 4 letters and numbers'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('settle_reference')), 'AB1');
    await tester.ensureVisible(find.byKey(const Key('settle_confirm')));
    await tester.tap(find.byKey(const Key('settle_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('you entered 3'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settle_method_card')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settle_amount')), '5');
    await tester.enterText(find.byKey(const Key('settle_reference')), '');
    await tester.ensureVisible(find.byKey(const Key('settle_confirm')));
    await tester.tap(find.byKey(const Key('settle_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('card or receipt reference'), findsOneWidget);
  });

  test('list state copyWith keeps prior error', () {
    const s = CustomersListState(error: 'prior');
    expect(s.copyWith(loading: true).error, 'prior');
    expect(s.copyWith(clearError: true).error, isNull);
  });

  testWidgets('list error retry search fab and credit chip', (tester) async {
    var listMode = 'error';
    final client = MockClient((request) async {
      if (request.url.path.contains('/sales/customers')) {
        if (listMode == 'error') {
          return http.Response(jsonEncode({'error': 'down'}), 500);
        }
        if (listMode == 'credit') {
          return http.Response(
            jsonEncode([
              {
                'id': 4,
                'name': 'Cred',
                'wallet_balance': '25',
                'customer_code': 'C4',
                'phone': '1',
              },
            ]),
            200,
          );
        }
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const CustomersListPage()),
              GoRoute(
                path: '/customers/new',
                builder: (_, _) => const CustomerFormPage(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    listMode = 'empty';
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('customers_search')), 'zzz');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('No matches'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customers_add')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_form_name')), findsOneWidget);
  });

  testWidgets('list credit standing chip', (tester) async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode([
          {
            'id': 4,
            'name': 'Cred',
            'wallet_balance': '25',
            'customer_code': 'C4',
            'phone': '1',
          },
        ]),
        200,
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: const MaterialApp(home: CustomersListPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_standing_4')), findsOneWidget);
    expect(find.textContaining('Credit 25.00'), findsOneWidget);
  });

  testWidgets('form validation failure and returnToPos', (tester) async {
    final failClient = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'error': 'create failed'}), 400);
      }
      return http.Response('{}', 200);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(failClient),
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/new',
            routes: [
              GoRoute(
                path: '/new',
                builder: (_, _) => const CustomerFormPage(returnToPos: true),
              ),
              GoRoute(path: '/pos', builder: (_, _) => const Text('POS_HOME')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('customer_form_save')));
    await tester.pumpAndSettle();
    expect(find.text('Customer name is required.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('customer_form_name')), 'Fail');
    await tester.tap(find.byKey(const Key('customer_form_save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('create failed'), findsOneWidget);

    final okClient = MockClient((request) async {
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'id': 55, 'name': 'PosCust'}), 201);
      }
      return http.Response('{}', 200);
    });
    final okContainer = ProviderContainer(overrides: _base(okClient));
    addTearDown(okContainer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: okContainer,
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: '/new',
            routes: [
              GoRoute(
                path: '/new',
                builder: (_, _) => const CustomerFormPage(returnToPos: true),
              ),
              GoRoute(path: '/pos', builder: (_, _) => const Text('POS_HOME')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('customer_form_name')),
      'PosCust',
    );
    await tester.tap(find.byKey(const Key('customer_form_save')));
    await tester.pumpAndSettle();
    expect(okContainer.read(cartControllerProvider).customerId, 55);
  });

  testWidgets('detail empty not found and settle errors', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/999/')) {
        return http.Response(jsonEncode({'error': 'gone'}), 404);
      }
      if (request.url.path.contains('/detail/')) {
        return http.Response(
          jsonEncode({
            'customer': {'id': 3, 'name': 'A', 'wallet_balance': '-10'},
            'standing_summary': {'standing': 'debt'},
            'orders': [],
          }),
          200,
        );
      }
      if (request.url.path.contains('receive-wallet-payment')) {
        return http.Response(jsonEncode({'error': 'rejected'}), 400);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ..._base(client),
          customerDetailProvider(42).overrideWith((ref) {
            return CustomerDetailController(_api(client), ClientUuid());
          }),
        ],
        child: const MaterialApp(home: CustomerDetailPage(customerId: 42)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Customer not found'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
  });

  testWidgets('settle unavailable and payment rejected snackbar', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/999/')) {
        return http.Response(jsonEncode({'error': 'gone'}), 404);
      }
      if (request.url.path.contains('/detail/')) {
        return http.Response(
          jsonEncode({
            'customer': {'id': 3, 'name': 'A', 'wallet_balance': '-10'},
            'standing_summary': {'standing': 'debt'},
            'orders': [],
          }),
          200,
        );
      }
      if (request.url.path.contains('receive-wallet-payment')) {
        return http.Response(jsonEncode({'error': 'rejected'}), 400);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: const MaterialApp(home: ReceivePaymentPage(customerId: 999)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: const MaterialApp(home: ReceivePaymentPage(customerId: 3)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('settle_amount')), '');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('settle_amount')), '4');
    await tester.tap(find.byKey(const Key('settle_confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settle_commit_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('rejected'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settle_method_mpesa')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settle_mpesa_capture_prompt')), findsOneWidget);
    expect(find.byKey(const Key('settle_mpesa_capture_code')), findsOneWidget);
  });

  testWidgets('picker failure empty create and create error', (tester) async {
    var listMode = 'error';
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/customers/')) {
        return http.Response(jsonEncode({'error': 'create failed'}), 400);
      }
      if (request.url.path.contains('/sales/customers')) {
        if (listMode == 'error') {
          return http.Response(jsonEncode({'error': 'down'}), 500);
        }
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp.router(
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (context, _) => Scaffold(
                      body: TextButton(
                        key: const Key('open_picker2'),
                        onPressed: () => showCustomerPickerSheet(context, ref),
                        child: const Text('open'),
                      ),
                    ),
                  ),
                  GoRoute(
                    path: '/customers/new',
                    builder: (_, _) =>
                        const CustomerFormPage(returnToPos: true),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_picker2')));
    await tester.pumpAndSettle();
    expect(find.textContaining('down'), findsOneWidget);
    listMode = 'empty';
    await tester.tap(find.byKey(const Key('pos_customer_create')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_form_name')), findsOneWidget);
  });

  testWidgets('picker empty list and named create failure', (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'POST' &&
          request.url.path.endsWith('/customers/')) {
        return http.Response(jsonEncode({'error': 'create failed'}), 400);
      }
      if (request.url.path.contains('/sales/customers')) {
        return http.Response(jsonEncode([]), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const Key('open_picker3'),
                    onPressed: () => showCustomerPickerSheet(context, ref),
                    child: const Text('open'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_picker3')));
    await tester.pumpAndSettle();
    expect(find.text('No customers yet'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('pos_customer_search')),
      'Nope',
    );
    await tester.pump();
    expect(find.textContaining('No match for'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pos_customer_create')));
    await tester.pumpAndSettle();
    expect(find.textContaining('create failed'), findsOneWidget);
  });

  testWidgets('edit form shows loading then fields', (tester) async {
    final completer = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path.contains('/detail/')) {
        return completer.future;
      }
      if (request.method == 'PUT') {
        return http.Response(jsonEncode({'id': 7, 'name': 'Debtor'}), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: const MaterialApp(home: CustomerFormPage(customerId: 7)),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    completer.complete(
      http.Response(
        jsonEncode({
          'customer': {
            'id': 7,
            'name': 'Debtor',
            'wallet_balance': '0',
            'notes': 'hi',
          },
          'standing_summary': {'standing': 'good'},
          'orders': [],
        }),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_form_name')), findsOneWidget);
  });

  testWidgets('picker loads more customers when the first page ends', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (!request.url.path.contains('/sales/customers')) {
        return http.Response('{}', 200);
      }
      final page = request.url.queryParameters['page'] ?? '1';
      if (page == '1') {
        return http.Response(
          jsonEncode({
            'count': 2,
            'next': 'http://example.com/api/sales/customers/?page=2',
            'results': [
              {'id': 1, 'name': 'Ann Alpha', 'phone': '0700'},
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'count': 2,
          'next': null,
          'results': [
            {'id': 2, 'name': 'Zed Zulu', 'phone': '0701'},
          ],
        }),
        200,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _base(client),
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    key: const Key('open_picker_pages'),
                    onPressed: () => showCustomerPickerSheet(context, ref),
                    child: const Text('open'),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_picker_pages')));
    await tester.pumpAndSettle();

    expect(find.text('Select customer'), findsOneWidget);
    expect(find.text('Ann Alpha'), findsOneWidget);
    expect(find.text('Zed Zulu'), findsOneWidget);
  });
}
