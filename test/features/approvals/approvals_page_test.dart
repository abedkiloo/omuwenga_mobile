import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/approvals/presentation/approvals_page.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/store_shell.dart';
import 'package:completebyte_pos_mobile/features/home/presentation/store_home_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/auth_fixtures.dart';

AuthSession _approver() {
  return AuthSession(
    user: const AuthUser(id: 2, username: 'mgr', firstName: 'Mo'),
    profile: const UserProfileSnapshot(
      role: 'manager',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: true,
    ),
    permissions: PermissionSet(const [
      PermissionGrant(module: 'sales', action: 'view'),
      PermissionGrant(module: 'sales', action: 'approve'),
      PermissionGrant(module: 'debt_management', action: 'view'),
      PermissionGrant(module: 'debt_management', action: 'approve'),
      PermissionGrant(module: 'customers', action: 'view'),
    ]),
    persona: AppPersona.manager,
  );
}

List<Override> _approverOverrides() {
  final tokens = InMemoryTokenStore();
  return [
    ...seedOverrides(_approver(), tokens: tokens),
    apiClientProvider.overrideWith((ref) {
      return ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          if (request.url.path.contains('sales')) {
            return http.Response(jsonEncode({'results': []}), 200);
          }
          if (request.url.path.contains('pending-changes')) {
            return http.Response(jsonEncode([]), 200);
          }
          return http.Response('{}', 404);
        }),
      );
    }),
  ];
}

void main() {
  testWidgets('shell menu shows Approvals for managers', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
              path: AppRoutes.approvals,
              builder: (_, _) => const ApprovalsPage(),
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: _approverOverrides(),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav_approvals')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav_approvals')));
    await tester.pumpAndSettle();
    expect(find.text('No sales waiting.'), findsOneWidget);
    expect(find.text('No collections waiting.'), findsOneWidget);
  });

  testWidgets('home shows Approvals quick action when permitted', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const StoreHomeDashboard(
            title: 'Manager',
            canAccessPos: false,
            canViewCustomers: true,
            canApprove: true,
          ),
        ),
        GoRoute(
          path: AppRoutes.approvals,
          builder: (_, _) => const Text('approvals-body'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(_approver()),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_approvals')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home_approvals')));
    await tester.pumpAndSettle();
    expect(find.text('approvals-body'), findsOneWidget);
  });
}
