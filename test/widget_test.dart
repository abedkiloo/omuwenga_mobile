import 'package:completebyte_pos_mobile/app/app.dart';
import 'package:completebyte_pos_mobile/app/providers.dart';
import 'package:completebyte_pos_mobile/app/router.dart';
import 'package:completebyte_pos_mobile/app/routes.dart';
import 'package:completebyte_pos_mobile/core/env/app_env.dart';
import 'package:completebyte_pos_mobile/core/theme/app_colors.dart';
import 'package:completebyte_pos_mobile/core/secure/token_store.dart';
import 'package:completebyte_pos_mobile/design_system/states/async_states.dart';
import 'package:completebyte_pos_mobile/features/auth/application/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App loads MaterialApp with CompleteByte theme', (tester) async {
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
        child: Consumer(
          builder: (context, ref, _) {
            final listenable = AuthRouterListenable(ref);
            final router = createAppRouter(
              readAuth: () => ref.read(authControllerProvider),
              refreshListenable: listenable,
              initialLocation: AppRoutes.login,
            );
            return CompleteByteApp(router: router, fetchRuntimeFonts: false);
          },
        ),
      ),
    );
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(authControllerProvider.notifier).bootstrap();
    await tester.pumpAndSettle();

    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.theme?.colorScheme.primary, AppColors.primary);
    expect(find.byKey(const Key('brand_logo')), findsOneWidget);
    expect(find.text('Sign in to start your shift.'), findsOneWidget);
  });

  testWidgets('EmptyState primary CTA callback fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            title: 'Nothing here',
            message: 'Try again',
            primaryLabel: 'Refresh',
            onPrimary: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Refresh'));
    expect(tapped, isTrue);
  });

  testWidgets('ErrorState and LoadingState render', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              ErrorState(message: 'failed', onRetry: () {}),
              const LoadingState(),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Loading…'), findsOneWidget);
  });

  testWidgets('Splash bootstraps to login when no tokens', (tester) async {
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
        child: Consumer(
          builder: (context, ref, _) {
            final listenable = AuthRouterListenable(ref);
            final router = createAppRouter(
              readAuth: () => ref.read(authControllerProvider),
              refreshListenable: listenable,
            );
            return CompleteByteApp(router: router, fetchRuntimeFonts: false);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign in to start your shift.'), findsOneWidget);
  });
}
