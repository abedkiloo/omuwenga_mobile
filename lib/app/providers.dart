import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../core/env/app_env.dart';
import '../core/network/api_client.dart';
import '../core/secure/secure_token_store.dart';
import '../core/secure/token_store.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/auth_api.dart';

final appEnvProvider = Provider<AppEnv>((ref) {
  return AppEnv.fromDefines();
});

final tokenStoreProvider = Provider<TokenStore>((ref) {
  return SecureTokenStore();
});

/// Optional override for tests; production uses the default `http.Client`.
final httpClientProvider = Provider<http.Client?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    env: ref.watch(appEnvProvider),
    tokenStore: ref.watch(tokenStoreProvider),
    httpClient: ref.watch(httpClientProvider),
    onSessionExpired: () {
      ref.read(authControllerProvider.notifier).markSessionExpired();
    },
  );
  ref.onDispose(client.close);
  return client;
});

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(
    client: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});
