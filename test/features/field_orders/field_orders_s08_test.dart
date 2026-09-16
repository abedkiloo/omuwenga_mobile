import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/notifications/push_notifier.dart';
import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/field_orders/application/field_order_controllers.dart';
import 'package:completebyte_pos_mobile/features/field_orders/data/field_orders_api.dart';
import 'package:completebyte_pos_mobile/features/field_orders/domain/field_order.dart';
import 'package:completebyte_pos_mobile/features/field_orders/presentation/field_order_review_page.dart';
import 'package:completebyte_pos_mobile/features/pos/application/pos_controllers.dart';
import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _orderJson({
  int id = 1,
  String status = 'draft',
  int siteId = 7,
}) {
  return {
    'id': id,
    'status': status,
    'site': siteId,
    'site_detail': {
      'id': siteId,
      'label': 'Gate',
      'latitude': '-1.29',
      'longitude': '36.82',
    },
    'site_media': [
      {'image_url': 'http://x/a.jpg'},
    ],
    'lines': [
      {
        'product_id': 1,
        'product_name': 'Sample SKU',
        'quantity': '2',
        'unit_price': '100.00',
      },
    ],
    'stock_allocated': false,
  };
}

FieldOrdersApi _api(MockClient client) {
  return FieldOrdersApi(
    ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: InMemoryTokenStore(),
      httpClient: client,
    ),
  );
}

void main() {
  group('domain', () {
    test('status parse and apiValue', () {
      expect(FieldOrderStatus.parse('submitted'), FieldOrderStatus.submitted);
      expect(
        FieldOrderStatus.parse('out_for_delivery'),
        FieldOrderStatus.outForDelivery,
      );
      expect(FieldOrderStatus.parse(null), FieldOrderStatus.draft);
      expect(FieldOrderStatus.outForDelivery.apiValue, 'out_for_delivery');
      expect(FieldOrderStatus.ready.apiValue, 'ready');
      for (final s in FieldOrderStatus.values) {
        expect(FieldOrderStatus.parse(s.apiValue), s);
      }
    });

    test('cart canSubmit and addProduct merge', () {
      var cart = const FieldOrderCart(siteId: 0);
      expect(cart.canSubmit, isFalse);
      cart = cart
          .copyWith(siteId: 3)
          .addProduct(const CatalogProduct(id: 1, name: 'A', price: 10));
      expect(cart.canSubmit, isTrue);
      cart = cart.addProduct(const CatalogProduct(id: 1, name: 'A', price: 10));
      expect(cart.lines.single.quantity, 2);
      expect(cart.subtotal, 20);
      expect(cart.toLinesJson().single['product_id'], 1);
      cart = cart.copyWith(
        notes: 'n',
        photoUrls: ['u'],
        latitude: 1,
        longitude: 2,
      );
      expect(cart.notes, 'n');
      expect(cart.photoUrls, ['u']);
    });

    test('summary fromJson', () {
      final s = FieldOrderSummary.fromJson(_orderJson(status: 'packing'));
      expect(s.id, 1);
      expect(s.status, FieldOrderStatus.packing);
      expect(s.photoUrls, ['http://x/a.jpg']);
      expect(s.latitude, -1.29);
      expect(s.lines.single.name, 'Sample SKU');
    });
  });

  group('api', () {
    test('create submit list success and failures', () async {
      final api = _api(
        MockClient((request) async {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/field-orders/')) {
            return http.Response(jsonEncode(_orderJson()), 201);
          }
          if (request.url.path.contains('/submit/')) {
            return http.Response(
              jsonEncode(_orderJson(status: 'submitted')),
              200,
            );
          }
          if (request.url.path.contains('/field-orders/')) {
            return http.Response(
              jsonEncode({
                'results': [_orderJson(status: 'submitted')],
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      final created = await api.create(
        const FieldOrderCart(siteId: 7).addProduct(
          const CatalogProduct(id: 1, name: 'Sample SKU', price: 100),
        ),
      );
      expect(created.getOrThrow().id, 1);
      expect(
        (await api.submit(1)).getOrThrow().status,
        FieldOrderStatus.submitted,
      );
      expect((await api.listMine()).getOrThrow().single.id, 1);

      final bad = _api(MockClient((_) async => http.Response('nope', 400)));
      expect(
        (await bad.create(const FieldOrderCart(siteId: 1))).isFailure,
        isTrue,
      );
      expect((await bad.submit(9)).isFailure, isTrue);
      expect((await bad.listMine()).isFailure, isTrue);

      final invalid = _api(MockClient((_) async => http.Response('"x"', 200)));
      expect((await invalid.listMine()).isFailure, isTrue);
      expect((await invalid.submit(1)).isFailure, isTrue);

      final listBare = _api(
        MockClient((_) async => http.Response(jsonEncode([_orderJson()]), 200)),
      );
      expect((await listBare.listMine()).getOrThrow().length, 1);

      final netFail = FieldOrdersApi(
        ApiClient(
          env: const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
          tokenStore: InMemoryTokenStore(),
          httpClient: MockClient((_) async => throw Exception('down')),
        ),
      );
      expect((await netFail.listMine()).isFailure, isTrue);
    });
  });

  group('controller', () {
    test('submit blocked without lines; success notifies push', () async {
      final push = FakePushNotifier();
      final api = _api(
        MockClient((request) async {
          if (request.url.path.endsWith('/field-orders/')) {
            return http.Response(jsonEncode(_orderJson()), 201);
          }
          return http.Response(
            jsonEncode(_orderJson(status: 'submitted')),
            200,
          );
        }),
      );
      final c = FieldOrderCartController(api, push);
      expect(await c.submit(), isFalse);
      c.bindSite(
        siteId: 7,
        label: 'Gate',
        photoUrls: ['u'],
        latitude: 1,
        longitude: 2,
      );
      c.setNotes('rush');
      expect(c.state.canSubmit, isFalse);
      c.addProduct(const CatalogProduct(id: 1, name: 'Sample SKU', price: 100));
      expect(c.state.canSubmit, isTrue);
      expect(await c.submit(), isTrue);
      expect(c.state.submittedOrderId, 1);
      expect(c.state.cart.lines, isEmpty);
      expect(push.sent, isNotEmpty);
    });

    test('create failure and submit failure paths', () async {
      var n = 0;
      final api = _api(
        MockClient((request) async {
          n++;
          if (n == 1) return http.Response('bad', 400);
          if (request.url.path.endsWith('/field-orders/')) {
            return http.Response(jsonEncode(_orderJson(id: 5)), 201);
          }
          return http.Response('no', 400);
        }),
      );
      final c = FieldOrderCartController(api, FakePushNotifier());
      c.bindSite(siteId: 1);
      c.addProduct(const CatalogProduct(id: 1, name: 'A', price: 1));
      expect(await c.submit(), isFalse);
      expect(c.state.error, isNotNull);
      expect(await c.submit(), isFalse);
      expect(c.state.submittedOrderId, 5);
      expect(c.state.error, contains('submit failed'));
    });
  });

  group('widgets', () {
    testWidgets('submit button disabled without lines', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fieldOrdersApiProvider.overrideWithValue(
              _api(MockClient((_) async => http.Response('{}', 200))),
            ),
            pushNotifierProvider.overrideWithValue(FakePushNotifier()),
          ],
          child: const MaterialApp(home: FieldOrderReviewPage()),
        ),
      );
      await tester.pumpAndSettle();
      final btn = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('fo_submit')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('cart add enables review; review submit works', (tester) async {
      final push = FakePushNotifier();
      final posApi = PosApi(
        ApiClient(
          env: const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
          tokenStore: InMemoryTokenStore(),
          httpClient: MockClient((request) async {
            if (request.url.path.contains('/products/search/')) {
              return http.Response(
                jsonEncode([
                  {
                    'id': 1,
                    'name': 'Sample SKU',
                    'selling_price': 100,
                    'sku': 'SKU-1',
                  },
                ]),
                200,
              );
            }
            return http.Response('[]', 200);
          }),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            fieldOrdersApiProvider.overrideWithValue(
              _api(
                MockClient((request) async {
                  if (request.url.path.endsWith('/field-orders/')) {
                    return http.Response(jsonEncode(_orderJson()), 201);
                  }
                  return http.Response(
                    jsonEncode(_orderJson(status: 'submitted')),
                    200,
                  );
                }),
              ),
            ),
            posApiProvider.overrideWithValue(posApi),
            pushNotifierProvider.overrideWithValue(push),
            appEnvProvider.overrideWithValue(
              const AppEnv(
                flavor: AppFlavor.dev,
                apiBaseUrl: 'http://example.com/api',
              ),
            ),
          ],
          child: const MaterialApp(home: FieldOrderCartPage(siteId: 7)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byKey(const Key('fo_to_review')),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(find.byKey(const Key('fo_search')), 'sample');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fo_product_1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('fo_to_review')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('fo_submit')), findsOneWidget);
      await tester.tap(find.byKey(const Key('fo_submit')));
      await tester.pumpAndSettle();
      expect(push.sent, isNotEmpty);
    });
  });

  test('push stubs', () async {
    final fake = FakePushNotifier();
    await fake.notify(title: 't', body: 'b', data: {'k': 'v'});
    expect(fake.sent.single['title'], 't');
    await NoOpPushNotifier().notify(title: 't', body: 'b');
  });

  test('FieldOrdersApiException toString', () {
    expect(FieldOrdersApiException('x').toString(), 'x');
    expect(Failure<int>(FieldOrdersApiException('e')).isFailure, isTrue);
  });
}
