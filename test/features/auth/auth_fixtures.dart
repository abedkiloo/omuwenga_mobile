import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/result/result.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/application/sync_engine.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Sales-capable user for visit-order / map tests.
AuthSession salesSession() {
  return AuthSession(
    user: const AuthUser(id: 9, username: 'sales', firstName: 'Ada', lastName: 'Field'),
    profile: const UserProfileSnapshot(
      role: 'cashier',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
      roleDisplay: 'Sales',
    ),
    permissions: PermissionSet(const [
      PermissionGrant(module: 'pos', action: 'view'),
      PermissionGrant(module: 'pos', action: 'create'),
      PermissionGrant(module: 'sales', action: 'view'),
      PermissionGrant(module: 'sales', action: 'create'),
      PermissionGrant(module: 'customers', action: 'view'),
      PermissionGrant(module: 'customers', action: 'create'),
    ]),
    persona: AppPersona.cashier,
  );
}

AuthSession cashierSession({bool dailySales = false}) {
  return AuthSession(
    user: const AuthUser(id: 1, username: 'sales', firstName: 'Sam', lastName: 'Cash'),
    profile: const UserProfileSnapshot(
      role: 'cashier',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
    ),
    permissions: PermissionSet([
      const PermissionGrant(module: 'pos', action: 'view'),
      const PermissionGrant(module: 'pos', action: 'create'),
      const PermissionGrant(module: 'customers', action: 'view'),
      const PermissionGrant(module: 'customers', action: 'create'),
      const PermissionGrant(module: 'customers', action: 'update'),
      const PermissionGrant(module: 'sales', action: 'view'),
      if (dailySales) const PermissionGrant(module: 'sales', action: 'daily_sales'),
    ]),
    persona: AppPersona.cashier,
  );
}

AuthSession managerSession({bool dailySales = false}) {
  return AuthSession(
    user: const AuthUser(id: 2, username: 'manager', firstName: 'Mo', lastName: 'Lead'),
    profile: const UserProfileSnapshot(
      role: 'manager',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: true,
    ),
    permissions: PermissionSet([
      const PermissionGrant(module: 'pos', action: 'view'),
      const PermissionGrant(module: 'customers', action: 'view'),
      const PermissionGrant(module: 'customers', action: 'create'),
      const PermissionGrant(module: 'customers', action: 'update'),
      const PermissionGrant(module: 'sales', action: 'view'),
      const PermissionGrant(module: 'sales', action: 'refund'),
      const PermissionGrant(module: 'dispatch', action: 'view'),
      const PermissionGrant(module: 'dispatch', action: 'update'),
      if (dailySales) const PermissionGrant(module: 'sales', action: 'daily_sales'),
    ]),
    persona: AppPersona.manager,
  );
}

List<Override> seedOverrides(AuthSession session, {InMemoryTokenStore? tokens}) {
  final store = tokens ?? InMemoryTokenStore();
  final outbox = MemoryOutboxStore();
  final connectivity = FakeConnectivityMonitor(online: true);
  return [
    tokenStoreProvider.overrideWithValue(store),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
    authSessionSeedProvider.overrideWithValue(session),
    httpClientProvider.overrideWithValue(
      MockClient((_) async => http.Response('{"status":"ok"}', 200)),
    ),
    apiClientProvider.overrideWith((ref) {
      return ApiClient(
        env: ref.watch(appEnvProvider),
        tokenStore: store,
        httpClient: ref.watch(httpClientProvider) ??
            MockClient((_) async => http.Response('{}', 200)),
      );
    }),
    outboxStoreProvider.overrideWithValue(outbox),
    connectivityMonitorProvider.overrideWithValue(connectivity),
    syncEngineProvider.overrideWithValue(
      SyncEngine(
        store: outbox,
        sender: (_) async => Success(http.Response('{}', 200)),
      ),
    ),
  ];
}
