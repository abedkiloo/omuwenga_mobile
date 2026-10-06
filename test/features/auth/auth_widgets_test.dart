import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/change_password_page.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/login_page.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/store_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'auth_fixtures.dart';

void main() {
  testWidgets('login validation empty fields', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          appEnvProvider.overrideWithValue(
            const AppEnv(
              flavor: AppFlavor.dev,
              apiBaseUrl: 'http://example.com/api',
            ),
          ),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.byKey(const Key('login_error')), findsOneWidget);
    expect(find.text('Enter your username and password.'), findsOneWidget);
  });

  testWidgets('login password toggle shows and hides the value', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          appEnvProvider.overrideWithValue(
            const AppEnv(
              flavor: AppFlavor.dev,
              apiBaseUrl: 'http://example.com/api',
            ),
          ),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.enterText(find.byKey(const Key('login_password')), 'secret12');
    expect(
      tester.widget<TextField>(find.byKey(const Key('login_password'))).obscureText,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('login_password_toggle')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('login_password'))).obscureText,
      isFalse,
    );
    await tester.tap(find.byKey(const Key('login_password_toggle')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('login_password'))).obscureText,
      isTrue,
    );
  });

  testWidgets('change password fields each have a visibility toggle', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStoreProvider.overrideWithValue(InMemoryTokenStore()),
          appEnvProvider.overrideWithValue(
            const AppEnv(
              flavor: AppFlavor.dev,
              apiBaseUrl: 'http://example.com/api',
            ),
          ),
        ],
        child: const MaterialApp(home: ChangePasswordPage()),
      ),
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('change_password_new'))).obscureText,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('change_password_new_toggle')));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byKey(const Key('change_password_new'))).obscureText,
      isFalse,
    );
    expect(
      tester.widget<TextField>(find.byKey(const Key('change_password_confirm'))).obscureText,
      isTrue,
    );
  });

  testWidgets('cashier home shows Start New Sale primary CTA', (tester) async {
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (_, _) => const PersonaHomePage(),
        ),
        GoRoute(path: AppRoutes.pos, builder: (_, _) => const Text('pos')),
        GoRoute(
          path: AppRoutes.customers,
          builder: (_, _) => const Text('customers'),
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
    expect(find.byKey(const Key('home_primary_cta')), findsOneWidget);
    expect(find.text('Start New Sale'), findsOneWidget);
  });

  testWidgets('manager home shows daily sales only when permitted', (
    tester,
  ) async {
    Future<void> pumpManager(AuthSession session) async {
      final router = GoRouter(
        initialLocation: AppRoutes.home,
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const PersonaHomePage(),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (_, _) => const Text('customers'),
          ),
          GoRoute(
            path: AppRoutes.dailySales,
            builder: (_, _) => const Text('daily'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: seedOverrides(session),
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpManager(managerSession(dailySales: false));
    expect(find.text('Open debtors'), findsNothing);
    expect(find.text('Start New Sale'), findsOneWidget);
    // sales.view alone opens Daily sales (own sales only).
    expect(find.byKey(const Key('home_daily_sales')), findsOneWidget);

    await pumpManager(managerSession(dailySales: true));
    expect(
      managerSession(dailySales: true).permissions.canViewDailySales,
      isTrue,
    );
    expect(find.text('Daily sales'), findsOneWidget);
    expect(find.byKey(const Key('home_daily_sales')), findsOneWidget);
  });

  testWidgets('More page shows own daily sales for cashier and logs out', (
    tester,
  ) async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(cashierSession(), tokens: tokens),
        child: const MaterialApp(home: MorePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more_daily_sales')), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(await tokens.readAccess(), isNull);
  });

  testWidgets('StoreShell hides POS without permission', (tester) async {
    final session = AuthSession(
      user: const AuthUser(id: 3, username: 'limited'),
      profile: const UserProfileSnapshot(
        role: 'custom',
        isSuperAdmin: false,
        isAdmin: false,
        isManager: false,
      ),
      permissions: PermissionSet(const []),
      persona: AppPersona.cashier,
    );
    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        ShellRoute(
          builder: (context, state, child) => StoreShellPage(child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (_, _) => const Text('home-body'),
            ),
            GoRoute(
              path: AppRoutes.more,
              builder: (_, _) => const Text('more-body'),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(session),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('POS'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
    expect(find.byKey(const Key('shell_side_rail')), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  test('shell hides tab bar on register and edit duka', () {
    expect(shellHidesBottomNav(AppRoutes.customerNew), isTrue);
    expect(
      shellHidesBottomNav('${AppRoutes.customerNew}?returnTo=pos'),
      isTrue,
    );
    expect(shellHidesBottomNav(AppRoutes.customerEdit(12)), isTrue);
    expect(shellHidesBottomNav(AppRoutes.customers), isFalse);
    expect(shellHidesBottomNav(AppRoutes.home), isFalse);
  });
}
