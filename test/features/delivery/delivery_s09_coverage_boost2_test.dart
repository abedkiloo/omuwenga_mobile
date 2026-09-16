import 'dart:convert';

import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/delivery/application/delivery_controllers.dart';
import 'package:completebyte_pos_mobile/features/delivery/data/delivery_api.dart';
import 'package:completebyte_pos_mobile/features/delivery/domain/delivery_stop.dart';
import 'package:completebyte_pos_mobile/features/delivery/presentation/delivery_route_page.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> stop({
  int id = 1,
  String status = 'pending',
  String label = 'Gate',
  bool pod = false,
}) => {
  'id': id,
  'sequence': id,
  'status': status,
  'customer_name': 'C',
  'customer_phone': '07',
  'site': {
    'id': 1,
    'label': label,
    'latitude': '-1',
    'longitude': '36',
    'landmark': '',
    'customer_phone': '0799',
    'media': [],
  },
  'lines': [
    {
      'product_id': 1,
      'product_name': 'A',
      'ordered_quantity': '1',
      'delivered_quantity': '0',
      'returned_quantity': '0',
    },
  ],
  'pod': pod ? {'is_complete': true} : null,
  'next_stop_id': null,
};

DeliveryApi api(MockClient client) => DeliveryApi(
  ApiClient(
    env: const AppEnv(
      flavor: AppFlavor.dev,
      apiBaseUrl: 'http://example.com/api',
    ),
    tokenStore: InMemoryTokenStore(),
    httpClient: client,
  ),
);

void main() {
  test('controller happy actions and load error', () async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/config')) {
        return http.Response(
          jsonEncode({
            'require_pod_to_complete': true,
            'allow_offline_pod_queue': true,
          }),
          200,
        );
      }
      if (request.url.path.contains('/routes/today')) {
        return http.Response(
          jsonEncode({
            'id': 1,
            'route_date': '2026-09-14',
            'stops': [stop(status: 'pending')],
            'next_stop_id': 1,
          }),
          200,
        );
      }
      if (request.url.path.contains('/arrive')) {
        return http.Response(jsonEncode(stop(status: 'arrived')), 200);
      }
      if (request.url.path.contains('/start')) {
        return http.Response(jsonEncode(stop(status: 'delivering')), 200);
      }
      if (request.url.path.contains('/lines')) {
        return http.Response(jsonEncode(stop(status: 'delivering')), 200);
      }
      if (request.url.path.contains('/collect')) {
        return http.Response(jsonEncode(stop(status: 'collected')), 200);
      }
      return http.Response('{}', 404);
    });
    final c = DeliveryRouteController(
      api(client),
      FakeConnectivityMonitor(online: true),
      MemoryOutboxStore(),
    );
    await c.load();
    expect(c.stopById(1), isNotNull);
    expect(await c.arrive(1), isTrue);
    expect(await c.start(1), isTrue);
    expect(
      await c.saveLines(1, [
        const DeliveryLine(
          productId: 1,
          productName: 'A',
          orderedQuantity: 1,
          deliveredQuantity: 1,
        ),
      ]),
      isTrue,
    );
    expect(await c.collectCash(1, amount: 10), isTrue);
    expect(await c.collectDebt(1), isTrue);
    expect(await c.submitPod(1), isFalse); // incomplete draft

    final fail = DeliveryRouteController(
      api(MockClient((_) async => http.Response('x', 500))),
      FakeConnectivityMonitor(online: true),
      MemoryOutboxStore(),
    );
    await fail.load();
    expect(fail.state.error, isNotNull);
    // _act with null route
    expect(await fail.arrive(9), isFalse);
  });

  testWidgets('route error retry and stop flows', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    var calls = 0;
    final router = GoRouter(
      initialLocation: AppRoutes.deliveryRoute,
      routes: [
        GoRoute(
          path: AppRoutes.deliveryRoute,
          builder: (_, _) => const DeliveryRoutePage(),
        ),
        GoRoute(
          path: '/delivery/stops/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return DeliveryStopPage(stopId: id);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryApiProvider.overrideWithValue(
            api(
              MockClient((request) async {
                calls++;
                if (request.url.path.contains('/config')) {
                  return http.Response(
                    jsonEncode({
                      'require_pod_to_complete': true,
                      'allow_offline_pod_queue': true,
                    }),
                    200,
                  );
                }
                if (calls <= 2) return http.Response('no', 500);
                return http.Response(
                  jsonEncode({
                    'id': 1,
                    'route_date': '2026-09-14',
                    'stops': [
                      stop(id: 1, status: 'arrived', label: ''),
                      stop(id: 2, status: 'pending'),
                    ],
                    'next_stop_id': 1,
                  }),
                  200,
                );
              }),
            ),
          ),
          connectivityMonitorProvider.overrideWithValue(
            FakeConnectivityMonitor(online: true),
          ),
          outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delivery_next_stop')), findsOneWidget);
    await tester.tap(find.byKey(const Key('delivery_route_stop_1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('del_start')), findsOneWidget);
    await tester.tap(find.byKey(const Key('del_start')));
    await tester.pumpAndSettle();
  });

  testWidgets('stop missing and complete next navigation', (tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final container = ProviderContainer(
      overrides: [
        deliveryApiProvider.overrideWithValue(
          api(
            MockClient((request) async {
              if (request.url.path.contains('/config')) {
                return http.Response(
                  jsonEncode({
                    'require_pod_to_complete': true,
                    'allow_offline_pod_queue': true,
                  }),
                  200,
                );
              }
              if (request.url.path.contains('/routes/today')) {
                return http.Response(
                  jsonEncode({
                    'id': 1,
                    'route_date': '2026-09-14',
                    'stops': [
                      stop(id: 1, status: 'collected', pod: true),
                      stop(id: 2, status: 'pending'),
                    ],
                    'next_stop_id': 1,
                  }),
                  200,
                );
              }
              if (request.url.path.contains('/complete')) {
                return http.Response(
                  jsonEncode(stop(id: 1, status: 'completed', pod: true)),
                  200,
                );
              }
              return http.Response('{}', 404);
            }),
          ),
        ),
        connectivityMonitorProvider.overrideWithValue(
          FakeConnectivityMonitor(online: true),
        ),
        outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(deliveryRouteProvider.notifier).load();
    container
        .read(deliveryRouteProvider.notifier)
        .setPodDraft(
          const PodDraft(
            hasSignature: true,
            hasPhoto: true,
            latitude: -1,
            longitude: 36,
          ),
        );

    final router = GoRouter(
      initialLocation: '/delivery/stops/1',
      routes: [
        GoRoute(
          path: AppRoutes.deliveryRoute,
          builder: (_, _) => const DeliveryRoutePage(),
        ),
        GoRoute(
          path: '/delivery/stops/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return DeliveryStopPage(stopId: id);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('del_collect_cash')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('del_collect_debt')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('del_complete')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DeliveryStopPage(stopId: 999)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Stop not found'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
  });

  testWidgets('empty refresh, next CTA, clear pin, complete to route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: AppRoutes.deliveryRoute,
      routes: [
        GoRoute(
          path: AppRoutes.deliveryRoute,
          builder: (_, _) => const DeliveryRoutePage(),
        ),
        GoRoute(
          path: '/delivery/stops/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return DeliveryStopPage(stopId: id);
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryApiProvider.overrideWithValue(
            api(
              MockClient((request) async {
                if (request.url.path.contains('/config')) {
                  return http.Response(
                    jsonEncode({
                      'require_pod_to_complete': true,
                      'allow_offline_pod_queue': true,
                    }),
                    200,
                  );
                }
                if (request.url.path.contains('/routes/today')) {
                  return http.Response(
                    jsonEncode({
                      'id': 1,
                      'route_date': '2026-09-14',
                      'stops': [],
                      'next_stop_id': null,
                    }),
                    200,
                  );
                }
                return http.Response('{}', 404);
              }),
            ),
          ),
          connectivityMonitorProvider.overrideWithValue(
            FakeConnectivityMonitor(online: true),
          ),
          outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    final container = ProviderContainer(
      overrides: [
        deliveryApiProvider.overrideWithValue(
          api(
            MockClient((request) async {
              if (request.url.path.contains('/config')) {
                return http.Response(
                  jsonEncode({
                    'require_pod_to_complete': true,
                    'allow_offline_pod_queue': true,
                  }),
                  200,
                );
              }
              if (request.url.path.contains('/routes/today')) {
                return http.Response(
                  jsonEncode({
                    'id': 1,
                    'route_date': '2026-09-14',
                    'stops': [stop(id: 1, status: 'collected', pod: true)],
                    'next_stop_id': 1,
                  }),
                  200,
                );
              }
              if (request.url.path.contains('/complete')) {
                return http.Response(
                  jsonEncode(stop(id: 1, status: 'completed', pod: true)),
                  200,
                );
              }
              return http.Response('{}', 404);
            }),
          ),
        ),
        connectivityMonitorProvider.overrideWithValue(
          FakeConnectivityMonitor(online: true),
        ),
        outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(deliveryRouteProvider.notifier).load();

    final router2 = GoRouter(
      initialLocation: AppRoutes.deliveryRoute,
      routes: [
        GoRoute(
          path: AppRoutes.deliveryRoute,
          builder: (_, _) => const DeliveryRoutePage(),
        ),
        GoRoute(
          path: '/delivery/stops/:id',
          builder: (context, state) {
            final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
            return DeliveryStopPage(stopId: id);
          },
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router2),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delivery_next_stop')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('del_pod_pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('del_pod_pin'))); // clear
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('del_complete')));
    await tester.pumpAndSettle();
  });
}
