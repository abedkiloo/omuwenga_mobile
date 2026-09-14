import 'package:completebyte_pos_mobile/app/providers.dart';
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
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('HealthPage shows reachable state', (tester) async {
    final mockHttp = MockClient((request) async => http.Response('{"ok":true}', 200));
    final tokens = InMemoryTokenStore();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          appEnvProvider.overrideWithValue(
            const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
          ),
          apiClientProvider.overrideWithValue(
            ApiClient(
              env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
              tokenStore: tokens,
              httpClient: mockHttp,
            ),
          ),
        ],
        child: const MaterialApp(home: HealthPage()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Backend reachable'), findsOneWidget);
    await tester.tap(find.text('Check again'));
    await tester.pumpAndSettle();
    expect(find.text('Backend reachable'), findsOneWidget);
  });

  testWidgets('HealthPage shows error when API fails', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          healthCheckProvider.overrideWith(
            (ref) async => Failure<HealthStatus>(Exception('down')),
          ),
        ],
        child: const MaterialApp(home: HealthPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('HealthPage shows error when HTTP not OK', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          healthCheckProvider.overrideWith(
            (ref) async => const Success(HealthStatus(ok: false, rawBody: '503')),
          ),
        ],
        child: const MaterialApp(home: HealthPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('HTTP not OK'), findsOneWidget);
  });
}
