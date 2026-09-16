import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/health/data/health_api.dart';
import 'package:completebyte_pos_mobile/features/health/presentation/health_page.dart';
import 'package:completebyte_pos_mobile/features/health/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('app providers expose env, api client, and health api', () {
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        appEnvProvider.overrideWithValue(
          const AppEnv(
            flavor: AppFlavor.staging,
            apiBaseUrl: 'http://example.com/api',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(appEnvProvider).flavor, AppFlavor.staging);
    final client = container.read(apiClientProvider);
    expect(client.baseUrl, 'http://example.com/api');
    expect(container.read(healthApiProvider), isNotNull);
    expect(container.read(authApiProvider), isNotNull);
  });

  test('default providers dispose closes api client', () {
    final container = ProviderContainer(
      overrides: [tokenStoreProvider.overrideWithValue(InMemoryTokenStore())],
    );
    final client = container.read(apiClientProvider);
    expect(client.baseUrl, isNotEmpty);
    expect(container.read(appEnvProvider), isA<AppEnv>());
    container.dispose();
  });

  testWidgets('HealthPage FutureProvider error branch', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          healthCheckProvider.overrideWith((ref) async {
            throw Exception('provider boom');
          }),
        ],
        child: const MaterialApp(home: HealthPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
  });

  testWidgets('navigates to health route', (tester) async {
    final tokens = InMemoryTokenStore();
    final api = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient((_) async => http.Response('ok', 200)),
    );
    final router = GoRouter(
      initialLocation: AppRoutes.health,
      routes: [
        GoRoute(path: AppRoutes.health, builder: (_, _) => const HealthPage()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          appEnvProvider.overrideWithValue(
            const AppEnv(
              flavor: AppFlavor.dev,
              apiBaseUrl: 'http://example.com/api',
            ),
          ),
          apiClientProvider.overrideWithValue(api),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('API health'), findsOneWidget);
    expect(find.text('Backend reachable'), findsOneWidget);
  });

  testWidgets('HealthPage loading then Result failure branch', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          healthCheckProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 20));
            return Failure<HealthStatus>(Exception('timeout'));
          }),
        ],
        child: const MaterialApp(home: HealthPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Checking API…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    await tester.pumpAndSettle();
  });

  testWidgets('HealthPage success with empty body', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          healthCheckProvider.overrideWith(
            (ref) async => const Success(HealthStatus(ok: true, rawBody: '')),
          ),
        ],
        child: const MaterialApp(home: HealthPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('OK'), findsOneWidget);
  });
}
