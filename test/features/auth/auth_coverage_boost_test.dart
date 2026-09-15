import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/app/router.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/data/auth_api.dart';
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

import 'auth_fixtures.dart';

void main() {
  test('PermissionSet from plain Map and name', () {
    expect(PermissionSet.fromJsonList(null).isEmpty, isTrue);
    final set = PermissionSet.fromJsonList([
      <dynamic, dynamic>{'module': 'sales', 'action': 'view', 'name': 'sales.view'},
    ]);
    expect(set.canViewSales, isTrue);
    expect(PermissionGrant.fromJson({'module': 'x', 'action': 'y', 'name': 'x.y'}).name, 'x.y');
  });

  test('AuthApi me unexpected body', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final client = ApiClient(
      env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
      tokenStore: tokens,
      httpClient: MockClient((_) async => http.Response('[]', 200)),
    );
    final result = await AuthApi(client: client, tokenStore: tokens).me();
    expect(result.isFailure, isTrue);
    client.close();
  });

  test('AuthSession displayName and null profile', () {
    final session = AuthSession.fromAuthPayload({
      'user': {'id': 9, 'username': 'solo'},
      'profile': null,
      'permissions': [],
    });
    expect(session.user.displayName, 'solo');
    expect(session.persona, AppPersona.cashier);
  });

  test('AuthApi me success and login server error', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final client = ApiClient(
      env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/me/')) {
          return http.Response(
            jsonEncode({
              'user': {'id': 1, 'username': 'sales'},
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
        return http.Response('{"error":"Locked"}', 500);
      }),
    );
    final api = AuthApi(client: client, tokenStore: tokens);
    expect((await api.me()).isSuccess, isTrue);
    expect((await api.login(username: 'a', password: 'b')).isFailure, isTrue);
    client.close();
  });

  test('ApiClient refresh missing access + auth false', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'old', refresh: 'r');
    final client = ApiClient(
      env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        if (request.url.path.contains('/token/refresh/')) {
          return http.Response('{"refresh":"no-access"}', 200);
        }
        if (request.url.path.contains('healthz')) {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('ok', 200);
        }
        return http.Response('expired', 401);
      }),
    );
    expect((await client.get('x/')).isFailure, isTrue);
    await client.get('healthz/', auth: false);
    expect(AuthSessionExpiredException().toString(), contains('Session expired'));
    client.close();
  });

  test('AuthController empty login and network failure', () async {
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
            httpClient: MockClient((_) async => throw Exception('network down')),
          );
        }),
      ],
    );
    addTearDown(container.dispose);
    final auth = container.read(authControllerProvider.notifier);
    expect((await auth.login(username: ' ', password: '')).isFailure, isTrue);
    expect((await auth.login(username: 'u', password: 'p')).isFailure, isTrue);
  });

  testWidgets('admin home and more daily sales', (tester) async {
    final admin = AuthSession(
      user: const AuthUser(id: 1, username: 'admin', firstName: 'Ada'),
      profile: const UserProfileSnapshot(
        role: 'super_admin',
        isSuperAdmin: true,
        isAdmin: true,
        isManager: false,
      ),
      permissions: PermissionSet([
        const PermissionGrant(module: 'sales', action: 'daily_sales'),
        const PermissionGrant(module: 'pos', action: 'view'),
        const PermissionGrant(module: 'customers', action: 'view'),
      ]),
      persona: AppPersona.admin,
    );
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (context, state, child) => StoreShellPage(child: child),
          routes: [
            GoRoute(path: AppRoutes.home, builder: (_, _) => const PersonaHomePage()),
            GoRoute(path: AppRoutes.pos, builder: (_, _) => const Text('pos-body')),
            GoRoute(path: AppRoutes.customers, builder: (_, _) => const Text('cust-body')),
            GoRoute(path: AppRoutes.more, builder: (_, _) => const MorePage()),
            GoRoute(path: AppRoutes.dailySales, builder: (_, _) => const Text('daily-body')),
            GoRoute(path: AppRoutes.health, builder: (_, _) => const Text('health-body')),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(admin),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Admin'), findsOneWidget);
    expect(find.byKey(const Key('home_daily_sales')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home_primary_cta')));
    await tester.pumpAndSettle();
    expect(find.text('pos-body'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_customers')));
    await tester.pumpAndSettle();
    expect(find.text('cust-body'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_daily_sales')));
    await tester.pumpAndSettle();
    expect(find.text('daily-body'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('more_daily_sales')));
    await tester.pumpAndSettle();
    expect(find.text('daily-body'), findsOneWidget);
    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('API health'));
    await tester.pumpAndSettle();
    expect(find.text('health-body'), findsOneWidget);
  });

  testWidgets('router redirects authenticated user from login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(cashierSession()),
        child: Consumer(
          builder: (context, ref, _) {
            final listenable = AuthRouterListenable(ref);
            final router = createAppRouter(
              readAuth: () => ref.read(authControllerProvider),
              refreshListenable: listenable,
              initialLocation: AppRoutes.login,
            );
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start New Sale'), findsOneWidget);
  });

  testWidgets('cashier navigates POS and Customers', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (context, state, child) => StoreShellPage(child: child),
          routes: [
            GoRoute(path: AppRoutes.home, builder: (_, _) => const PersonaHomePage()),
            GoRoute(path: AppRoutes.pos, builder: (_, _) => const Text('pos-body')),
            GoRoute(path: AppRoutes.customers, builder: (_, _) => const Text('cust-body')),
            GoRoute(path: AppRoutes.more, builder: (_, _) => const MorePage()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(cashierSession()),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_primary_cta')));
    await tester.pumpAndSettle();
    expect(find.text('pos-body'), findsOneWidget);
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_customers')));
    await tester.pumpAndSettle();
    expect(find.text('cust-body'), findsOneWidget);
  });

  testWidgets('signed out home and feature placeholder', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: PersonaHomePage())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Signed out'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: FeaturePlaceholderPage(title: 'POS', message: 'Coming in a later sprint.'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('POS'), findsOneWidget);
    expect(find.text('Coming in a later sprint.'), findsOneWidget);
  });

  test('routerProvider builds', () {
    final container = ProviderContainer(overrides: seedOverrides(cashierSession()));
    addTearDown(container.dispose);
    expect(container.read(routerProvider), isA<GoRouter>());
  });

  test('me 403 and login 403', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final client = ApiClient(
      env: const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
      tokenStore: tokens,
      httpClient: MockClient((_) async => http.Response('{}', 403)),
    );
    expect((await AuthApi(client: client, tokenStore: tokens).me()).isFailure, isTrue);
    expect(
      (await AuthApi(client: client, tokenStore: InMemoryTokenStore())
              .login(username: 'a', password: 'b'))
          .isFailure,
      isTrue,
    );
    client.close();
  });

  testWidgets('login onSubmitted', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          appEnvProvider.overrideWithValue(
            const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
          ),
          apiClientProvider.overrideWith((ref) {
            return ApiClient(
              env: ref.watch(appEnvProvider),
              tokenStore: ref.watch(tokenStoreProvider),
              httpClient: MockClient((_) async => http.Response('{"error":"no"}', 401)),
            );
          }),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.enterText(find.byKey(const Key('login_username')), 'u');
    await tester.enterText(find.byKey(const Key('login_password')), 'p');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('login_error')), findsOneWidget);
  });

  test('providers onSessionExpired marks auth', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'old', refresh: 'bad');
    final container = ProviderContainer(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
        ),
        httpClientProvider.overrideWithValue(
          MockClient((request) async {
            if (request.url.path.contains('/token/refresh/')) {
              return http.Response('{}', 401);
            }
            return http.Response('x', 401);
          }),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(apiClientProvider).get('accounts/auth/me/');
    expect(container.read(authControllerProvider).message, contains('Session expired'));
  });

  testWidgets('createAppRouter shell placeholders and health', (tester) async {
    late GoRouter router;
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(cashierSession()),
        child: Consumer(
          builder: (context, ref, _) {
            router = createAppRouter(
              readAuth: () => ref.read(authControllerProvider),
              initialLocation: AppRoutes.pos,
            );
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Start New Sale'), findsOneWidget);

    router.go(AppRoutes.customers);
    await tester.pumpAndSettle();
    expect(find.textContaining('Customer'), findsWidgets);

    router.go(AppRoutes.more);
    await tester.pumpAndSettle();
    expect(find.text('Sign out'), findsOneWidget);

    router.go(AppRoutes.dailySales);
    await tester.pumpAndSettle();
    // Cashier lacks sales.daily_sales — router redirects home.
    expect(router.state.uri.toString(), AppRoutes.home);
  });

  testWidgets('createAppRouter health route', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(cashierSession()),
        child: Consumer(
          builder: (context, ref, _) {
            final router = createAppRouter(
              readAuth: () => ref.read(authControllerProvider),
              initialLocation: AppRoutes.health,
            );
            return MaterialApp.router(routerConfig: router);
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.text('API health'), findsOneWidget);
  });

  testWidgets('routerProvider readAuth runs on redirect', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(cashierSession()),
        child: Consumer(
          builder: (context, ref, _) {
            return MaterialApp.router(routerConfig: ref.watch(routerProvider));
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Start New Sale'), findsOneWidget);
  });
}
