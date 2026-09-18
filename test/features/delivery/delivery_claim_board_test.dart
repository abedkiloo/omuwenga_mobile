import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/store_shell.dart';
import 'package:completebyte_pos_mobile/features/delivery/application/delivery_controllers.dart';
import 'package:completebyte_pos_mobile/features/delivery/data/delivery_api.dart';
import 'package:completebyte_pos_mobile/features/delivery/domain/delivery_stop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AuthSession _driverSession() {
  return AuthSession(
    user: const AuthUser(
      id: 9,
      username: 'driver',
      firstName: 'Dee',
      lastName: 'Liver',
    ),
    profile: const UserProfileSnapshot(
      role: 'delivery',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
    ),
    permissions: PermissionSet([
      const PermissionGrant(module: 'delivery', action: 'view'),
      const PermissionGrant(module: 'delivery', action: 'update'),
    ]),
    persona: AppPersona.deliveryDriver,
  );
}

Map<String, dynamic> _stopJson({int id = 5, int orderId = 44}) {
  return {
    'id': id,
    'sequence': 1,
    'status': 'pending',
    'field_order_id': orderId,
    'customer_name': 'Assigned Shop',
    'site': {
      'id': 1,
      'label': 'Gate',
      'latitude': '-1.3',
      'longitude': '36.8',
      'media': [],
    },
    'lines': [],
  };
}

Map<String, dynamic> _readyOrderJson({int id = 77}) {
  return {
    'id': id,
    'status': 'ready',
    'site': 2,
    'site_detail': {
      'id': 2,
      'label': 'Yard',
      'latitude': '-1.2',
      'longitude': '36.7',
    },
    'customer_name': 'Claimable Shop',
    'lines': [
      {
        'product_id': 1,
        'product_name': 'Paint',
        'quantity': '3',
        'unit_price': '10',
      },
    ],
    'assigned_delivery_agent_id': null,
    'stock_allocated': true,
  };
}

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
  group('api', () {
    test('available and claim parse', () async {
      final api = _api(
        MockClient((request) async {
          if (request.url.path.contains('/available/')) {
            return http.Response(jsonEncode([_readyOrderJson()]), 200);
          }
          if (request.url.path.contains('/claim/')) {
            return http.Response(
              jsonEncode({
                ..._readyOrderJson(),
                'status': 'out_for_delivery',
                'assigned_delivery_agent_id': 9,
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      expect((await api.available()).getOrThrow().single.id, 77);
      expect(
        (await api.claim(77)).getOrThrow().assignedDeliveryDriverId,
        9,
      );

      final bad = _api(MockClient((_) async => http.Response('x', 500)));
      expect((await bad.available()).isFailure, isTrue);
      expect((await bad.claim(1)).isFailure, isTrue);
    });
  });

  group('board controller', () {
    test('loads assigned before available and claim refreshes', () async {
      var claimed = false;
      final api = _api(
        MockClient((request) async {
          if (request.url.path.contains('/config/')) {
            return http.Response(
              jsonEncode({
                'require_pod_to_complete': true,
                'allow_offline_pod_queue': true,
              }),
              200,
            );
          }
          if (request.url.path.contains('/routes/today/')) {
            return http.Response(
              jsonEncode({
                'id': 1,
                'route_date': '2026-09-18',
                'stops': claimed
                    ? [_stopJson(), _stopJson(id: 6, orderId: 77)]
                    : [_stopJson()],
                'next_stop_id': 5,
              }),
              200,
            );
          }
          if (request.url.path.contains('/available/')) {
            return http.Response(
              jsonEncode(claimed ? [] : [_readyOrderJson()]),
              200,
            );
          }
          if (request.url.path.contains('/claim/')) {
            claimed = true;
            return http.Response(
              jsonEncode({
                ..._readyOrderJson(),
                'status': 'out_for_delivery',
                'assigned_delivery_agent_id': 9,
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      final c = DeliveryBoardController(api);
      await c.load();
      expect(c.state.assigned, hasLength(1));
      expect(c.state.available, hasLength(1));
      expect(await c.claim(77), isTrue);
      expect(c.state.available, isEmpty);
      expect(c.state.assigned, hasLength(2));
    });

    test('claim failure surfaces error', () async {
      final c = DeliveryBoardController(
        _api(
          MockClient((request) async {
            if (request.url.path.contains('/routes/today/')) {
              return http.Response(
                jsonEncode({
                  'id': 1,
                  'route_date': '2026-09-18',
                  'stops': [],
                }),
                200,
              );
            }
            if (request.url.path.contains('/available/')) {
              return http.Response(jsonEncode([_readyOrderJson()]), 200);
            }
            return http.Response('no', 400);
          }),
        ),
      );
      await c.load();
      expect(await c.claim(77), isFalse);
      expect(c.state.error, isNotNull);
    });
  });

  group('widgets', () {
    testWidgets('delivery home shows assigned and claimable', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionSeedProvider.overrideWithValue(_driverSession()),
            deliveryApiProvider.overrideWithValue(
              _api(
                MockClient((request) async {
                  if (request.url.path.contains('/routes/today/')) {
                    return http.Response(
                      jsonEncode({
                        'id': 1,
                        'route_date': '2026-09-18',
                        'stops': [_stopJson()],
                        'next_stop_id': 5,
                      }),
                      200,
                    );
                  }
                  if (request.url.path.contains('/available/')) {
                    return http.Response(
                      jsonEncode([_readyOrderJson()]),
                      200,
                    );
                  }
                  if (request.url.path.contains('/claim/')) {
                    return http.Response(
                      jsonEncode({
                        ..._readyOrderJson(),
                        'status': 'out_for_delivery',
                        'assigned_delivery_agent_id': 9,
                      }),
                      200,
                    );
                  }
                  return http.Response(
                    jsonEncode({
                      'require_pod_to_complete': true,
                      'allow_offline_pod_queue': true,
                    }),
                    200,
                  );
                }),
              ),
            ),
          ],
          child: MaterialApp.router(
            routerConfig: GoRouter(
              initialLocation: '/home',
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (_, _) => const PersonaHomePage(),
                ),
                GoRoute(
                  path: '/delivery',
                  builder: (_, _) => const Scaffold(body: Text('route')),
                ),
                GoRoute(
                  path: '/delivery/stops/:id',
                  builder: (_, _) => const Scaffold(body: Text('stop')),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Delivery ·'), findsOneWidget);
      expect(find.byKey(const Key('delivery_home_assigned_5')), findsOneWidget);
      expect(
        find.byKey(const Key('delivery_home_claimable_77')),
        findsOneWidget,
      );
      expect(find.text('Assigned Shop'), findsOneWidget);
      expect(find.text('Claimable Shop'), findsOneWidget);

      await tester.tap(find.byKey(const Key('delivery_home_claim_77')));
      await tester.pumpAndSettle();
    });
  });

  test('stop parses field_order_id', () {
    final stop = DeliveryStop.fromJson(_stopJson());
    expect(stop.fieldOrderId, 44);
    expect(stop.customerName, 'Assigned Shop');
  });
}
