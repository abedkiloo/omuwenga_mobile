import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/login_page.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/store_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';

void main() {
  test('InMemoryTokenStore round-trip', () async {
    final store = InMemoryTokenStore();
    await store.writeTokens(access: 'a', refresh: 'r');
    expect(await store.readAccess(), 'a');
    expect(await store.readRefresh(), 'r');
    await store.writeAccess('b');
    expect(await store.readAccess(), 'b');
    await store.clear();
    expect(await store.readAccess(), isNull);
  });

  test('AuthController bootstrap unauthenticated without tokens', () async {
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.notifier).bootstrap();
    expect(container.read(authControllerProvider).status, AuthStatus.unauthenticated);
  });

  test('AuthController login success and markSessionExpired', () async {
    final tokens = InMemoryTokenStore();
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        ),
        apiClientProvider.overrideWith((ref) {
          return ApiClient(
            env: ref.watch(appEnvProvider),
            tokenStore: tokens,
            httpClient: MockClient((request) async {
              if (request.url.path.contains('/login/')) {
                return http.Response(
                  jsonEncode({
                    'access': 'a',
                    'refresh': 'r',
                    'user': {'id': 1, 'username': 'sales', 'first_name': 'Sam'},
                    'profile': {
                      'role': 'cashier',
                      'is_super_admin': false,
                      'is_admin': false,
                      'is_manager': false,
                    },
                    'permissions': [
                      {'module': 'pos', 'action': 'view'},
                    ],
                  }),
                  200,
                );
              }
              return http.Response('{}', 200);
            }),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final auth = container.read(authControllerProvider.notifier);
    final result = await auth.login(username: 'sales', password: 'x');
    expect(result.isSuccess, isTrue);
    expect(container.read(authControllerProvider).isAuthenticated, isTrue);
    auth.markSessionExpired();
    expect(container.read(authControllerProvider).status, AuthStatus.unauthenticated);
    expect(container.read(authControllerProvider).message, contains('Session expired'));
    auth.clearMessage();
    expect(container.read(authControllerProvider).message, isNull);
  });

  test('AuthController logout and bootstrap with bad me', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        ),
        apiClientProvider.overrideWith((ref) {
          return ApiClient(
            env: ref.watch(appEnvProvider),
            tokenStore: tokens,
            httpClient: MockClient((request) async {
              if (request.url.path.contains('/me/')) {
                return http.Response('nope', 500);
              }
              if (request.url.path.contains('/logout/')) {
                return http.Response('{}', 200);
              }
              if (request.url.path.contains('/token/refresh/')) {
                return http.Response('{}', 401);
              }
              return http.Response('{}', 200);
            }),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authControllerProvider.notifier).bootstrap();
    expect(container.read(authControllerProvider).status, AuthStatus.unauthenticated);

    await tokens.writeTokens(access: 'a', refresh: 'r');
    final seeded = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        ),
        authSessionSeedProvider.overrideWithValue(
          AuthSession(
            user: const AuthUser(id: 1, username: 'u'),
            profile: const UserProfileSnapshot(
              role: 'cashier',
              isSuperAdmin: false,
              isAdmin: false,
              isManager: false,
            ),
            permissions: PermissionSet(const []),
            persona: AppPersona.cashier,
          ),
        ),
        apiClientProvider.overrideWith((ref) {
          return ApiClient(
            env: ref.watch(appEnvProvider),
            tokenStore: tokens,
            httpClient: MockClient((_) async => http.Response('{}', 200)),
          );
        }),
      ],
    );
    addTearDown(seeded.dispose);
    expect(seeded.read(authControllerProvider).isAuthenticated, isTrue);
    await seeded.read(authControllerProvider.notifier).logout();
    expect(seeded.read(authControllerProvider).status, AuthStatus.unauthenticated);
  });

  testWidgets('login page success rebuilds to cashier home', (tester) async {
    final tokens = InMemoryTokenStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(tokens),
          appEnvProvider.overrideWithValue(
            const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
          ),
          apiClientProvider.overrideWith((ref) {
            return ApiClient(
              env: ref.watch(appEnvProvider),
              tokenStore: tokens,
              httpClient: MockClient((request) async {
                if (request.url.path.contains('/login/')) {
                  return http.Response(
                    jsonEncode({
                      'access': 'a',
                      'refresh': 'r',
                      'user': {
                        'id': 1,
                        'username': 'sales',
                        'first_name': 'Sam',
                        'last_name': 'Cash',
                      },
                      'profile': {
                        'role': 'cashier',
                        'is_super_admin': false,
                        'is_admin': false,
                        'is_manager': false,
                      },
                      'permissions': [
                        {'module': 'pos', 'action': 'view'},
                        {'module': 'pos', 'action': 'create'},
                        {'module': 'customers', 'action': 'view'},
                      ],
                    }),
                    200,
                  );
                }
                return http.Response('{}', 200);
              }),
            );
          }),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final auth = ref.watch(authControllerProvider);
            if (auth.isAuthenticated) {
              final router = GoRouter(
                initialLocation: AppRoutes.home,
                routes: [
                  GoRoute(path: AppRoutes.home, builder: (_, _) => const PersonaHomePage()),
                  GoRoute(path: AppRoutes.pos, builder: (_, _) => const Text('pos')),
                  GoRoute(path: AppRoutes.customers, builder: (_, _) => const Text('c')),
                ],
              );
              return MaterialApp.router(routerConfig: router);
            }
            return const MaterialApp(home: LoginPage());
          },
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('login_username')), 'sales');
    await tester.enterText(find.byKey(const Key('login_password')), 'sales123');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('New sale'), findsOneWidget);
  });
}
