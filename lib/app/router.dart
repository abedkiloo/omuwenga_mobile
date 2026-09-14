import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/dispatch/presentation/dispatch_queue_page.dart';
import '../features/delivery/presentation/delivery_route_page.dart';
import '../features/field_orders/presentation/field_order_review_page.dart';
import '../features/agents/presentation/google_map_pin_picker.dart';
import '../features/agents/presentation/map_pin_picker.dart';
import '../features/agents/presentation/site_visit_wizard_page.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/store_shell.dart';
import '../features/customers/presentation/customer_detail_page.dart';
import '../features/customers/presentation/customer_form_page.dart';
import '../features/customers/presentation/customers_list_page.dart';
import '../features/customers/presentation/receive_payment_page.dart';
import '../features/daily_sales/presentation/customer_day_page.dart';
import '../features/daily_sales/presentation/daily_sales_page.dart';
import '../features/health/presentation/health_page.dart';
import '../features/pos/presentation/pos_page.dart';
import '../features/sales_history/presentation/sale_detail_page.dart';
import '../features/sales_history/presentation/sales_history_page.dart';
import '../design_system/branding/brand_logo.dart';
import 'routes.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(authControllerProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: BrandLogo(height: 220),
      ),
    );
  }
}

CustomTransitionPage<void> _fadePage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

typedef AuthStateReader = AuthState Function();

GoRouter createAppRouter({
  required AuthStateReader readAuth,
  Listenable? refreshListenable,
  String initialLocation = AppRoutes.splash,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final auth = readAuth();
      final loc = state.matchedLocation;
      final loggingIn = loc == AppRoutes.login;
      final splashing = loc == AppRoutes.splash;

      if (auth.status == AuthStatus.unknown) {
        return splashing ? null : AppRoutes.splash;
      }
      if (!auth.isAuthenticated) {
        return loggingIn ? null : AppRoutes.login;
      }
      if (loggingIn || splashing) {
        return AppRoutes.home;
      }
      if (loc.startsWith(AppRoutes.dailySales) &&
          !(auth.session?.permissions.canViewDailySales ?? false)) {
        return AppRoutes.home;
      }
      if (loc.startsWith(AppRoutes.siteVisit) &&
          !(auth.session?.permissions.canCreateAgentSites ?? false)) {
        return AppRoutes.home;
      }
      if (loc.startsWith('/agents/orders') &&
          !(auth.session?.permissions.canAccessAgents ?? false)) {
        return AppRoutes.home;
      }
      if (loc.startsWith(AppRoutes.dispatchQueue) &&
          !(auth.session?.permissions.canDispatch ?? false)) {
        return AppRoutes.home;
      }
      if (loc.startsWith(AppRoutes.deliveryRoute) &&
          !(auth.session?.permissions.canAccessDelivery ?? false)) {
        return AppRoutes.home;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const SplashPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fadePage(
          key: state.pageKey,
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.health,
        builder: (context, state) => const HealthPage(),
      ),
      ShellRoute(
        builder: (context, state, child) => StoreShellPage(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            builder: (context, state) => const PersonaHomePage(),
          ),
          GoRoute(
            path: AppRoutes.pos,
            builder: (context, state) => const PosPage(),
          ),
          GoRoute(
            path: AppRoutes.customers,
            builder: (context, state) => const CustomersListPage(),
          ),
          GoRoute(
            path: AppRoutes.customerNew,
            builder: (context, state) {
              final returnToPos =
                  state.uri.queryParameters['returnTo'] == 'pos';
              return CustomerFormPage(returnToPos: returnToPos);
            },
          ),
          GoRoute(
            path: '/customers/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return CustomerDetailPage(customerId: id);
            },
          ),
          GoRoute(
            path: '/customers/:id/edit',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return CustomerFormPage(customerId: id);
            },
          ),
          GoRoute(
            path: '/customers/:id/settle',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return ReceivePaymentPage(customerId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.more,
            builder: (context, state) => const MorePage(),
          ),
          GoRoute(
            path: AppRoutes.salesHistory,
            builder: (context, state) => const SalesHistoryPage(),
          ),
          GoRoute(
            path: '/sales/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return SaleDetailPage(saleId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.dailySales,
            builder: (context, state) => const DailySalesPage(),
          ),
          GoRoute(
            path: '/daily-sales/customer/:customerId',
            builder: (context, state) {
              final id =
                  int.tryParse(state.pathParameters['customerId'] ?? '') ?? 0;
              final date = state.uri.queryParameters['date'] ?? '';
              return CustomerDayPage(customerId: id, date: date);
            },
          ),
          GoRoute(
            path: AppRoutes.siteVisit,
            builder: (context, state) => SiteVisitWizardPage(
              mapPickerBuilder: const bool.fromEnvironment('FLUTTER_TEST')
                  ? fakeMapPinPickerBuilder
                  : googleMapPinPickerBuilder,
            ),
          ),
          GoRoute(
            path: AppRoutes.fieldOrderCart,
            builder: (context, state) {
              final siteId =
                  int.tryParse(state.uri.queryParameters['siteId'] ?? '') ?? 0;
              return FieldOrderCartPage(siteId: siteId);
            },
          ),
          GoRoute(
            path: AppRoutes.fieldOrderReview,
            builder: (context, state) => const FieldOrderReviewPage(),
          ),
          GoRoute(
            path: AppRoutes.dispatchQueue,
            builder: (context, state) => const DispatchQueuePage(),
          ),
          GoRoute(
            path: '/dispatch/orders/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return DispatchOrderDetailPage(orderId: id);
            },
          ),
          GoRoute(
            path: AppRoutes.deliveryRoute,
            builder: (context, state) => const DeliveryRoutePage(),
          ),
          GoRoute(
            path: '/delivery/stops/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return DeliveryStopPage(stopId: id);
            },
          ),
        ],
      ),
    ],
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = AuthRouterListenable(ref);
  ref.onDispose(listenable.dispose);
  final router = createAppRouter(
    readAuth: () => ref.read(authControllerProvider),
    refreshListenable: listenable,
  );
  ref.onDispose(router.dispose);
  return router;
});
