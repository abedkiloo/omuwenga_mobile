import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/delivery/data/delivery_api.dart';
import 'package:completebyte_pos_mobile/features/delivery/domain/delivery_route_geometry.dart';
import 'package:completebyte_pos_mobile/features/delivery/domain/delivery_stop.dart';
import 'package:completebyte_pos_mobile/features/delivery/presentation/delivery_route_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fromJson requires geometry fields', () {
    expect(
      () => DeliveryRouteGeometry.fromJson({'id': 1, 'stops': []}),
      throwsA(isA<FormatException>()),
    );
  });

  test('fromJson and fromStops build pins and skip missing coords', () {
    final geo = DeliveryRouteGeometry.fromJson({
      'route_id': 8,
      'route_date': '2026-09-24',
      'delivery_agent_id': 3,
      'delivery_agent_name': 'Ken',
      'encoded_polyline': 'abc',
      'source': 'google',
      'depot': {
        'latitude': -1.29,
        'longitude': 36.82,
        'label': 'HQ',
        'placeholder': false,
      },
      'path': [
        {'latitude': -1.29, 'longitude': 36.82},
        {'latitude': -1.30, 'longitude': 36.80},
      ],
      'stops': [
        {
          'id': 4,
          'sequence': 1,
          'label': 'Blue gate',
          'latitude': -1.30,
          'longitude': 36.80,
        },
        {'id': 5, 'sequence': 2, 'label': 'No pin'},
      ],
    });
    expect(geo.routeId, 8);
    expect(geo.pins, hasLength(2));
    expect(geo.stops.single.sequence, 1);

    final local = DeliveryRouteGeometry.fromStops([
      DeliveryStop.fromJson({
        'id': 1,
        'sequence': 1,
        'status': 'pending',
        'site': {
          'id': 3,
          'label': '',
          'latitude': '-1.29',
          'longitude': '36.82',
        },
        'lines': [],
      }),
      DeliveryStop.fromJson({
        'id': 2,
        'sequence': 2,
        'status': 'pending',
        'site': {'id': 4, 'label': 'Yard'},
        'lines': [],
      }),
    ]);
    expect(local.stops, hasLength(1));
    expect(local.stops.first.label, 'Stop 1');
    expect(local.source, 'straight');
  });

  testWidgets('fallback map taps a numbered stop', (tester) async {
    var tapped = 0;
    final geo = DeliveryRouteGeometry.fromJson({
      'depot': {
        'latitude': -1.29,
        'longitude': 36.82,
        'label': 'HQ',
        'placeholder': true,
      },
      'encoded_polyline': '',
      'source': 'straight',
      'path': [],
      'stops': [
        {
          'id': 4,
          'sequence': 1,
          'label': 'Blue gate',
          'latitude': -1.30,
          'longitude': 36.80,
        },
      ],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FallbackDeliveryRouteMap(
            geometry: geo,
            onStopTap: (id) => tapped = id,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('delivery_map_depot')), findsOneWidget);
    await tester.tap(find.byKey(const Key('delivery_map_stop_4')));
    expect(tapped, 4);
  });

  testWidgets('route map card shows straight-line notice', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: DeliveryRouteMapCard(
              usePlatformMap: false,
              geometry: DeliveryRouteGeometry(
                source: 'straight',
                depot: RouteMapPin(
                  latitude: -1.29,
                  longitude: 36.82,
                  label: 'HQ',
                  isDepot: true,
                  placeholder: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.textContaining('straight fallback'), findsOneWidget);
    expect(find.textContaining('Nairobi default'), findsOneWidget);
  });

  test('todayGeometry parses and rejects bad payloads', () async {
    final api = DeliveryApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((request) async {
          if (request.url.path.contains('geometry')) {
            return http.Response(
              jsonEncode({
                'depot': {'latitude': -1.29, 'longitude': 36.82, 'label': 'HQ'},
                'encoded_polyline': 'abc',
                'source': 'straight',
                'path': [
                  {'latitude': -1.29, 'longitude': 36.82},
                ],
                'stops': [],
              }),
              200,
            );
          }
          return http.Response('nope', 500);
        }),
      ),
    );
    final geo = (await api.todayGeometry()).getOrThrow();
    expect(geo.source, 'straight');
    expect(geo.depot!.label, 'HQ');

    final bad = DeliveryApi(
      ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: InMemoryTokenStore(),
        httpClient: MockClient((request) async => http.Response('[]', 200)),
      ),
    );
    expect((await bad.todayGeometry()).isFailure, isTrue);
  });
}
