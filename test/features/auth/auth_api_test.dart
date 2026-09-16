import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/data/auth_api.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _loginPayload({
  String role = 'cashier',
  bool dailySales = false,
  bool isSuperAdmin = false,
}) {
  return {
    'access': 'access-token',
    'refresh': 'refresh-token',
    'user': {
      'id': 1,
      'username': 'sales',
      'first_name': 'Sam',
      'last_name': 'Seller',
      'is_superuser': isSuperAdmin,
    },
    'profile': {
      'role': role,
      'is_super_admin': isSuperAdmin,
      'is_admin': false,
      'is_manager': role == 'manager',
      'role_display': role,
    },
    'permissions': [
      {'module': 'pos', 'action': 'view'},
      {'module': 'pos', 'action': 'create'},
      {'module': 'customers', 'action': 'view'},
      if (dailySales) {'module': 'sales', 'action': 'daily_sales'},
    ],
  };
}

void main() {
  late InMemoryTokenStore tokens;

  setUp(() {
    tokens = InMemoryTokenStore();
  });

  test('login success stores tokens and builds session', () async {
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/accounts/auth/login/'));
        expect(request.headers['Authorization'], isNull);
        return http.Response(jsonEncode(_loginPayload()), 200);
      }),
    );
    final api = AuthApi(client: client, tokenStore: tokens);
    final result = await api.login(username: 'sales', password: 'sales123');
    final session = result.getOrThrow();
    expect(session.persona, AppPersona.cashier);
    expect(await tokens.readAccess(), 'access-token');
    expect(await tokens.readRefresh(), 'refresh-token');
    client.close();
  });

  test('login failure invalid credentials', () async {
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient(
        (_) async => http.Response('{"error":"Invalid credentials"}', 401),
      ),
    );
    final api = AuthApi(client: client, tokenStore: tokens);
    final result = await api.login(username: 'x', password: 'y');
    expect(result.isFailure, isTrue);
    expect(
      result.when(success: (_) => '', failure: (e, _) => e.toString()),
      contains('Invalid'),
    );
    expect(await tokens.readAccess(), isNull);
    client.close();
  });

  test('me success and logout clears tokens', () async {
    await tokens.writeTokens(access: 'a', refresh: 'r');
    var logoutCalled = false;
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/me/')) {
          expect(request.headers['Authorization'], 'Bearer a');
          return http.Response(
            jsonEncode(_loginPayload(role: 'manager', dailySales: true)),
            200,
          );
        }
        if (request.url.path.contains('/logout/')) {
          logoutCalled = true;
          return http.Response('{"message":"ok"}', 200);
        }
        return http.Response('nope', 404);
      }),
    );
    final api = AuthApi(client: client, tokenStore: tokens);
    final me = (await api.me()).getOrThrow();
    expect(me.persona, AppPersona.manager);
    expect(me.permissions.canViewDailySales, isTrue);
    await api.logout();
    expect(logoutCalled, isTrue);
    expect(await tokens.readAccess(), isNull);
    client.close();
  });

  test('ApiClient refreshes once on 401', () async {
    await tokens.writeTokens(access: 'old', refresh: 'refresh-token');
    var calls = 0;
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        calls++;
        if (request.url.path.contains('/token/refresh/')) {
          return http.Response(jsonEncode({'access': 'new'}), 200);
        }
        final auth = request.headers['Authorization'];
        if (auth == 'Bearer old') {
          return http.Response('expired', 401);
        }
        if (auth == 'Bearer new') {
          return http.Response('{"ok":true}', 200);
        }
        return http.Response('bad', 500);
      }),
    );
    final result = await client.get('accounts/auth/me/');
    expect(result.isSuccess, isTrue);
    expect(await tokens.readAccess(), 'new');
    expect(calls, greaterThanOrEqualTo(3));
    client.close();
  });

  test('safeMessage never echoes stack', () {
    expect(AuthApi.safeMessage('not-json'), contains('Something went wrong'));
    expect(AuthApi.safeMessage('{"error":"Nope"}'), 'Nope');
    expect(AuthApi.safeMessage('{"detail":"Denied"}'), 'Denied');
  });

  test('login missing tokens and bad JSON', () async {
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient(
        (_) async => http.Response('{"access":"only"}', 200),
      ),
    );
    final api = AuthApi(client: client, tokenStore: tokens);
    expect((await api.login(username: 'a', password: 'b')).isFailure, isTrue);
    client.close();

    final bad = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient((_) async => http.Response('not-json', 200)),
    );
    expect(
      (await AuthApi(
        client: bad,
        tokenStore: tokens,
      ).login(username: 'a', password: 'b')).isFailure,
      isTrue,
    );
    bad.close();
  });

  test('me session expired and server errors', () async {
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient((_) async => http.Response('{}', 401)),
    );
    // Refresh will also fail → session expired from client layer
    final api = AuthApi(client: client, tokenStore: tokens);
    expect((await api.me()).isFailure, isTrue);
    client.close();
  });

  test('ApiClient session expired when refresh fails', () async {
    await tokens.writeTokens(access: 'old', refresh: 'bad');
    var expired = false;
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      onSessionExpired: () => expired = true,
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/token/refresh/')) {
          return http.Response('nope', 401);
        }
        return http.Response('expired', 401);
      }),
    );
    final result = await client.get('accounts/auth/me/');
    expect(result.isFailure, isTrue);
    expect(expired, isTrue);
    expect(await tokens.readAccess(), isNull);
    client.close();
  });

  test('logout without refresh token still clears', () async {
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
    await AuthApi(client: client, tokenStore: tokens).logout();
    expect(await tokens.readAccess(), isNull);
    client.close();
  });
}
