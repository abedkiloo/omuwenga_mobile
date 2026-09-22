import 'dart:convert';

import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/daily_sales/data/daily_sales_api.dart';
import 'package:completebyte_pos_mobile/features/home/application/home_daily_controller.dart';
import 'package:completebyte_pos_mobile/features/sales_history/data/sales_history_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('homeShowsAllSales', () {
    test('admin and superuser see all; manager and cashier do not', () {
      final admin = AuthSession(
        user: const AuthUser(id: 1, username: 'a', isSuperuser: false),
        profile: const UserProfileSnapshot(
          role: 'admin',
          isSuperAdmin: false,
          isAdmin: true,
          isManager: false,
        ),
        permissions: PermissionSet(const []),
        persona: AppPersona.admin,
      );
      expect(homeShowsAllSales(admin), isTrue);

      final cashier = AuthSession(
        user: const AuthUser(id: 2, username: 'c'),
        profile: const UserProfileSnapshot(
          role: 'cashier',
          isSuperAdmin: false,
          isAdmin: false,
          isManager: false,
        ),
        permissions: PermissionSet(const []),
        persona: AppPersona.cashier,
      );
      expect(homeShowsAllSales(cashier), isFalse);

      final manager = AuthSession(
        user: const AuthUser(id: 3, username: 'm'),
        profile: const UserProfileSnapshot(
          role: 'manager',
          isSuperAdmin: false,
          isAdmin: false,
          isManager: true,
        ),
        permissions: PermissionSet(const []),
        persona: AppPersona.manager,
      );
      expect(homeShowsAllSales(manager), isFalse);

      final granted = AuthSession(
        user: const AuthUser(id: 4, username: 'g'),
        profile: const UserProfileSnapshot(
          role: 'manager',
          isSuperAdmin: false,
          isAdmin: false,
          isManager: true,
        ),
        permissions: PermissionSet([
          const PermissionGrant(module: 'sales', action: 'view_all'),
        ]),
        persona: AppPersona.manager,
      );
      expect(homeShowsAllSales(granted), isTrue);
    });
  });

  test('HomeDailyController loads scoped daily report for cashier', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['cashier_id'], '2');
        return http.Response(
          jsonEncode({
            'date': '2026-09-14',
            'summary': {
              'total_sales': '100.00',
              'orders_count': 1,
              'total_paid': '100.00',
              'paid_orders_count': 1,
              'total_debt_incurred': '0',
              'debt_orders_count': 0,
              'partial_orders_count': 0,
              'total_debt_collected': '0',
              'total_collected': '100.00',
            },
            'orders': [
              {
                'id': 9,
                'sale_number': 'S-9',
                'total': '100.00',
                'amount_paid': '100.00',
                'payment_status': 'paid',
                'cashier_name': 'c',
              },
            ],
          }),
          200,
        );
      }),
    );
    final session = AuthSession(
      user: const AuthUser(id: 2, username: 'c'),
      profile: const UserProfileSnapshot(
        role: 'cashier',
        isSuperAdmin: false,
        isAdmin: false,
        isManager: false,
      ),
      permissions: PermissionSet(const [
        PermissionGrant(module: 'sales', action: 'daily_sales'),
      ]),
      persona: AppPersona.cashier,
    );
    final controller = HomeDailyController(
      dailyApi: DailySalesApi(client),
      salesApi: SalesHistoryApi(client),
      session: session,
    );
    await controller.load();
    expect(controller.state.summary?.scopeAll, isFalse);
    expect(controller.state.summary?.summary.ordersCount, 1);
    expect(controller.state.summary?.orders.single.saleNumber, 'S-9');
    client.close();
  });

  test('admin load omits cashier_id', () async {
    final tokens = InMemoryTokenStore();
    await tokens.writeTokens(access: 'a', refresh: 'r');
    String? cashierParam;
    final client = ApiClient(
      env: const AppEnv(
        flavor: AppFlavor.dev,
        apiBaseUrl: 'http://example.com/api',
      ),
      tokenStore: tokens,
      httpClient: MockClient((request) async {
        cashierParam = request.url.queryParameters['cashier_id'];
        return http.Response(
          jsonEncode({
            'date': '2026-09-14',
            'summary': {
              'total_sales': '0',
              'orders_count': 0,
              'total_paid': '0',
              'paid_orders_count': 0,
              'total_debt_incurred': '0',
              'debt_orders_count': 0,
              'partial_orders_count': 0,
              'total_debt_collected': '0',
              'total_collected': '0',
            },
            'orders': [],
          }),
          200,
        );
      }),
    );
    final session = AuthSession(
      user: const AuthUser(id: 1, username: 'admin'),
      profile: const UserProfileSnapshot(
        role: 'admin',
        isSuperAdmin: true,
        isAdmin: true,
        isManager: false,
      ),
      permissions: PermissionSet(const [
        PermissionGrant(module: 'sales', action: 'daily_sales'),
      ]),
      persona: AppPersona.admin,
    );
    final controller = HomeDailyController(
      dailyApi: DailySalesApi(client),
      salesApi: SalesHistoryApi(client),
      session: session,
    );
    await controller.load();
    expect(cashierParam, isNull);
    expect(controller.state.summary?.scopeAll, isTrue);
    client.close();
  });
}
