import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/store_shell.dart';
import 'package:completebyte_pos_mobile/features/expenses/domain/expense.dart';
import 'package:completebyte_pos_mobile/features/expenses/presentation/expenses_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/auth_fixtures.dart';

AuthSession _expenseUser({bool admin = false}) {
  return AuthSession(
    user: AuthUser(
      id: 3,
      username: admin ? 'admin' : 'mgr',
      firstName: 'Mo',
      isSuperuser: admin,
    ),
    profile: UserProfileSnapshot(
      role: admin ? 'admin' : 'manager',
      isSuperAdmin: admin,
      isAdmin: admin,
      isManager: !admin,
    ),
    permissions: PermissionSet(const [
      PermissionGrant(module: 'expenses', action: 'view'),
      PermissionGrant(module: 'expenses', action: 'create'),
      PermissionGrant(module: 'expenses', action: 'update'),
      PermissionGrant(module: 'expenses', action: 'delete'),
      PermissionGrant(module: 'customers', action: 'view'),
    ]),
    persona: admin ? AppPersona.admin : AppPersona.manager,
  );
}

List<Override> _overrides(AuthSession session) {
  final tokens = InMemoryTokenStore();
  return [
    ...seedOverrides(session, tokens: tokens),
    apiClientProvider.overrideWith((ref) {
      return ApiClient(
        env: const AppEnv(
          flavor: AppFlavor.dev,
          apiBaseUrl: 'http://example.com/api',
        ),
        tokenStore: tokens,
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path.contains('store-settings')) {
            return http.Response(
              jsonEncode({'maker_checker_enabled': false}),
              200,
            );
          }
          if (path.contains('expenses/categories')) {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': 1,
                    'name': 'Rent',
                    'description': '',
                    'is_active': true,
                    'expense_count': 0,
                  },
                ],
              }),
              200,
            );
          }
          if (path.contains('expenses') && request.method == 'GET') {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': 11,
                    'expense_number': 'EXP-1',
                    'amount': '2500.00',
                    'description': 'Shop rent',
                    'status': 'pending',
                    'category': 1,
                    'category_name': 'Rent',
                    'payment_method': 'mpesa',
                    'vendor': 'Landlord',
                    'receipt_number': '',
                    'expense_date': '2026-10-10',
                    'notes': '',
                    'created_by': 3,
                    'created_by_name': 'mgr',
                  },
                ],
              }),
              200,
            );
          }
          if (path.contains('expenses') && request.method == 'POST') {
            return http.Response(
              jsonEncode({
                'id': 12,
                'expense_number': 'EXP-2',
                'amount': '100.00',
                'description': 'Airtime',
                'status': 'pending',
                'category': 1,
                'category_name': 'Rent',
                'payment_method': 'cash',
                'vendor': '',
                'receipt_number': '',
                'expense_date': '2026-10-10',
                'notes': '',
              }),
              201,
            );
          }
          return http.Response('{}', 404);
        }),
      );
    }),
  ];
}

void main() {
  test('expense parses list payload', () {
    final expense = Expense.fromJson({
      'id': 11,
      'expense_number': 'EXP-1',
      'amount': '2500.00',
      'description': 'Shop rent',
      'status': 'pending',
      'category': 1,
      'category_name': 'Rent',
      'payment_method': 'mpesa',
      'expense_date': '2026-10-10',
    });
    expect(expense.amount, 2500);
    expect(expense.isPending, isTrue);
    expect(expense.paymentLabel, 'M-PESA');
  });

  testWidgets('more menu shows Expenses when permitted', (tester) async {
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
              path: AppRoutes.expenses,
              builder: (_, _) => const ExpensesListPage(),
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
        overrides: _overrides(_expenseUser()),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more_expenses')), findsOneWidget);
    await tester.tap(find.byKey(const Key('more_expenses')));
    await tester.pumpAndSettle();
    expect(find.text('Shop rent'), findsOneWidget);
    expect(find.byKey(const Key('expenses_add')), findsOneWidget);
  });
}
