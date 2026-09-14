import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('post/put/patch send Idempotency-Key', () async {
    final seen = <String?>[];
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final client = ApiClient(
      env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        seen.add(request.headers['Idempotency-Key']);
        return http.Response('{}', 200);
      }),
    );
    await client.post('sales/', body: {}, idempotencyKey: 'k-post');
    await client.put('sales/1/', body: {}, idempotencyKey: 'k-put');
    await client.patch('sales/1/', body: {}, idempotencyKey: 'k-patch');
    expect(seen, ['k-post', 'k-put', 'k-patch']);
    client.close();
  });
}
