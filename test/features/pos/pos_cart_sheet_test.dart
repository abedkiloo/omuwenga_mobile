import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/pos/application/pos_controllers.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/payment.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/pos_cart_sheet.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/pos_page.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

List<Override> _overrides(MockClient client) {
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
      FakeConnectivityMonitor(online: true),
    ),
    posSettingsProvider.overrideWith((ref) async => const PosSettings()),
  ];
}

MockClient _catalogClient() {
  return MockClient((request) async {
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
              'id': 12,
              'name': 'Cement 50kg',
              'selling_price': 150,
              'stock_quantity': 10,
              'sku': 'CEM-50',
            },
          ],
        }),
        200,
      );
    }
    if (request.url.path.contains('/products/search/')) {
      return http.Response(
        jsonEncode([
          {
            'id': 12,
            'name': 'Cement 50kg',
            'selling_price': 150,
            'stock_quantity': 10,
            'sku': 'CEM-50',
          },
        ]),
        200,
      );
    }
    return http.Response('{}', 200);
  });
}

void main() {
  testWidgets('cart icon opens empty cart sheet', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(_catalogClient()),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_cart_icon')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_cart_sheet_title')), findsOneWidget);
    expect(find.byKey(const Key('pos_cart_sheet_empty')), findsOneWidget);
    expect(find.byKey(const Key('pos_cart_sheet_checkout')), findsOneWidget);

    final checkout = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('pos_cart_sheet_checkout')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(checkout.onPressed, isNull);

    await tester.tap(find.byKey(const Key('pos_cart_sheet_close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pos_cart_sheet_title')), findsNothing);
  });

  testWidgets('cart sheet edits quantity, removes line, and starts payment', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(_catalogClient()),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_product_12')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_cart_icon')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_cart_sheet_list')), findsOneWidget);
    expect(find.byKey(const Key('pos_cart_sheet_line_12')), findsOneWidget);
    expect(find.byKey(const Key('pos_cart_sheet_qty_12')), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await tester.tap(find.byKey(const Key('pos_cart_sheet_inc_12')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pos_cart_sheet_qty_12')), findsOneWidget);
    expect(
      (tester.widget<Text>(find.byKey(const Key('pos_cart_sheet_qty_12')))).data,
      '2',
    );
    expect(find.byKey(const Key('pos_cart_sheet_total')), findsOneWidget);
    expect(find.text('KES 300.00'), findsWidgets);

    await tester.tap(find.byKey(const Key('pos_cart_sheet_dec_12')));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Text>(find.byKey(const Key('pos_cart_sheet_qty_12')))).data,
      '1',
    );

    await tester.tap(find.byKey(const Key('pos_cart_sheet_checkout')));
    await tester.pumpAndSettle();
    expect(find.text('Checkout & Tender'), findsOneWidget);
  });

  testWidgets('cart sheet remove empties cart', (tester) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(_catalogClient()),
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
        .addProduct(
          const CatalogProduct(
            id: 12,
            name: 'Cement 50kg',
            price: 150,
            stockQuantity: 10,
          ),
        );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_cart_icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_cart_sheet_remove_12')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pos_cart_sheet_empty')), findsOneWidget);
    expect(widgetRef.read(cartControllerProvider).isEmpty, isTrue);
  });

  testWidgets('cart sheet clear confirms and clears sale', (tester) async {
    late WidgetRef widgetRef;
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(_catalogClient()),
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
        .addProduct(const CatalogProduct(id: 12, name: 'Cement', price: 150));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_cart_icon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_cart_sheet_clear')));
    await tester.pumpAndSettle();
    expect(find.text('Clear current sale?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('pos_clear_confirm')));
    await tester.pumpAndSettle();
    expect(widgetRef.read(cartControllerProvider).isEmpty, isTrue);
  });

  testWidgets('PosCartSheet standalone keeps shopping', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartControllerProvider.overrideWith((ref) => CartController()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PosCartSheet(onCheckout: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pos_cart_sheet_empty')), findsOneWidget);
    await tester.tap(find.text('Keep shopping'));
    await tester.pumpAndSettle();
  });

  testWidgets('PosCartSheet clear without callback and multi-line separator', (
    tester,
  ) async {
    final cart = CartController()
      ..addProduct(
        const CatalogProduct(id: 1, name: 'A', price: 10, stockQuantity: 5),
      )
      ..addProduct(
        const CatalogProduct(id: 2, name: 'B', price: 20, stockQuantity: 5),
      );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cartControllerProvider.overrideWith((ref) => cart),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPosCartSheet(
                  context: context,
                  onCheckout: () {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pos_cart_sheet_line_1')), findsOneWidget);
    expect(find.byKey(const Key('pos_cart_sheet_line_2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('pos_cart_sheet_clear')));
    await tester.pumpAndSettle();
    expect(cart.state.isEmpty, isTrue);
    expect(find.byKey(const Key('pos_cart_sheet_empty')), findsOneWidget);
  });
}
