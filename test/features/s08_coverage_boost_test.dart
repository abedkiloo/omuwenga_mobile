import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/notifications/push_notifier.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/dispatch/application/dispatch_controllers.dart';
import 'package:completebyte_pos_mobile/features/dispatch/data/dispatch_api.dart';
import 'package:completebyte_pos_mobile/features/dispatch/presentation/dispatch_queue_page.dart';
import 'package:completebyte_pos_mobile/features/field_orders/application/field_order_controllers.dart';
import 'package:completebyte_pos_mobile/features/field_orders/data/field_orders_api.dart';
import 'package:completebyte_pos_mobile/features/field_orders/domain/field_order.dart';
import 'package:completebyte_pos_mobile/features/field_orders/presentation/field_order_review_page.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AuthSession _dispatcherSession() {
  return AuthSession(
    user: const AuthUser(id: 3, username: 'dispatch', firstName: 'Di', lastName: 'Patch'),
    profile: const UserProfileSnapshot(
      role: 'manager',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: true,
    ),
    permissions: PermissionSet(const [
      PermissionGrant(module: 'dispatch', action: 'view'),
      PermissionGrant(module: 'dispatch', action: 'update'),
    ]),
    persona: AppPersona.dispatcher,
  );
}
ApiClient _client(MockClient httpClient) {
  return ApiClient(
    env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    tokenStore: InMemoryTokenStore(),
    httpClient: httpClient,
  );
}

void main() {
  test('default providers construct', () {
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          _client(MockClient((_) async => http.Response('[]', 200))),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(container.read(fieldOrdersApiProvider), isA<FieldOrdersApi>());
    expect(container.read(dispatchApiProvider), isA<DispatchApi>());
    expect(container.read(pushNotifierProvider), isA<FakePushNotifier>());
  });

  test('api catch and site_id from site_detail', () async {
    final fo = FieldOrdersApi(
      _client(
        MockClient((_) async => http.Response('{not-json', 200)),
      ),
    );
    expect((await fo.listMine()).isFailure, isTrue);
    expect((await fo.submit(1)).isFailure, isTrue);

    final netFail = FieldOrdersApi(
      _client(MockClient((_) async => throw Exception('x'))),
    );
    expect((await netFail.submit(1)).isFailure, isTrue);

    final dispatch = DispatchApi(
      _client(MockClient((_) async => http.Response('{bad', 200))),
    );
    expect((await dispatch.queue()).isFailure, isTrue);
    expect((await dispatch.pack(1)).isFailure, isTrue);

    final dispatchNet = DispatchApi(
      _client(MockClient((_) async => throw Exception('x'))),
    );
    expect((await dispatchNet.pack(1)).isFailure, isTrue);

    final summary = FieldOrderSummary.fromJson({
      'id': 3,
      'status': 'draft',
      'site_detail': {'id': 99, 'label': 'Only detail'},
      'lines': 'nope',
      'site_media': [{'image_url': null}, 'x'],
    });
    expect(summary.siteId, 99);
    expect(summary.photoUrls, isEmpty);
  });

  testWidgets('review shows pin photos and submit error', (tester) async {
    final container = ProviderContainer(
      overrides: [
        fieldOrdersApiProvider.overrideWithValue(
          FieldOrdersApi(
            _client(MockClient((_) async => http.Response('no', 400))),
          ),
        ),
        pushNotifierProvider.overrideWithValue(FakePushNotifier()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(fieldOrderCartProvider.notifier);
    notifier.bindSite(
      siteId: 7,
      label: 'Gate',
      photoUrls: ['http://x/a.jpg'],
      latitude: -1.2921,
      longitude: 36.8219,
    );
    notifier.addProduct(const CatalogProduct(id: 1, name: 'SKU', price: 10));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: FieldOrderReviewPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fo_site_map')), findsOneWidget);
    expect(find.byKey(const Key('fo_photo_0')), findsOneWidget);
    await tester.tap(find.byKey(const Key('fo_submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('fo_submit_error')), findsOneWidget);
  });

  testWidgets('dispatch queue error empty refresh and detail actions', (tester) async {
    var calls = 0;
    final api = DispatchApi(
      _client(
        MockClient((request) async {
          calls++;
          if (request.url.path.contains('/queue/')) {
            if (calls == 1) return http.Response('x', 500);
            return http.Response(
              jsonEncode([
                {
                  'id': 11,
                  'status': 'submitted',
                  'site': 7,
                  'site_detail': {
                    'id': 7,
                    'label': 'Yard',
                    'latitude': '-1.3',
                    'longitude': '36.8',
                  },
                  'site_media': [
                    {'image_url': 'http://x/b.jpg'},
                  ],
                  'lines': [
                    {
                      'product_id': 2,
                      'product_name': 'Paint',
                      'quantity': '1',
                      'unit_price': '50',
                    },
                  ],
                },
              ]),
              200,
            );
          }
          if (request.url.path.contains('/pack/')) {
            return http.Response('bad', 400);
          }
          if (request.url.path.contains('/assign/')) {
            return http.Response('bad', 400);
          }
          return http.Response('[]', 200);
        }),
      ),
    );

    final router = GoRouter(
      initialLocation: AppRoutes.dispatchQueue,
      routes: [
        GoRoute(
          path: AppRoutes.dispatchQueue,
          builder: (_, _) => const DispatchQueuePage(),
        ),
        GoRoute(
          path: '/dispatch/orders/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return DispatchOrderDetailPage(orderId: id);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionSeedProvider.overrideWithValue(_dispatcherSession()),
          dispatchApiProvider.overrideWithValue(api),
          pushNotifierProvider.overrideWithValue(FakePushNotifier()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dispatch_order_11')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dispatch_order_11')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dispatch_driver_select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Driver A (101)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dispatch_pack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dispatch_error')), findsOneWidget);
    await tester.tap(find.byKey(const Key('dispatch_assign')));
    await tester.pumpAndSettle();
  });

  testWidgets('dispatch empty refresh and missing order', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dispatchApiProvider.overrideWithValue(
            DispatchApi(
              _client(MockClient((_) async => http.Response('[]', 200))),
            ),
          ),
          pushNotifierProvider.overrideWithValue(FakePushNotifier()),
        ],
        child: const MaterialApp(home: DispatchQueuePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Queue clear'), findsOneWidget);
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dispatchApiProvider.overrideWithValue(
            DispatchApi(
              _client(MockClient((_) async => http.Response('[]', 200))),
            ),
          ),
          pushNotifierProvider.overrideWithValue(FakePushNotifier()),
        ],
        child: const MaterialApp(home: DispatchOrderDetailPage(orderId: 999)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Order not in queue'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
  });
}
