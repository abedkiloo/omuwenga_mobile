import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/module_features.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
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

AuthSession _session({required bool cameraScan}) {
  return AuthSession(
    user: const AuthUser(
      id: 1,
      username: 'cashier',
      firstName: 'Sam',
      lastName: 'Cash',
    ),
    profile: const UserProfileSnapshot(
      role: 'cashier',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
    ),
    permissions: PermissionSet(const [
      PermissionGrant(module: 'pos', action: 'view'),
      PermissionGrant(module: 'pos', action: 'create'),
    ]),
    persona: AppPersona.cashier,
    features: ModuleFeatures(
      enabled: {
        'sales': {
          'pos': true,
          'camera_barcode_scan': cameraScan,
        },
      },
    ),
  );
}

List<Override> _overrides({
  required MockClient httpClient,
  required AuthSession session,
}) {
  final tokens = InMemoryTokenStore();
  return [
    tokenStoreProvider.overrideWithValue(tokens),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
    authSessionSeedProvider.overrideWithValue(session),
    httpClientProvider.overrideWithValue(httpClient),
    apiClientProvider.overrideWith((ref) {
      return ApiClient(
        env: ref.watch(appEnvProvider),
        tokenStore: tokens,
        httpClient: httpClient,
      );
    }),
    outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
    connectivityMonitorProvider.overrideWithValue(
      FakeConnectivityMonitor(online: true),
    ),
    posSettingsProvider.overrideWith((ref) async => const PosSettings()),
  ];
}

MockClient _catalogClient({
  List<Map<String, Object?>> searchHits = const [],
}) {
  return MockClient((request) async {
    if (request.url.path.contains('/products/search/')) {
      return http.Response(jsonEncode(searchHits), 200);
    }
    if (request.url.path.contains('/products/') &&
        !request.url.path.contains('/variants/')) {
      return http.Response(
        jsonEncode({
          'count': 0,
          'next': null,
          'previous': null,
          'results': <Object>[],
        }),
        200,
      );
    }
    return http.Response('{}', 200);
  });
}

void main() {
  testWidgets('HID Enter on barcode exact-adds to cart', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          httpClient: _catalogClient(
            searchHits: [
              {
                'id': 44,
                'name': 'Barcode Soap',
                'sku': 'SOAP-1',
                'barcode': '6281001234567',
                'selling_price': 25,
                'stock_quantity': 8,
              },
            ],
          ),
          session: _session(cameraScan: true),
        ),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('pos_search')), '6281001234567');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Barcode Soap added'), findsOneWidget);
    expect(find.textContaining('Barcode Soap'), findsWidgets);
  });

  testWidgets('scan button with camera feature off shows guidance', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          httpClient: _catalogClient(),
          session: _session(cameraScan: false),
        ),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Search SKU / barcode (Bluetooth gun)…'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('pos_search_button')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Camera scan is off'), findsOneWidget);
  });

  testWidgets('unknown barcode shows not-found snackbar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          httpClient: _catalogClient(),
          session: _session(cameraScan: true),
        ),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('pos_search')), '999000111222');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.textContaining('No product for'), findsOneWidget);
  });

  testWidgets('scan adds product that does not track stock', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          httpClient: _catalogClient(
            searchHits: [
              {
                'id': 55,
                'name': 'Service Fee',
                'sku': 'SVC-1',
                'barcode': '555000111222',
                'selling_price': 100,
                'track_stock': false,
              },
            ],
          ),
          session: _session(cameraScan: true),
        ),
        child: const MaterialApp(home: PosPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('pos_search')), '555000111222');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('Service Fee added'), findsOneWidget);
    expect(find.textContaining('no available stock'), findsNothing);
  });
}
