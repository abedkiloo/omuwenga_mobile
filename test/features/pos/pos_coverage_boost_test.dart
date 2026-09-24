import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/pos/application/pos_controllers.dart';
import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/payment.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/pos_page.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_page.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

List<Override> overrides({
  required MockClient client,
  PosSettings settings = const PosSettings(),
  FakeConnectivityMonitor? connectivity,
  PosApi? api,
}) {
  final tokens = InMemoryTokenStore();
  return [
    tokenStoreProvider.overrideWithValue(tokens),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
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
      connectivity ?? FakeConnectivityMonitor(online: true),
    ),
    if (api != null) posApiProvider.overrideWithValue(api),
    posSettingsProvider.overrideWith((ref) async {
      if (api != null) {
        final r = await api.loadSettings();
        return r.when(
          success: (s) => s,
          failure: (_, _) => const PosSettings(),
        );
      }
      return settings;
    }),
  ];
}

void main() {
  test('cart controller and payment labels', () {
    final c = CartController();
    const p = CatalogProduct(id: 1, name: 'A', price: 10, sku: 'A1');
    c.addProduct(p);
    c.setQuantity('1', 2);
    expect(c.state.total, 20);
    expect(c.state.itemCount, 2);
    c.attachCustomer(id: 3, name: 'Ada');
    expect(c.state.customerName, 'Ada');
    c.clearCustomer();
    c.removeProduct('1');
    c.clear();
    expect(c.state.isEmpty, isTrue);
    expect(PosPaymentMethod.other.label, 'Other');
    expect(PosPaymentMethod.mpesa.label, 'M-Pesa');
  });

  test('pos api edge branches', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    var n = 0;
    final api = PosApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          n++;
          if (request.url.path.contains('search')) {
            if (n == 1) return http.Response('boom', 500);
            return http.Response('{}', 200);
          }
          if (request.url.path.contains('settings/sales')) {
            return http.Response(jsonEncode({'require_customer': false}), 200);
          }
          if (request.url.path.contains('store-settings')) {
            return http.Response(
              jsonEncode({
                'enabled_payment_methods': ['cash', 'mpesa'],
              }),
              200,
            );
          }
          if (request.method == 'POST') {
            return http.Response('{"detail":"no"}', 422);
          }
          return http.Response('x', 500);
        }),
      ),
    );
    expect((await api.searchProducts('')).isSuccess, isTrue);
    expect((await api.searchProducts('x')).isFailure, isTrue);
    expect((await api.searchProducts('y')).isSuccess, isTrue);
    final settings = (await api.loadSettings()).getOrThrow();
    expect(settings.enabledPaymentMethods, contains(PosPaymentMethod.cash));

    final cart = const PosCart().addProduct(
      const CatalogProduct(id: 1, name: 'A', price: 10),
    );
    expect(
      (await api.createSale(
        cart: cart,
        draft: const CheckoutDraft(
          method: PosPaymentMethod.mpesa,
          amountPaid: 10,
          paymentReference: 'QHX7K2L9M1',
        ),
        idempotencyKey: 'k',
      )).isFailure,
      isTrue,
    );
  });

  test('checkout validation error and settings provider fallback', () async {
    final failing = _FailingSettingsApi();
    final tokens = InMemoryTokenStore();
    final client = MockClient((_) async => http.Response('{}', 200));
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(
          const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
        ),
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
          FakeConnectivityMonitor(),
        ),
        posApiProvider.overrideWithValue(failing),
        // do not override posSettingsProvider — exercise failure → defaults
      ],
    );
    addTearDown(container.dispose);
    final settings = await container.read(posSettingsProvider.future);
    expect(settings.enabledPaymentMethods, isNotEmpty);
    expect(
      await container.read(checkoutControllerProvider.notifier).submit(),
      isFalse,
    );
  });

  test('api createSale transport and unexpected body', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    var n = 0;
    final api = PosApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          n++;
          if (n == 1) throw Exception('socket');
          if (n == 2) return http.Response('[]', 201);
          if (n == 3) return http.Response('{"error":"server"}', 500);
          throw Exception('settings boom');
        }),
      ),
    );
    final cart = const PosCart().addProduct(
      const CatalogProduct(id: 1, name: 'A', price: 10),
    );
    final draft = const CheckoutDraft(
      method: PosPaymentMethod.cash,
      amountPaid: 10,
    );
    expect(
      (await api.createSale(
        cart: cart,
        draft: draft,
        idempotencyKey: 'a',
      )).isFailure,
      isTrue,
    );
    expect(
      (await api.createSale(
        cart: cart,
        draft: draft,
        idempotencyKey: 'b',
      )).isFailure,
      isTrue,
    );
    expect(
      (await api.createSale(
        cart: cart,
        draft: draft,
        idempotencyKey: 'c',
      )).isFailure,
      isTrue,
    );

    final settingsApi = PosApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient((_) async => http.Response('{not-json', 200)),
      ),
    );
    expect((await settingsApi.loadSettings()).isFailure, isTrue);
    expect(
      const CartLine(
        productId: 1,
        name: 'A',
        unitPrice: 1,
        quantity: 1,
      ).copyWith(unitPrice: 2).unitPrice,
      2,
    );
  });

  test('offline enqueue includes payment reference', () async {
    final outbox = MemoryOutboxStore();
    final connectivity = FakeConnectivityMonitor(online: false);
    final tokens = InMemoryTokenStore();
    final client = MockClient((_) async => http.Response('{}', 200));
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(
          const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
        ),
        httpClientProvider.overrideWithValue(client),
        apiClientProvider.overrideWith((ref) {
          return ApiClient(
            env: ref.watch(appEnvProvider),
            tokenStore: tokens,
            httpClient: client,
          );
        }),
        outboxStoreProvider.overrideWithValue(outbox),
        connectivityMonitorProvider.overrideWithValue(connectivity),
        posSettingsProvider.overrideWith((ref) async => const PosSettings()),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await outbox.dispose();
      connectivity.dispose();
    });
    container
        .read(cartControllerProvider.notifier)
        .addProduct(const CatalogProduct(id: 1, name: 'A', price: 10));
    container
        .read(checkoutControllerProvider.notifier)
        .setDraft(
          const CheckoutDraft(
            method: PosPaymentMethod.mpesa,
            amountPaid: 10,
            paymentReference: 'REF1',
          ),
        );
    expect(
      await container.read(checkoutControllerProvider.notifier).submit(),
      isTrue,
    );
    final pending = await outbox.listPending();
    expect(pending.single.bodyJson, contains('REF1'));
  });

  testWidgets('success pay opens receipt; qty and mpesa ref', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/products/') &&
          !request.url.path.contains('/search/') &&
          !request.url.path.contains('/variants/')) {
        final q = request.url.queryParameters['search'] ?? '';
        final rows = [
          {'id': 5, 'name': 'Nail', 'selling_price': 20, 'stock_quantity': 5},
        ];
        if (q.isNotEmpty &&
            !q.toLowerCase().contains('nail') &&
            q != '12345678') {
          return http.Response(
            jsonEncode({
              'count': 0,
              'next': null,
              'previous': null,
              'results': [],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'count': 1,
            'next': null,
            'previous': null,
            'results': rows,
          }),
          200,
        );
      }
      if (request.url.path.contains('/products/search/')) {
        return http.Response(
          jsonEncode([
            {'id': 5, 'name': 'Nail', 'selling_price': 20, 'stock_quantity': 5},
          ]),
          200,
        );
      }
      if (request.url.path.endsWith('/sales/')) {
        return http.Response(
          jsonEncode({
            'id': 7,
            'sale_number': 'S-7',
            'total': 40,
            'payment_method': 'mpesa',
            'amount_paid': 40,
            'change': 0,
            'items': [
              {
                'product_id': 5,
                'product_name': 'Nail',
                'quantity': 2,
                'unit_price': 20,
              },
            ],
          }),
          201,
        );
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(client: client),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_product_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_inc_5')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_method_cash')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('pos_confirm_pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_confirm_pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_review_cart')));
    await tester.pumpAndSettle();
    expect(find.text('Active Cart Items'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pos_pay')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('pos_confirm_pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_confirm_pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_close_sale_confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt_title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('receipt_done')));
    await tester.pumpAndSettle();
  });

  testWidgets('require customer banner and leave dialog', (tester) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(
          client: MockClient((_) async => http.Response('[]', 200)),
          settings: const PosSettings(requireCustomer: true),
        ),
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const PosPage();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    widgetRef
        .read(cartControllerProvider.notifier)
        .addProduct(const CatalogProduct(id: 1, name: 'X', price: 1));
    await tester.pumpAndSettle();
    expect(find.textContaining('Customer required'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave sale?'), findsOneWidget);
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
  });

  testWidgets('decrement qty and empty search clears', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/products/') &&
          !request.url.path.contains('/variants/')) {
        return http.Response(
          jsonEncode({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [
              {
                'id': 3,
                'name': 'Bolt',
                'selling_price': 5,
                'stock_quantity': 3,
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path.contains('/products/search/')) {
        return http.Response(
          jsonEncode([
            {'id': 3, 'name': 'Bolt', 'selling_price': 5, 'stock_quantity': 3},
          ]),
          200,
        );
      }
      return http.Response('{}', 200);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(client: client),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_product_3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_inc_3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_dec_3')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pos_search')), '');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pos_cart_icon')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pos_clear_cart')));
    await tester.pumpAndSettle();
    expect(find.text('Clear current sale?'), findsOneWidget);
    await tester.tap(find.text('Keep sale'));
    await tester.pumpAndSettle();
    expect(find.text('Active Cart Items'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pos_clear_cart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_clear_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Active Cart Items'), findsNothing);
  });

  testWidgets('customer attached label', (tester) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(
          client: MockClient((_) async => http.Response('[]', 200)),
          settings: const PosSettings(requireCustomer: true),
        ),
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const PosPage();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    widgetRef.read(cartControllerProvider.notifier)
      ..addProduct(const CatalogProduct(id: 1, name: 'X', price: 1))
      ..attachCustomer(id: 2, name: 'Ada');
    await tester.pumpAndSettle();
    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('CUSTOMER'), findsOneWidget);
  });

  testWidgets('offline pay shows queued receipt', (tester) async {
    final connectivity = FakeConnectivityMonitor(online: false);
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(
          client: MockClient((_) async => http.Response('{}', 200)),
          connectivity: connectivity,
        ),
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const PosPage();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    widgetRef
        .read(cartControllerProvider.notifier)
        .addProduct(const CatalogProduct(id: 1, name: 'A', price: 10));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_pay')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('pos_confirm_pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_confirm_pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_close_sale_confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('waiting to sync'), findsOneWidget);
  });

  testWidgets('pay sheet back returns to pos; pay later records debt', (
    tester,
  ) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(
          client: MockClient((request) async {
            if (request.method == 'POST' &&
                request.url.path.contains('/sales/')) {
              final body = jsonDecode(request.body) as Map;
              expect(body['allow_partial_payment'], isTrue);
              expect(body['amount_paid'], 0);
              expect(body['customer_id'], 9);
              return http.Response(
                jsonEncode({
                  'id': 8,
                  'sale_number': 'S-8',
                  'total': 10,
                  'payment_method': 'cash',
                  'amount_paid': 0,
                  'change': 0,
                  'items': [],
                }),
                201,
              );
            }
            return http.Response('[]', 200);
          }),
          settings: const PosSettings(allowPartialPayment: true),
        ),
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const PosPage();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    widgetRef.read(cartControllerProvider.notifier)
      ..addProduct(const CatalogProduct(id: 1, name: 'A', price: 10))
      ..attachCustomer(id: 9, name: 'Ada');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_pay')));
    await tester.pumpAndSettle();
    expect(find.text('Checkout & Tender'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pos_pay_back')));
    await tester.pumpAndSettle();
    expect(find.text('Active Cart Items'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pos_pay')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('pos_payment_on_account')));
    await tester.tap(find.byKey(const Key('pos_payment_on_account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_pay_later')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pay later'), findsWidgets);
    await tester.ensureVisible(find.byKey(const Key('pos_confirm_pay')));
    await tester.tap(find.byKey(const Key('pos_confirm_pay')));
    await tester.pumpAndSettle();
    expect(find.text('Record full amount as pay later?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pos_close_sale_confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('receipt_title')), findsOneWidget);
  });

  testWidgets('search failure shows error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(
          client: MockClient((_) async => throw Exception('network')),
        ),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pos_search')), 'failme');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.textContaining('network'), findsOneWidget);
  });

  testWidgets('queued receipt two lines', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptPage(
          receipt: SaleReceipt(
            id: null,
            saleNumber: 'QUEUED',
            total: 10,
            paymentMethod: 'cash',
            amountPaid: 10,
            change: 0,
            items: const [
              CartLine(productId: 1, name: 'A', unitPrice: 5, quantity: 1),
              CartLine(productId: 2, name: 'B', unitPrice: 5, quantity: 1),
            ],
            queuedOffline: true,
          ),
        ),
      ),
    );
    expect(find.textContaining('waiting to sync'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('leave via GoRouter', (tester) async {
    late WidgetRef widgetRef;
    final router = GoRouter(
      initialLocation: '/pos',
      routes: [
        GoRoute(
          path: '/pos',
          builder: (context, state) => Consumer(
            builder: (context, ref, _) {
              widgetRef = ref;
              return const PosPage();
            },
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Text('home-root'),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(
          client: MockClient((_) async => http.Response('[]', 200)),
        ),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    widgetRef
        .read(cartControllerProvider.notifier)
        .addProduct(const CatalogProduct(id: 1, name: 'X', price: 1));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('home-root'), findsOneWidget);
  });

  test('settings provider success path', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final client = MockClient((request) async {
      if (request.url.path.contains('sales')) {
        return http.Response('{"require_customer":false}', 200);
      }
      return http.Response('{"enabled_payment_methods":["cash"]}', 200);
    });
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(
          const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
        ),
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
          FakeConnectivityMonitor(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final settings = await container.read(posSettingsProvider.future);
    expect(settings.enabledPaymentMethods, isNotEmpty);
  });

  testWidgets('mpesa checkout offers prompt payment or an SMS code', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/products/') &&
          !request.url.path.contains('/search/') &&
          !request.url.path.contains('/variants/')) {
        return http.Response(
          jsonEncode({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [
              {
                'id': 5,
                'name': 'Nail',
                'selling_price': 20,
                'stock_quantity': 5,
              },
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(client: client),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_product_5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_method_mpesa')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_mpesa_capture_prompt')), findsOneWidget);
    expect(find.byKey(const Key('pos_mpesa_capture_code')), findsOneWidget);
    expect(find.byKey(const Key('pos_mpesa_phone')), findsOneWidget);
    expect(find.textContaining('Send M-Pesa prompt'), findsOneWidget);
  });
}

class _FailingSettingsApi extends PosApi {
  _FailingSettingsApi()
    : super(
        ApiClient(
          env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://x/api'),
          tokenStore: InMemoryTokenStore(),
          httpClient: MockClient((_) async => http.Response('{}', 200)),
        ),
      );

  @override
  Future<Result<PosSettings>> loadSettings() async {
    return Failure(Exception('settings down'));
  }
}
