import 'dart:convert';

import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/customers/application/customers_controllers.dart';
import 'package:completebyte_pos_mobile/features/customers/domain/customer.dart';
import 'package:completebyte_pos_mobile/features/customers/presentation/customer_detail_page.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AuthSession _session({required bool canUpdate}) {
  return AuthSession(
    user: const AuthUser(id: 1, username: 'sales', firstName: 'Sam', lastName: 'Cash'),
    profile: const UserProfileSnapshot(
      role: 'cashier',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
    ),
    permissions: PermissionSet([
      const PermissionGrant(module: 'customers', action: 'view'),
      if (canUpdate) const PermissionGrant(module: 'customers', action: 'update'),
    ]),
    persona: AppPersona.cashier,
  );
}

List<Override> _overrides({
  required AuthSession session,
  required MockClient httpClient,
}) {
  final tokens = InMemoryTokenStore();
  return [
    tokenStoreProvider.overrideWithValue(tokens),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
    authSessionSeedProvider.overrideWithValue(session),
    httpClientProvider.overrideWithValue(httpClient),
    apiClientProvider.overrideWith((ref) {
      return ApiClient(
        env: ref.watch(appEnvProvider),
        tokenStore: tokens,
        httpClient: httpClient,
      );
    }),
    outboxStoreProvider.overrideWithValue(MemoryOutboxStore()),
    connectivityMonitorProvider.overrideWithValue(
      FakeConnectivityMonitor(online: true),
    ),
    customersSettingsProvider.overrideWith(
      (ref) async => const CustomersModuleSettings(),
    ),
  ];
}

Map<String, dynamic> _detailJson({required String wallet}) => {
      'customer': {
        'id': 7,
        'name': 'Debtor',
        'wallet_balance': wallet,
        'phone': '0700',
      },
      'standing_summary': {
        'standing': double.parse(wallet) < 0 ? 'debt' : 'good',
      },
      'orders': <dynamic>[],
    };

void main() {
  testWidgets('hides settle when no debt', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/detail/')) {
        return http.Response(jsonEncode(_detailJson(wallet: '0.00')), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          session: _session(canUpdate: true),
          httpClient: client,
        ),
        child: const MaterialApp(home: CustomerDetailPage(customerId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_settle')), findsNothing);
    expect(find.text('Good standing'), findsOneWidget);
  });

  testWidgets('hides settle when no customers.update permission', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/detail/')) {
        return http.Response(jsonEncode(_detailJson(wallet: '-80.00')), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          session: _session(canUpdate: false),
          httpClient: client,
        ),
        child: const MaterialApp(home: CustomerDetailPage(customerId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Owes'), findsOneWidget);
    expect(find.byKey(const Key('customer_settle')), findsNothing);
  });

  testWidgets('shows settle when debt and update permission', (tester) async {
    final client = MockClient((request) async {
      if (request.url.path.contains('/detail/')) {
        return http.Response(jsonEncode(_detailJson(wallet: '-80.00')), 200);
      }
      return http.Response('{}', 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(
          session: _session(canUpdate: true),
          httpClient: client,
        ),
        child: const MaterialApp(home: CustomerDetailPage(customerId: 7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer_settle')), findsOneWidget);
  });

  test('canSettleCustomerDebt gates', () {
    final authWith = AuthState(
      status: AuthStatus.authenticated,
      session: _session(canUpdate: true),
    );
    final authWithout = AuthState(
      status: AuthStatus.authenticated,
      session: _session(canUpdate: false),
    );
    const settings = CustomersModuleSettings();
    expect(
      canSettleCustomerDebt(auth: authWith, settings: settings, debtAmount: 10),
      isTrue,
    );
    expect(
      canSettleCustomerDebt(auth: authWithout, settings: settings, debtAmount: 10),
      isFalse,
    );
    expect(
      canSettleCustomerDebt(auth: authWith, settings: settings, debtAmount: 0),
      isFalse,
    );
    expect(
      canSettleCustomerDebt(
        auth: authWith,
        settings: const CustomersModuleSettings(enableWalletPayment: false),
        debtAmount: 10,
      ),
      isFalse,
    );
  });
}
