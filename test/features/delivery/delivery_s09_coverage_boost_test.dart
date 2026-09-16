import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
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
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> stopJson({
  int id = 1,
  String status = 'pending',
  bool podComplete = false,
}) => {
  'id': id,
  'sequence': 1,
  'status': status,
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
  'pod': podComplete ? {'is_complete': true} : null,
};

void main() {
  test('provider constructs', () {
    final c = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(
          ApiClient(
            env: const AppEnv(
              flavor: AppFlavor.dev,
              apiBaseUrl: 'http://example.com/api',
            ),
            tokenStore: InMemoryTokenStore(),
            httpClient: MockClient((_) async => http.Response('{}', 200)),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    expect(c.read(deliveryApiProvider), isA<DeliveryApi>());
  });

  testWidgets('stop layout order and POD complete enablement', (tester) async {
    tester.view.physicalSize = const Size(400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    var status = 'collected';
    final api = DeliveryApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((request) async {
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
                'stops': [stopJson(status: status)],
                'next_stop_id': 1,
              }),
              200,
            );
          }
          if (request.url.path.contains('/pod')) {
            return http.Response(jsonEncode({'is_complete': true}), 200);
          }
          if (request.url.path.endsWith('/stops/1/') ||
              request.url.path.endsWith('/stops/1')) {
            return http.Response(
              jsonEncode(stopJson(status: 'collected', podComplete: true)),
              200,
            );
          }
          if (request.url.path.contains('/complete')) {
            status = 'completed';
            return http.Response(
              jsonEncode(stopJson(status: 'completed', podComplete: true)),
              200,
            );
          }
          if (request.url.path.contains('/arrive')) {
            status = 'arrived';
            return http.Response(jsonEncode(stopJson(status: 'arrived')), 200);
          }
          if (request.url.path.contains('/start')) {
            status = 'delivering';
            return http.Response(
              jsonEncode(stopJson(status: 'delivering')),
              200,
            );
          }
          if (request.url.path.contains('/collect')) {
            status = 'collected';
            return http.Response(
              jsonEncode(stopJson(status: 'collected')),
              200,
            );
          }
          if (request.url.path.contains('/lines')) {
            return http.Response(
              jsonEncode(stopJson(status: 'delivering')),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        deliveryApiProvider.overrideWithValue(api),
        connectivityMonitorProvider.overrideWithValue(
          FakeConnectivityMonitor(online: true),
        ),
        outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
        deliveryExternalUriHandlerProvider.overrideWithValue((_) async {}),
      ],
    );
    addTearDown(container.dispose);
    await container.read(deliveryRouteProvider.notifier).load();
    expect(
      container.read(deliveryRouteProvider).route!.stops.single.lines,
      isNotEmpty,
    );
    expect(
      container
          .read(deliveryRouteProvider)
          .route!
          .stops
          .single
          .lines
          .single
          .productId,
      2,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DeliveryStopPage(stopId: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('del_stop_map')), findsOneWidget);
    expect(find.byKey(const Key('del_stop_photos')), findsOneWidget);
    expect(find.byKey(const Key('del_line_2')), findsOneWidget);
    final mapY = tester.getTopLeft(find.byKey(const Key('del_stop_map'))).dy;
    final lineY = tester.getTopLeft(find.byKey(const Key('del_line_2'))).dy;
    expect(mapY < lineY, isTrue);

    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('del_complete')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const Key('del_pod_signature')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('del_pod_photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('del_pod_pin')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('del_save_pod')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const Key('del_complete')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('del_open_maps')));
    await tester.tap(find.byKey(const Key('del_call')));
    await tester.pumpAndSettle();
  });

  testWidgets('pending arrive CTA and empty route', (tester) async {
    final container = ProviderContainer(
      overrides: [
        deliveryApiProvider.overrideWithValue(
          DeliveryApi(
            ApiClient(
              env: const AppEnv(
                flavor: AppFlavor.dev,
                apiBaseUrl: 'http://example.com/api',
              ),
              tokenStore: InMemoryTokenStore(),
              httpClient: MockClient((request) async {
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
                      'stops': [stopJson(status: 'pending')],
                      'next_stop_id': 1,
                    }),
                    200,
                  );
                }
                return http.Response(
                  jsonEncode(stopJson(status: 'arrived')),
                  200,
                );
              }),
            ),
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
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DeliveryStopPage(stopId: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('del_arrive')), findsOneWidget);
    await tester.tap(find.byKey(const Key('del_arrive')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deliveryApiProvider.overrideWithValue(
            DeliveryApi(
              ApiClient(
                env: const AppEnv(
                  flavor: AppFlavor.dev,
                  apiBaseUrl: 'http://example.com/api',
                ),
                tokenStore: InMemoryTokenStore(),
                httpClient: MockClient((request) async {
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
                    jsonEncode({
                      'id': 1,
                      'route_date': '2026-09-14',
                      'stops': [],
                      'next_stop_id': null,
                    }),
                    200,
                  );
                }),
              ),
            ),
          ),
          connectivityMonitorProvider.overrideWithValue(
            FakeConnectivityMonitor(online: true),
          ),
          outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
        ],
        child: const MaterialApp(home: DeliveryRoutePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No stops today'), findsOneWidget);
  });

  test('domain edges and api invalid payloads', () async {
    expect(DeliveryStopStatus.parse('arrived').apiValue, 'arrived');
    expect(
      DeliveryStopStatus.parse('delivering'),
      DeliveryStopStatus.delivering,
    );
    expect(DeliveryStopStatus.parse('failed'), DeliveryStopStatus.failed);
    final site = DeliverySiteSnapshot.fromJson({
      'id': 1,
      'media': [
        {'image_url': null},
        'x',
      ],
    });
    expect(site.photoUrls, isEmpty);
    final pod = const PodDraft(hasSignature: true).copyWith(clearPin: true);
    expect(pod.latitude, isNull);

    final api = DeliveryApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((_) async => http.Response('"x"', 200)),
      ),
    );
    expect((await api.config()).isFailure, isTrue);
    expect((await api.todayRoute()).isFailure, isTrue);
    expect((await api.retrieve(1)).isFailure, isTrue);

    final net = DeliveryApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((_) async => throw Exception('down')),
      ),
    );
    expect((await net.todayRoute()).isFailure, isTrue);
  });

  test('controller action failures and offline deny', () async {
    final api = DeliveryApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('/config')) {
            return http.Response(
              jsonEncode({
                'require_pod_to_complete': true,
                'allow_offline_pod_queue': false,
              }),
              200,
            );
          }
          if (request.url.path.contains('/routes/today')) {
            return http.Response(
              jsonEncode({
                'id': 1,
                'route_date': '2026-09-14',
                'stops': [stopJson(status: 'arrived')],
                'next_stop_id': 1,
              }),
              200,
            );
          }
          return http.Response('no', 400);
        }),
      ),
    );
    final net = FakeConnectivityMonitor(online: false);
    final c = DeliveryRouteController(api, net, MemoryOutboxStore());
    await c.load();
    expect(await c.start(1), isFalse);
    c.setPodDraft(
      const PodDraft(
        hasSignature: true,
        hasPhoto: true,
        latitude: 1,
        longitude: 2,
      ),
    );
    expect(await c.submitPod(1), isFalse);
    expect(c.state.error, contains('Offline'));
  });
}
