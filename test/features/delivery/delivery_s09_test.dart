import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
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

Map<String, dynamic> _stopJson({
  int id = 1,
  int sequence = 1,
  String status = 'pending',
  bool podComplete = false,
}) {
  return {
    'id': id,
    'sequence': sequence,
    'status': status,
    'field_order_id': 9,
    'customer_name': 'Debtor',
    'customer_phone': '0700',
    'site': {
      'id': 3,
      'label': 'Blue gate',
      'latitude': '-1.29',
      'longitude': '36.82',
      'landmark': 'Blue container',
      'media': [
        {'image_url': 'http://x/a.jpg'},
      ],
    },
    'lines': [
      {
        'product_id': 2,
        'product_name': 'Paint',
        'ordered_quantity': '2',
        'delivered_quantity': '0',
        'returned_quantity': '0',
      },
    ],
    'pod': podComplete
        ? {'is_complete': true, 'latitude': '-1.29', 'longitude': '36.82'}
        : null,
    'next_stop_id': null,
  };
}

Map<String, dynamic> _routeJson(List<Map<String, dynamic>> stops) => {
  'id': 1,
  'route_date': '2026-09-14',
  'delivery_agent_id': 5,
  'stops': stops,
  'next_stop_id': stops.isEmpty ? null : stops.first['id'],
};

DeliveryApi _api(MockClient client) {
  return DeliveryApi(
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
    test('status parse, next stop, canComplete, config', () {
      expect(
        DeliveryStopStatus.parse('collected'),
        DeliveryStopStatus.collected,
      );
      expect(DeliveryStopStatus.parse(null), DeliveryStopStatus.pending);
      final a = DeliveryStop.fromJson(
        _stopJson(id: 1, sequence: 2, status: 'completed'),
      );
      final b = DeliveryStop.fromJson(
        _stopJson(id: 2, sequence: 1, status: 'pending'),
      );
      expect(selectNextStop([a, b])!.id, 2);
      expect(selectNextStop([a]), isNull);
      final collected = DeliveryStop.fromJson(
        _stopJson(status: 'collected', podComplete: false),
      );
      expect(collected.canComplete, isFalse);
      final ready = DeliveryStop.fromJson(
        _stopJson(status: 'collected', podComplete: true),
      );
      expect(ready.canComplete, isTrue);
      expect(
        DeliveryConfig.fromJson({
          'require_pod_to_complete': false,
          'allow_offline_pod_queue': false,
        }).requirePodToComplete,
        isFalse,
      );
      expect(
        DeliveryConfig.fromJson({
          'maps': {'can_view_history': true},
        }).canViewHistory,
        isTrue,
      );
      expect(localIsoDate(DateTime(2026, 9, 24)), '2026-09-24');
      expect(
        DeliveryRoute.fromJson({
          'id': null,
          'route_date': '2026-09-20',
          'stops': [],
        }).id,
        0,
      );
      final line = DeliveryLine.fromJson({
        'product_id': 1,
        'product_name': 'A',
        'ordered_quantity': '3',
      }).copyWith(deliveredQuantity: 2, returnedQuantity: 1);
      expect(line.deliveredQuantity, 2);
    });
  });

  group('api', () {
    test('today route config actions and failures', () async {
      final api = _api(
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
            return http.Response(jsonEncode(_routeJson([_stopJson()])), 200);
          }
          if (request.url.path.contains('/lookup')) {
            return http.Response(jsonEncode(_routeJson([_stopJson()])), 200);
          }
          if (request.url.path.contains('/arrive')) {
            return http.Response(jsonEncode(_stopJson(status: 'arrived')), 200);
          }
          if (request.url.path.contains('/pod')) {
            return http.Response(jsonEncode({'is_complete': true}), 200);
          }
          if (request.url.path.contains('/stops/1') &&
              request.method == 'GET') {
            return http.Response(
              jsonEncode(_stopJson(status: 'collected', podComplete: true)),
              200,
            );
          }
          if (request.url.path.contains('/complete')) {
            return http.Response(
              jsonEncode(_stopJson(status: 'completed', podComplete: true)),
              200,
            );
          }
          if (request.url.path.contains('/lines')) {
            return http.Response(
              jsonEncode(_stopJson(status: 'delivering')),
              200,
            );
          }
          if (request.url.path.contains('/collect')) {
            return http.Response(
              jsonEncode(_stopJson(status: 'collected')),
              200,
            );
          }
          if (request.url.path.contains('/start')) {
            return http.Response(
              jsonEncode(_stopJson(status: 'delivering')),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      expect((await api.config()).getOrThrow().requirePodToComplete, isTrue);
      expect((await api.todayRoute()).getOrThrow().stops.single.id, 1);
      expect(
        (await api.lookupRoute(agentId: 3, date: '2026-09-20')).getOrThrow().id,
        1,
      );
      expect(
        (await api.arrive(1)).getOrThrow().status,
        DeliveryStopStatus.arrived,
      );
      expect((await api.start(1)).isSuccess, isTrue);
      expect(
        (await api.updateLines(1, [
          const DeliveryLine(
            productId: 2,
            productName: 'Paint',
            orderedQuantity: 2,
            deliveredQuantity: 2,
          ),
        ])).isSuccess,
        isTrue,
      );
      expect(
        (await api.collect(1, method: 'cash', amount: 10)).isSuccess,
        isTrue,
      );
      expect(
        (await api.submitPod(
          1,
          draft: const PodDraft(
            hasSignature: true,
            hasPhoto: true,
            latitude: -1.29,
            longitude: 36.82,
          ),
        )).getOrThrow().podComplete,
        isTrue,
      );
      expect(
        (await api.complete(1)).getOrThrow().status,
        DeliveryStopStatus.completed,
      );

      final bad = _api(MockClient((_) async => http.Response('x', 500)));
      expect((await bad.config()).isFailure, isTrue);
      expect((await bad.todayRoute()).isFailure, isTrue);
      expect((await bad.lookupRoute(agentId: 3)).isFailure, isTrue);
      expect((await bad.arrive(1)).isFailure, isTrue);
      expect(DeliveryApiException('e').toString(), 'e');
    });
  });

  group('controller', () {
    test('complete gated on POD; offline queue', () async {
      final outbox = MemoryOutboxStore();
      final net = FakeConnectivityMonitor(online: true);
      var stopStatus = 'collected';
      final api = _api(
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
              jsonEncode(
                _routeJson([_stopJson(status: stopStatus, podComplete: false)]),
              ),
              200,
            );
          }
          if (request.url.path.contains('/pod')) {
            return http.Response(jsonEncode({'is_complete': true}), 200);
          }
          if (request.url.path.contains('/stops/1') &&
              request.method == 'GET') {
            return http.Response(
              jsonEncode(_stopJson(status: 'collected', podComplete: true)),
              200,
            );
          }
          if (request.url.path.contains('/complete')) {
            stopStatus = 'completed';
            return http.Response(
              jsonEncode(_stopJson(status: 'completed', podComplete: true)),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      final c = DeliveryRouteController(api, net, outbox);
      await c.load();
      expect(await c.complete(1), isFalse);
      expect(c.state.error, contains('POD'));
      c.setPodDraft(
        const PodDraft(
          hasSignature: true,
          hasPhoto: true,
          latitude: -1.2,
          longitude: 36.8,
        ),
      );
      expect(await c.submitPod(1), isTrue);
      expect(await c.complete(1), isTrue);

      net.setOnline(false);
      c.setPodDraft(
        const PodDraft(
          hasSignature: true,
          hasPhoto: true,
          latitude: -1.2,
          longitude: 36.8,
        ),
      );
      expect(await c.submitPod(1), isTrue);
      expect(c.state.queuedPodOffline, isTrue);
      expect(await outbox.pendingCount(), 1);
    });
  });

  group('widgets', () {
    testWidgets('map and photos render above lines; complete disabled', (
      tester,
    ) async {
      final api = _api(
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
          return http.Response(
            jsonEncode(
              _routeJson([_stopJson(status: 'collected', podComplete: false)]),
            ),
            200,
          );
        }),
      );
      final container = ProviderContainer(
        overrides: [
          deliveryApiProvider.overrideWithValue(api),
          connectivityMonitorProvider.overrideWithValue(
            FakeConnectivityMonitor(online: true),
          ),
          outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(deliveryRouteProvider.notifier).load();

      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DeliveryStopPage(stopId: 1)),
        ),
      );
      await tester.pumpAndSettle();

      final mapY = tester.getTopLeft(find.byKey(const Key('del_stop_map'))).dy;
      final photosY = tester
          .getTopLeft(find.byKey(const Key('del_stop_photos')))
          .dy;
      final lineY = tester.getTopLeft(find.byKey(const Key('del_line_2'))).dy;
      expect(mapY < photosY, isTrue);
      expect(photosY < lineY, isTrue);

      final complete = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('del_complete')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(complete.onPressed, isNull);
    });

    testWidgets('route list and two-stop next selection UI', (tester) async {
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
              _api(
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
                  return http.Response(
                    jsonEncode(
                      _routeJson([
                        _stopJson(id: 1, sequence: 1),
                        _stopJson(id: 2, sequence: 2, status: 'pending'),
                      ]),
                    ),
                    200,
                  );
                }),
              ),
            ),
            connectivityMonitorProvider.overrideWithValue(
              FakeConnectivityMonitor(online: true),
            ),
            outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
            appEnvProvider.overrideWithValue(
              const AppEnv(
                flavor: AppFlavor.dev,
                apiBaseUrl: 'http://example.com/api',
              ),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delivery_next_stop')), findsOneWidget);
      expect(find.byKey(const Key('delivery_route_stop_1')), findsOneWidget);
    });
  });
}
