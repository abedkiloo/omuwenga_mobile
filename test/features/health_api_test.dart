import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/health/data/health_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ApiClient + HealthApi', () {
    test('resolve joins base and path', () {
      final client = ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: InMemoryTokenStore(),
      );
      expect(client.resolve('healthz/').toString(), 'http://example.com/api/healthz/');
      expect(client.resolve('/healthz/').toString(), 'http://example.com/api/healthz/');
      client.close();
    });

    test('get success and failure', () async {
      final tokens = InMemoryTokenStore();
      final okClient = ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: MockClient((request) async => http.Response('ok', 200)),
      );
      final ok = await okClient.get('healthz/');
      expect(ok.isSuccess, isTrue);
      okClient.close();

      final badClient = ApiClient(
        env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        tokenStore: tokens,
        httpClient: MockClient((request) async => throw Exception('network')),
      );
      final fail = await badClient.get('healthz/');
      expect(fail.isFailure, isTrue);
      badClient.close();
    });

    test('HealthApi maps HTTP status to HealthStatus', () async {
      final tokens = InMemoryTokenStore();
      final api = HealthApi(
        ApiClient(
          env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
          tokenStore: tokens,
          httpClient: MockClient((request) async => http.Response('{"status":"ok"}', 200)),
        ),
      );
      final result = await api.check();
      final status = result.getOrThrow();
      expect(status.ok, isTrue);
      expect(status.rawBody, contains('ok'));

      final badApi = HealthApi(
        ApiClient(
          env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
          tokenStore: tokens,
          httpClient: MockClient((request) async => http.Response('nope', 503)),
        ),
      );
      final bad = (await badApi.check()).getOrThrow();
      expect(bad.ok, isFalse);
    });
  });
}
