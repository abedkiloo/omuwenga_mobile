import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/pos/application/pos_controllers.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/payment.dart';
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
    apiClientProvider.overrideWith(
      (ref) => ApiClient(
        env: ref.watch(appEnvProvider),
        tokenStore: tokens,
        httpClient: client,
      ),
    ),
    outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
    connectivityMonitorProvider.overrideWithValue(
      FakeConnectivityMonitor(online: true),
    ),
    posSettingsProvider.overrideWith((ref) async => const PosSettings()),
  ];
}

void main() {
  testWidgets('variant product opens picker and adds selected variant', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/products/variants/')) {
        return http.Response(
          jsonEncode({
            'results': [
              {
                'id': 101,
                'product': 12,
                'size': 1,
                'size_name': 'Large',
                'color': 2,
                'color_name': 'White',
                'effective_price': 22,
                'sku': 'TEE-L-W',
                'stock_quantity': 5,
                'is_active': true,
              },
              {
                'id': 102,
                'product': 12,
                'size': 1,
                'size_name': 'Large',
                'color': 3,
                'color_name': 'Black',
                'effective_price': 21,
                'sku': 'TEE-L-B',
                'stock_quantity': 2,
                'is_active': true,
              },
              {
                'id': 103,
                'product': 12,
                'size': 4,
                'size_name': 'Out of stock',
                'color': 5,
                'color_name': 'Red',
                'effective_price': 21,
                'sku': 'TEE-OOS',
                'stock_quantity': 0,
                'is_active': true,
              },
            ],
          }),
          200,
        );
      }
      if (request.url.path.contains('/products/') &&
          !request.url.path.contains('/search/')) {
        return http.Response(
          jsonEncode({
            'count': 1,
            'next': null,
            'previous': null,
            'results': [
              {
                'id': 12,
                'name': 'T-Shirt',
                'selling_price': 20,
                'has_variants': true,
                'sku': 'TEE',
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
              'name': 'T-Shirt',
              'selling_price': 20,
              'has_variants': true,
              'sku': 'TEE',
            },
          ]),
          200,
        );
      }
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(client),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('pos_search')), 'tee');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('pos_product_12')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('variant_picker_title')), findsOneWidget);
    expect(find.byKey(const Key('variant_size_4')), findsNothing);
    await tester.tap(find.byKey(const Key('variant_size_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('variant_color_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('variant_add')));
    await tester.pumpAndSettle();

    expect(find.textContaining('T-Shirt · Large / White'), findsOneWidget);
    expect(find.textContaining('22.00'), findsWidgets);
  });
}
