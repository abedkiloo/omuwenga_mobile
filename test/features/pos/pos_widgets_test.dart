import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
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
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

List<Override> _posOverrides({
  required MockClient httpClient,
  FakeConnectivityMonitor? connectivity,
  MemoryOutboxStore? outbox,
}) {
  final tokens = InMemoryTokenStore();
  final net = connectivity ?? FakeConnectivityMonitor(online: true);
  final box = outbox ?? MemoryOutboxStore();
  return [
    tokenStoreProvider.overrideWithValue(tokens),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
    httpClientProvider.overrideWithValue(httpClient),
    apiClientProvider.overrideWith((ref) {
      return ApiClient(
        env: ref.watch(appEnvProvider),
        tokenStore: tokens,
        httpClient: httpClient,
      );
    }),
    outboxStoreProvider.overrideWithValue(box),
    connectivityMonitorProvider.overrideWithValue(net),
    posSettingsProvider.overrideWith((ref) async => const PosSettings()),
  ];
}

void main() {
  testWidgets('empty cart shows and pay is disabled', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _posOverrides(
          httpClient: MockClient((request) async {
            if (request.url.path.contains('/products/') &&
                !request.url.path.contains('/search/')) {
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
            return http.Response('[]', 200);
          }),
        ),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No products yet'), findsOneWidget);
    final button = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('pos_pay')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('add product enables pay and checkout stock error', (tester) async {
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
                'id': 12,
                'name': 'Cement 50kg',
                'selling_price': 150,
                'stock_quantity': 0,
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
              'stock_quantity': 0,
            },
          ]),
          200,
        );
      }
      if (request.url.path.endsWith('/sales/')) {
        return http.Response(
          jsonEncode({'error': 'Insufficient stock for Cement 50kg. Available: 0'}),
          400,
        );
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _posOverrides(httpClient: client),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No products yet'), findsNothing);
    await tester.tap(find.byKey(const Key('pos_product_12')));
    await tester.pumpAndSettle();

    final payBtn = tester.widget<FilledButton>(
      find.descendant(
        of: find.byKey(const Key('pos_pay')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(payBtn.onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('pos_pay')));
    await tester.pumpAndSettle();
    expect(find.text('Checkout & Tender'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('pos_confirm_pay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pos_confirm_pay')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pos_checkout_error')), findsOneWidget);
    expect(find.textContaining('Insufficient'), findsOneWidget);
  });

  testWidgets('receipt page renders', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptPage(
          receipt: SaleReceipt(
            id: 1,
            saleNumber: 'S-1',
            total: 150,
            paymentMethod: 'cash',
            amountPaid: 200,
            change: 50,
            items: const [
              CartLine(
                productId: 1,
                name: 'Cement',
                unitPrice: 150,
                quantity: 1,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.textContaining('Payment Confirmed'), findsOneWidget);
    expect(find.byKey(const Key('receipt_total')), findsOneWidget);
    await tester.tap(find.byKey(const Key('receipt_done')));
    await tester.pumpAndSettle();
  });

  test('checkout controller success and offline queue', () async {
    final outbox = MemoryOutboxStore();
    final connectivity = FakeConnectivityMonitor(online: true);
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final httpClient = MockClient((request) async {
      if (request.url.path.endsWith('/sales/')) {
        return http.Response(
          jsonEncode({
            'id': 1,
            'sale_number': 'S-1',
            'total': 150,
            'payment_method': 'cash',
            'amount_paid': 150,
            'change': 0,
            'items': [],
          }),
          201,
        );
      }
      return http.Response('{}', 200);
    });

    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        ),
        httpClientProvider.overrideWithValue(httpClient),
        apiClientProvider.overrideWith((ref) {
          return ApiClient(
            env: ref.watch(appEnvProvider),
            tokenStore: tokens,
            httpClient: httpClient,
          );
        }),
        outboxStoreProvider.overrideWithValue(outbox),
        connectivityMonitorProvider.overrideWithValue(connectivity),
        posSettingsProvider.overrideWith((ref) async => const PosSettings()),
      ],
    );
    addTearDown(container.dispose);

    container.read(cartControllerProvider.notifier).addProduct(
          const CatalogProduct(id: 1, name: 'X', price: 150),
        );
    container.read(checkoutControllerProvider.notifier).setDraft(
          const CheckoutDraft(method: PosPaymentMethod.cash, amountPaid: 150),
        );
    expect(await container.read(checkoutControllerProvider.notifier).submit(), isTrue);
    expect(container.read(checkoutControllerProvider).phase, CheckoutPhase.success);
    expect(container.read(cartControllerProvider).isEmpty, isTrue);

    container.read(cartControllerProvider.notifier).addProduct(
          const CatalogProduct(id: 2, name: 'Y', price: 50),
        );
    container.read(checkoutControllerProvider.notifier).setDraft(
          const CheckoutDraft(method: PosPaymentMethod.cash, amountPaid: 50),
        );
    connectivity.setOnline(false);
    expect(await container.read(checkoutControllerProvider.notifier).submit(), isTrue);
    expect(container.read(checkoutControllerProvider).phase, CheckoutPhase.queued);
    expect(await outbox.pendingCount(), 1);
    container.read(checkoutControllerProvider.notifier).resetPhase();
    await outbox.dispose();
    connectivity.dispose();
  });
}
