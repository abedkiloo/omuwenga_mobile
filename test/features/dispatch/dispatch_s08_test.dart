import 'dart:convert';

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
import 'package:completebyte_pos_mobile/features/field_orders/domain/field_order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AuthSession _dispatcherSession({bool canUpdate = true}) {
  return AuthSession(
    user: const AuthUser(
      id: 3,
      username: 'dispatch',
      firstName: 'Di',
      lastName: 'Patch',
    ),
    profile: const UserProfileSnapshot(
      role: 'manager',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: true,
    ),
    permissions: PermissionSet([
      const PermissionGrant(module: 'dispatch', action: 'view'),
      if (canUpdate)
        const PermissionGrant(module: 'dispatch', action: 'update'),
    ]),
    persona: AppPersona.dispatcher,
  );
}

Map<String, dynamic> _orderJson({int id = 11, String status = 'submitted'}) {
  return {
    'id': id,
    'status': status,
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
    'assigned_delivery_agent_id': null,
    'stock_allocated': status != 'submitted',
  };
}

DispatchApi _api(MockClient client) {
  return DispatchApi(
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
    test('queue pack assign drivers and error paths', () async {
      final api = _api(
        MockClient((request) async {
          if (request.url.path.contains('/drivers/') &&
              request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'id': 201,
                'username': 'drvken',
                'display_name': 'Ken Mutua',
                'phone_number': '254712345678',
                'temporary_password': 'tmpPass99',
              }),
              201,
            );
          }
          if (request.url.path.contains('/drivers/')) {
            return http.Response(
              jsonEncode([
                {
                  'id': 101,
                  'username': 'drv_a',
                  'display_name': 'Driver A',
                },
                {
                  'id': 102,
                  'username': 'drv_b',
                  'display_name': 'Driver B',
                },
              ]),
              200,
            );
          }
          if (request.url.path.contains('/queue/')) {
            return http.Response(jsonEncode([_orderJson()]), 200);
          }
          if (request.url.path.contains('/pack/')) {
            return http.Response(jsonEncode(_orderJson(status: 'ready')), 200);
          }
          if (request.url.path.contains('/assign/')) {
            final body = jsonDecode(request.body) as Map;
            expect(body['delivery_agent_id'], 101);
            return http.Response(
              jsonEncode({
                ..._orderJson(status: 'out_for_delivery'),
                'assigned_delivery_agent_id': 101,
              }),
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      expect((await api.queue()).getOrThrow().single.id, 11);
      expect((await api.drivers()).getOrThrow().first.displayName, 'Driver A');
      final created = await api.createDriver(
        displayName: 'Ken Mutua',
        phone: '0712345678',
      );
      expect(created.getOrThrow().temporaryPassword, 'tmpPass99');
      expect((await api.pack(11)).getOrThrow().stockAllocated, isTrue);
      expect(
        (await api.assign(
          orderId: 11,
          deliveryDriverId: 101,
        )).getOrThrow().assignedDeliveryDriverId,
        101,
      );

      final bad = _api(MockClient((_) async => http.Response('x', 500)));
      expect((await bad.queue()).isFailure, isTrue);
      expect((await bad.drivers()).isFailure, isTrue);
      expect(
        (await bad.createDriver(displayName: 'A', phone: '0712')).isFailure,
        isTrue,
      );
      expect((await bad.pack(1)).isFailure, isTrue);
      expect(
        (await bad.assign(orderId: 1, deliveryDriverId: 1)).isFailure,
        isTrue,
      );

      final invalid = _api(MockClient((_) async => http.Response('{}', 200)));
      expect((await invalid.queue()).isFailure, isTrue);
      expect((await invalid.drivers()).isFailure, isTrue);
      expect((await invalid.pack(1)).isFailure, isTrue);

      final net = DispatchApi(
        ApiClient(
          env: const AppEnv(
            flavor: AppFlavor.dev,
            apiBaseUrl: 'http://example.com/api',
          ),
          tokenStore: InMemoryTokenStore(),
          httpClient: MockClient((_) async => throw Exception('down')),
        ),
      );
      expect((await net.queue()).isFailure, isTrue);
      expect(DispatchApiException('e').toString(), 'e');
    });
  });

  group('controller', () {
    test('assign requires driver selected', () async {
      final push = FakePushNotifier();
      final api = _api(
        MockClient((request) async {
          if (request.url.path.contains('/drivers/')) {
            return http.Response(
              jsonEncode([
                {'id': 101, 'username': 'a', 'display_name': 'Driver A'},
              ]),
              200,
            );
          }
          if (request.url.path.contains('/queue/')) {
            return http.Response(jsonEncode([_orderJson()]), 200);
          }
          if (request.url.path.contains('/pack/')) {
            return http.Response(jsonEncode(_orderJson(status: 'ready')), 200);
          }
          return http.Response(
            jsonEncode({
              ..._orderJson(status: 'out_for_delivery'),
              'assigned_delivery_agent_id': 101,
            }),
            200,
          );
        }),
      );
      final c = DispatchQueueController(api, push);
      await c.load();
      expect(c.state.orders, isNotEmpty);
      expect(c.state.drivers, isNotEmpty);
      expect(c.state.canAssign, isFalse);
      expect(await c.assign(11), isFalse);
      expect(c.state.error, contains('Select a delivery driver'));
      c.selectDeliveryDriver(101);
      expect(c.state.canAssign, isTrue);
      expect(await c.pack(11), isTrue);
      expect(await c.assign(11), isTrue);
      expect(push.sent.length, greaterThanOrEqualTo(2));
      c.selectDeliveryDriver(null);
      expect(c.state.selectedDeliveryDriverId, isNull);
    });

    test('createDriver validates and appends', () async {
      final c = DispatchQueueController(
        _api(
          MockClient((request) async {
            if (request.method == 'POST' &&
                request.url.path.contains('/drivers/')) {
              return http.Response(
                jsonEncode({
                  'id': 201,
                  'username': 'drvken',
                  'display_name': 'Ken Mutua',
                  'temporary_password': 'tmpPass99',
                }),
                201,
              );
            }
            if (request.url.path.contains('/drivers/')) {
              return http.Response(jsonEncode([]), 200);
            }
            return http.Response(jsonEncode([]), 200);
          }),
        ),
        FakePushNotifier(),
      );
      expect(await c.createDriver(displayName: '', phone: '0712'), isNull);
      expect(await c.createDriver(displayName: 'Ken', phone: ''), isNull);
      final driver = await c.createDriver(
        displayName: 'Ken Mutua',
        phone: '0712345678',
      );
      expect(driver?.id, 201);
      expect(c.state.selectedDeliveryDriverId, 201);
      expect(c.state.lastCreatedTempPassword, 'tmpPass99');
    });

    test('load and action failures', () async {
      final c = DispatchQueueController(
        _api(MockClient((_) async => http.Response('no', 400))),
        FakePushNotifier(),
      );
      await c.load();
      expect(c.state.error, isNotNull);
      c.selectDeliveryDriver(1);
      expect(await c.pack(1), isFalse);
      expect(await c.assign(1), isFalse);
    });
  });

  group('widgets', () {
    testWidgets('assign CTA disabled until driver selected', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authSessionSeedProvider.overrideWithValue(_dispatcherSession()),
          dispatchApiProvider.overrideWithValue(
            _api(
              MockClient((request) async {
                if (request.url.path.contains('/drivers/')) {
                  return http.Response(
                    jsonEncode([
                      {
                        'id': 101,
                        'username': 'a',
                        'display_name': 'Driver A',
                      },
                    ]),
                    200,
                  );
                }
                if (request.url.path.contains('/queue/')) {
                  return http.Response(jsonEncode([_orderJson()]), 200);
                }
                return http.Response(
                  jsonEncode(_orderJson(status: 'ready')),
                  200,
                );
              }),
            ),
          ),
          pushNotifierProvider.overrideWithValue(FakePushNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DispatchOrderDetailPage(orderId: 11)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dispatch_map')), findsOneWidget);
      final assign = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('dispatch_assign')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(assign.onPressed, isNull);

      await tester.tap(find.byKey(const Key('dispatch_driver_select')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Driver A').last);
      await tester.pumpAndSettle();

      final assignEnabled = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const Key('dispatch_assign')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(assignEnabled.onPressed, isNotNull);
      expect(find.byKey(const Key('dispatch_add_driver')), findsOneWidget);
    });

    testWidgets('view-only hides mark-ready actions', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionSeedProvider.overrideWithValue(
              _dispatcherSession(canUpdate: false),
            ),
            dispatchApiProvider.overrideWithValue(
              _api(
                MockClient((request) async {
                  if (request.url.path.contains('/drivers/')) {
                    return http.Response(jsonEncode([]), 200);
                  }
                  if (request.url.path.contains('/queue/')) {
                    return http.Response(jsonEncode([_orderJson()]), 200);
                  }
                  return http.Response(jsonEncode(_orderJson()), 200);
                }),
              ),
            ),
            pushNotifierProvider.overrideWithValue(FakePushNotifier()),
          ],
          child: const MaterialApp(home: DispatchOrderDetailPage(orderId: 11)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dispatch_pack')), findsNothing);
      expect(find.byKey(const Key('dispatch_assign')), findsNothing);
    });

    testWidgets('queue list empty state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dispatchApiProvider.overrideWithValue(
              _api(
                MockClient((request) async {
                  if (request.url.path.contains('/drivers/')) {
                    return http.Response(jsonEncode([]), 200);
                  }
                  return http.Response(jsonEncode([]), 200);
                }),
              ),
            ),
            pushNotifierProvider.overrideWithValue(FakePushNotifier()),
          ],
          child: const MaterialApp(home: DispatchQueuePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Queue clear'), findsOneWidget);
    });

    testWidgets('queue shows order row', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dispatchApiProvider.overrideWithValue(
              _api(
                MockClient((request) async {
                  if (request.url.path.contains('/drivers/')) {
                    return http.Response(jsonEncode([]), 200);
                  }
                  return http.Response(jsonEncode([_orderJson()]), 200);
                }),
              ),
            ),
            pushNotifierProvider.overrideWithValue(FakePushNotifier()),
          ],
          child: const MaterialApp(home: DispatchQueuePage()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('dispatch_order_11')), findsOneWidget);
    });
  });

  test('summary assigned driver parse', () {
    final s = FieldOrderSummary.fromJson({
      ..._orderJson(),
      'assigned_delivery_agent_id': 9,
      'stock_allocated': true,
    });
    expect(s.assignedDeliveryDriverId, 9);
    expect(s.stockAllocated, isTrue);
  });
}
