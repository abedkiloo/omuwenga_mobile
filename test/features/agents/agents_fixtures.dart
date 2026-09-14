import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/network/api_client.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/sync/application/connectivity_monitor.dart';
import 'package:completebyte_pos_mobile/sync/data/memory_outbox_store.dart';
import 'package:completebyte_pos_mobile/sync/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

AuthSession agentSession() {
  return AuthSession(
    user: const AuthUser(id: 9, username: 'agent', firstName: 'Ada', lastName: 'Field'),
    profile: const UserProfileSnapshot(
      role: 'agent',
      isSuperAdmin: false,
      isAdmin: false,
      isManager: false,
      roleDisplay: 'Field Agent',
    ),
    permissions: PermissionSet(const [
      PermissionGrant(module: 'agents', action: 'view'),
      PermissionGrant(module: 'agents', action: 'create'),
      PermissionGrant(module: 'agents', action: 'update'),
      PermissionGrant(module: 'customers', action: 'view'),
      PermissionGrant(module: 'customers', action: 'create'),
    ]),
    persona: AppPersona.fieldAgent,
  );
}

List<Override> agentOverrides(MockClient client, {MemoryOutboxStore? outbox}) {
  final tokens = InMemoryTokenStore();
  final store = outbox ?? MemoryOutboxStore();
  return [
    tokenStoreProvider.overrideWithValue(tokens),
    appEnvProvider.overrideWithValue(
      const AppEnv(flavor: AppFlavor.dev, apiBaseUrl: 'http://example.com/api'),
    ),
    authSessionSeedProvider.overrideWithValue(agentSession()),
    httpClientProvider.overrideWithValue(client),
    apiClientProvider.overrideWith((ref) {
      return ApiClient(
        env: ref.watch(appEnvProvider),
        tokenStore: tokens,
        httpClient: client,
      );
    }),
    outboxStoreProvider.overrideWithValue(store),
    connectivityMonitorProvider.overrideWithValue(
      FakeConnectivityMonitor(online: true),
    ),
  ];
}
