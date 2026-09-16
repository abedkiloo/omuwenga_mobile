import 'package:completebyte_pos_mobile/app/router.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/auth_session.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/permission_set.dart';
import 'package:completebyte_pos_mobile/features/auth/domain/persona.dart';
import 'package:completebyte_pos_mobile/features/auth/presentation/store_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fixtures.dart';

void main() {
  testWidgets('sales home shows visit order; delivery more hides it', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(salesSession()),
        child: const MaterialApp(home: PersonaHomePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_primary_cta')), findsOneWidget);
    expect(find.text('Start New Sale'), findsOneWidget);
    expect(find.byKey(const Key('home_visit_order')), findsOneWidget);
    expect(find.text('Visit order'), findsOneWidget);

    final deliveryOnly = AuthSession(
      user: const AuthUser(
        id: 3,
        username: 'driver',
        firstName: 'D',
        lastName: 'R',
      ),
      profile: const UserProfileSnapshot(
        role: 'delivery',
        isSuperAdmin: false,
        isAdmin: false,
        isManager: false,
      ),
      permissions: PermissionSet(const [
        PermissionGrant(module: 'delivery', action: 'view'),
      ]),
      persona: AppPersona.deliveryDriver,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: seedOverrides(deliveryOnly),
        child: const MaterialApp(home: MorePage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('more_visit_order')), findsNothing);
  });

  testWidgets('router redirects visit order without sales/pos', (tester) async {
    final deliveryOnly = AuthSession(
      user: const AuthUser(
        id: 3,
        username: 'driver',
        firstName: 'D',
        lastName: 'R',
      ),
      profile: const UserProfileSnapshot(
        role: 'delivery',
        isSuperAdmin: false,
        isAdmin: false,
        isManager: false,
      ),
      permissions: PermissionSet(const [
        PermissionGrant(module: 'delivery', action: 'view'),
      ]),
      persona: AppPersona.deliveryDriver,
    );
    final container = ProviderContainer(overrides: seedOverrides(deliveryOnly));
    addTearDown(container.dispose);
    final router = createAppRouter(
      readAuth: () => container.read(authControllerProvider),
      initialLocation: AppRoutes.siteVisit,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), AppRoutes.home);
  });
}
