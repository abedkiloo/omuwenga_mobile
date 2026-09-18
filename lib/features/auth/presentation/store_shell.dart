import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../sync/presentation/sync_failures_sheet.dart';
import '../../../sync/presentation/sync_status_chip.dart';
import '../../../sync/providers.dart';
import '../../delivery/application/delivery_controllers.dart';
import '../../delivery/domain/delivery_stop.dart';
import '../../field_orders/domain/field_order.dart';
import '../../home/presentation/store_home_dashboard.dart';
import '../application/auth_controller.dart';
import '../domain/persona.dart';

class StoreShellPage extends ConsumerWidget {
  const StoreShellPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final perms = session?.permissions;
    final location = GoRouterState.of(context).uri.toString();

    final destinations = <_NavDest>[
      const _NavDest(
        label: 'Home',
        icon: Icons.home_outlined,
        route: AppRoutes.home,
      ),
      if (perms == null || perms.canAccessPos)
        const _NavDest(
          label: 'POS',
          icon: Icons.point_of_sale_outlined,
          route: AppRoutes.pos,
        ),
      if (perms == null || perms.canViewSales)
        const _NavDest(
          label: 'History',
          icon: Icons.receipt_long_outlined,
          route: AppRoutes.salesHistory,
        ),
      if (perms == null || perms.canViewCustomers)
        const _NavDest(
          label: 'Dukas',
          icon: Icons.people_outline,
          route: AppRoutes.customers,
        ),
      const _NavDest(
        label: 'More',
        icon: Icons.more_horiz,
        route: AppRoutes.more,
      ),
    ];

    final sync = ref.watch(syncStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SyncStatusChip(
                  status: sync,
                  onTap: sync.failedCount > 0
                      ? () async {
                          final items = await ref
                              .read(syncStatusProvider.notifier)
                              .failedItems();
                          if (!context.mounted) return;
                          await SyncFailuresSheet.show(
                            context,
                            items: items,
                            onRetry: (id) => ref
                                .read(syncStatusProvider.notifier)
                                .retryFailed(id),
                            onDiscard: (id) => ref
                                .read(syncStatusProvider.notifier)
                                .discardFailed(id),
                          );
                        }
                      : null,
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        height: 64,
        selectedIndex: _selectedVisualIndex(location, destinations),
        onDestinationSelected: (i) => context.go(destinations[i].route),
        destinations: [
          for (final d in destinations)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }

  int _selectedVisualIndex(String location, List<_NavDest> destinations) {
    for (var i = 0; i < destinations.length; i++) {
      if (location.startsWith(destinations[i].route)) return i;
    }
    return 0;
  }
}

class _NavDest {
  const _NavDest({
    required this.label,
    required this.icon,
    required this.route,
  });
  final String label;
  final IconData icon;
  final String route;
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CbSurfaceCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(title),
          trailing: const Icon(
            Icons.chevron_right,
            color: AppColors.mutedForeground,
          ),
        ),
      ),
    );
  }
}

class PersonaHomePage extends ConsumerWidget {
  const PersonaHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    if (session == null) {
      return const Center(child: Text('Signed out'));
    }

    switch (session.persona) {
      case AppPersona.cashier:
        return StoreHomeDashboard(
          title: 'Hi, ${session.user.displayName}',
          canAccessPos: session.permissions.canAccessPos,
          canViewCustomers: session.permissions.canViewCustomers,
          canViewDailySales: session.permissions.canViewDailySales,
          canViewSales: session.permissions.canViewSales,
          canViewDebtors: session.permissions.canViewDebtManagement,
          canPlaceVisitOrders: session.permissions.canPlaceVisitOrders,
          canDispatch: session.permissions.canDispatch,
          canAccessDelivery: session.permissions.canAccessDelivery,
        );
      case AppPersona.dispatcher:
        return _DispatcherHome(name: session.user.displayName);
      case AppPersona.deliveryDriver:
        return _DeliveryHome(name: session.user.displayName);
      case AppPersona.manager:
      case AppPersona.admin:
        return StoreHomeDashboard(
          title: session.persona == AppPersona.admin
              ? 'Admin · ${session.user.displayName}'
              : 'Manager · ${session.user.displayName}',
          canAccessPos: session.permissions.canAccessPos,
          canViewCustomers: session.permissions.canViewCustomers,
          canViewDailySales: session.permissions.canViewDailySales,
          canViewSales: session.permissions.canViewSales,
          canViewDebtors: session.permissions.canViewDebtManagement,
          canDispatch: session.permissions.canDispatch,
          canPlaceVisitOrders: session.permissions.canPlaceVisitOrders,
          canAccessDelivery: session.permissions.canAccessDelivery,
        );
    }
  }
}

class _DeliveryHome extends ConsumerStatefulWidget {
  const _DeliveryHome({required this.name});
  final String name;

  @override
  ConsumerState<_DeliveryHome> createState() => _DeliveryHomeState();
}

class _DeliveryHomeState extends ConsumerState<_DeliveryHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(deliveryBoardProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final board = ref.watch(deliveryBoardProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(deliveryBoardProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Delivery · ${widget.name}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Assigned stops first. Claim ready orders when you can take more.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            CbPrimaryButton(
              key: const Key('home_primary_cta'),
              label: 'Open today’s route',
              onPressed: () => context.go(AppRoutes.deliveryRoute),
            ),
            if (board.error != null) ...[
              const SizedBox(height: 12),
              Text(
                board.error!,
                key: const Key('delivery_home_error'),
                style: const TextStyle(color: AppColors.destructive),
              ),
            ],
            const SizedBox(height: 20),
            Text('Assigned to you', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (board.loading && board.assigned.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (board.assigned.isEmpty)
              Text(
                'No assigned stops yet.',
                key: const Key('delivery_home_assigned_empty'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              )
            else
              for (final stop in board.assigned)
                _AssignedStopTile(stop: stop),
            const SizedBox(height: 20),
            Text(
              'Ready to pick up',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Unassigned packed orders you can claim.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            if (!board.loading && board.available.isEmpty)
              Text(
                'Nothing ready to claim.',
                key: const Key('delivery_home_available_empty'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedForeground,
                ),
              )
            else
              for (final order in board.available)
                _ClaimableOrderTile(
                  order: order,
                  acting: board.acting,
                  onClaim: () => ref
                      .read(deliveryBoardProvider.notifier)
                      .claim(order.id),
                ),
          ],
        ),
      ),
    );
  }
}

class _AssignedStopTile extends StatelessWidget {
  const _AssignedStopTile({required this.stop});
  final DeliveryStop stop;

  @override
  Widget build(BuildContext context) {
    final title = stop.customerName?.isNotEmpty == true
        ? stop.customerName!
        : (stop.site.label.isNotEmpty
              ? stop.site.label
              : 'Stop #${stop.id}');
    final orderLabel = stop.fieldOrderId != null
        ? 'Order #${stop.fieldOrderId}'
        : 'Stop #${stop.id}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CbSurfaceCard(
        key: Key('delivery_home_assigned_${stop.id}'),
        padding: EdgeInsets.zero,
        onTap: () => context.push(AppRoutes.deliveryStop(stop.id)),
        child: ListTile(
          title: Text(title),
          subtitle: Text('$orderLabel · ${stop.status.name}'),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }
}

class _ClaimableOrderTile extends StatelessWidget {
  const _ClaimableOrderTile({
    required this.order,
    required this.acting,
    required this.onClaim,
  });

  final FieldOrderSummary order;
  final bool acting;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final title = order.customerName?.isNotEmpty == true
        ? order.customerName!
        : 'Order #${order.id}';
    final qty = order.lines.fold<double>(0, (s, l) => s + l.quantity);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CbSurfaceCard(
        key: Key('delivery_home_claimable_${order.id}'),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '#${order.id} · ${order.lines.length} lines · qty ${qty.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                key: Key('delivery_home_claim_${order.id}'),
                onPressed: acting ? null : onClaim,
                child: const Text('Claim for my route'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DispatcherHome extends StatelessWidget {
  const _DispatcherHome({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Dispatcher · $name', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Prepare what the driver will take.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            CbPrimaryButton(
              key: const Key('home_primary_cta'),
              label: 'Open dispatch queue',
              onPressed: () => context.go(AppRoutes.dispatchQueue),
            ),
          ],
        ),
      ),
    );
  }
}

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final canDaily = session?.permissions.canViewDailySales ?? false;
    final canSales = session?.permissions.canViewSales ?? false;
    final canPlaceVisit = session?.permissions.canPlaceVisitOrders ?? false;
    final canDispatch = session?.permissions.canDispatch ?? false;
    final canDelivery = session?.permissions.canAccessDelivery ?? false;
    final canDebtors = session?.permissions.canViewDebtManagement ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (canPlaceVisit)
              _MoreTile(
                key: const Key('more_visit_order'),
                title: 'New visit order',
                icon: Icons.shopping_bag_outlined,
                onTap: () => context.go(AppRoutes.siteVisit),
              ),
            if (canDispatch)
              _MoreTile(
                key: const Key('more_dispatch'),
                title: 'Field sales',
                icon: Icons.inventory_2_outlined,
                onTap: () => context.go(AppRoutes.dispatchQueue),
              ),
            if (canDelivery)
              _MoreTile(
                key: const Key('more_delivery'),
                title: 'Today’s route',
                icon: Icons.map_outlined,
                onTap: () => context.go(AppRoutes.deliveryRoute),
              ),
            if (canSales)
              _MoreTile(
                key: const Key('more_sales_history'),
                title: 'Sales history',
                icon: Icons.receipt_long_outlined,
                onTap: () => context.go(AppRoutes.salesHistory),
              ),
            if (canDaily)
              _MoreTile(
                key: const Key('more_daily_sales'),
                title: 'Daily sales',
                icon: Icons.calendar_today_outlined,
                onTap: () => context.go(AppRoutes.dailySales),
              ),
            if (canDebtors)
              _MoreTile(
                key: const Key('more_debtors'),
                title: 'Debtors',
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => context.go(AppRoutes.debtors),
              ),
            _MoreTile(
              title: 'API health',
              icon: Icons.monitor_heart_outlined,
              onTap: () => context.go(AppRoutes.health),
            ),
            _MoreTile(
              key: const Key('more_logout'),
              title: 'Sign out',
              icon: Icons.logout,
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ],
        ),
      ),
    );
  }
}

class FeaturePlaceholderPage extends StatelessWidget {
  const FeaturePlaceholderPage({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
