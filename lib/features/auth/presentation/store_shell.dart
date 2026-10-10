import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../../design_system/chrome/cb_bounded_sheet.dart';
import '../../../design_system/chrome/cb_commit_confirm.dart';
import '../../../design_system/chrome/cb_surface_card.dart';
import '../../../sync/presentation/sync_failures_sheet.dart';
import '../../../sync/presentation/sync_status_chip.dart';
import '../../../sync/providers.dart';
import '../../approvals/application/approvals_controller.dart';
import '../../daily_notes/presentation/sticky_notes_gate.dart';
import '../../appraisals/presentation/appraisal_greeting.dart';
import '../../delivery/application/delivery_controllers.dart';
import '../../delivery/domain/delivery_stop.dart';
import '../../expenses/application/expenses_controller.dart';
import '../../field_orders/domain/field_order.dart';
import '../../field_orders/domain/field_order_commit.dart';
import '../../home/presentation/store_home_dashboard.dart';
import '../application/auth_controller.dart';
import '../domain/permission_set.dart';
import '../domain/persona.dart';

/// Full-screen forms hide the shell chrome so the keyboard does not fight the rail.
bool shellHidesChrome(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  if (path == AppRoutes.customerNew) return true;
  return RegExp(r'^/customers/\d+/edit/?$').hasMatch(path);
}

/// Kept for older tests / call sites.
bool shellHidesBottomNav(String location) => shellHidesChrome(location);

class _NavItem {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.route,
    this.key,
  });
  final String label;
  final IconData icon;
  final String route;
  final Key? key;
}

/// Core day-to-day business tabs on the bottom bar (phone).
List<_NavItem> _bottomBusinessNav(
  PermissionSet? perms, {
  required bool canApprove,
}) {
  final showHistoryOnBar = !canApprove && (perms == null || perms.canViewSales);
  return [
    const _NavItem(
      label: 'Home',
      icon: Icons.home_outlined,
      route: AppRoutes.home,
    ),
    if (perms == null || perms.canAccessPos)
      const _NavItem(
        label: 'POS',
        icon: Icons.point_of_sale_outlined,
        route: AppRoutes.pos,
      ),
    if (canApprove)
      const _NavItem(
        label: 'Approvals',
        icon: Icons.fact_check_outlined,
        route: AppRoutes.approvals,
        key: Key('nav_approvals'),
      ),
    if (showHistoryOnBar)
      const _NavItem(
        label: 'History',
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.salesHistory,
      ),
    if (perms == null || perms.canViewCustomers)
      const _NavItem(
        label: 'Customers',
        icon: Icons.people_outline,
        route: AppRoutes.customers,
      ),
  ];
}

/// Extra business tools — shown in the More bottom sheet (not the side drawer).
List<_NavItem> _businessMoreNav({
  required PermissionSet? perms,
  required bool canHistory,
  bool includeSalesHistory = false,
}) {
  return [
    if (includeSalesHistory && (perms?.canViewSales ?? false))
      const _NavItem(
        label: 'Sales history',
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.salesHistory,
        key: Key('more_sales_history'),
      ),
    if (perms?.canPlaceVisitOrders ?? false)
      const _NavItem(
        label: 'New field sale',
        icon: Icons.shopping_bag_outlined,
        route: AppRoutes.siteVisit,
        key: Key('more_visit_order'),
      ),
    if (perms?.canDispatch ?? false)
      const _NavItem(
        label: 'Field sales',
        icon: Icons.inventory_2_outlined,
        route: AppRoutes.dispatchQueue,
        key: Key('more_dispatch'),
      ),
    if ((perms?.canAccessDelivery ?? false) || canHistory)
      _NavItem(
        label: canHistory ? 'Routes' : 'Today’s route',
        icon: Icons.map_outlined,
        route: AppRoutes.deliveryRoute,
        key: const Key('more_delivery'),
      ),
    if (perms?.canViewDailySales ?? false)
      const _NavItem(
        label: 'Daily sales',
        icon: Icons.calendar_today_outlined,
        route: AppRoutes.dailySales,
        key: Key('more_daily_sales'),
      ),
    if (perms?.canViewDebtManagement ?? false)
      const _NavItem(
        label: 'Debtors',
        icon: Icons.account_balance_wallet_outlined,
        route: AppRoutes.debtors,
        key: Key('more_debtors'),
      ),
    if (perms?.canViewDailyNotes ?? false)
      const _NavItem(
        label: 'Daily notes',
        icon: Icons.sticky_note_2_outlined,
        route: AppRoutes.dailyNotes,
        key: Key('more_daily_notes'),
      ),
    if (perms?.canViewAppraisals ?? false)
      const _NavItem(
        label: 'Target delivery',
        icon: Icons.star_outline,
        route: AppRoutes.appraisals,
        key: Key('more_appraisals'),
      ),
    if (perms?.canViewExpenses ?? false)
      const _NavItem(
        label: 'Expenses',
        icon: Icons.payments_outlined,
        route: AppRoutes.expenses,
        key: Key('more_expenses'),
      ),
  ];
}

/// Non-business overflow — side nav / drawer only.
List<_NavItem> _sideOverflowNav() {
  return const [
    _NavItem(
      label: 'API health',
      icon: Icons.monitor_heart_outlined,
      route: AppRoutes.health,
      key: Key('more_api_health'),
    ),
  ];
}

/// Wide rail / More page: business tools (+ sales history when not on the bar).
List<_NavItem> _moreNav({
  required PermissionSet? perms,
  required bool canHistory,
  required bool canApprove,
  bool includePrimaryDupes = false,
}) {
  final historyOnBar = !canApprove && (perms == null || perms.canViewSales);
  return _businessMoreNav(
    perms: perms,
    canHistory: canHistory,
    includeSalesHistory: includePrimaryDupes || !historyOnBar,
  );
}

Future<void> _openBusinessMoreSheet({
  required BuildContext context,
  required List<_NavItem> items,
  required String location,
  required int approvalsCount,
}) {
  return showCbBoundedSheet<void>(
    context: context,
    heightFactor: 0.72,
    builder: (ctx) {
      return Material(
        color: AppColors.background,
        child: ListView(
          key: const Key('shell_more_sheet'),
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                'Business tools',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No extra tools for your role.'),
              )
            else
              for (final item in items)
                ListTile(
                  key: item.key,
                  leading: _NavIcon(
                    icon: item.icon,
                    badge:
                        item.route == AppRoutes.approvals ? approvalsCount : 0,
                  ),
                  title: Text(item.label),
                  selected: location.startsWith(item.route),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    context.go(item.route);
                  },
                ),
          ],
        ),
      );
    },
  );
}

class StoreShellPage extends ConsumerStatefulWidget {
  const StoreShellPage({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<StoreShellPage> createState() => _StoreShellPageState();
}

class _StoreShellPageState extends ConsumerState<StoreShellPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadApprovals());
  }

  void _maybeLoadApprovals() {
    if (!mounted) return;
    final session = ref.read(authControllerProvider).session;
    final perms = session?.permissions;
    final canApprove =
        (perms?.canApproveSales ?? false) ||
        (perms?.canApproveDebtManagement ?? false) ||
        sessionCanApproveExpenses(session);
    if (canApprove) {
      ref.read(approvalsProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authControllerProvider).session;
    final perms = session?.permissions;
    final location = GoRouterState.of(context).uri.toString();
    final hideChrome = shellHidesChrome(location);
    final canApprove =
        (perms?.canApproveSales ?? false) ||
        (perms?.canApproveDebtManagement ?? false) ||
        sessionCanApproveExpenses(session);
    final canHistory = session != null &&
        sessionCanViewDeliveryHistory(
          permissions: session.permissions,
          profile: session.profile,
          isSuperuser: session.user.isSuperuser,
        );

    final bottom = _bottomBusinessNav(perms, canApprove: canApprove);
    final historyOnBar =
        !canApprove && (perms == null || perms.canViewSales);
    final businessMore = _businessMoreNav(
      perms: perms,
      canHistory: canHistory,
      includeSalesHistory: !historyOnBar,
    );
    final overflow = _sideOverflowNav();
    final sync = ref.watch(syncStatusProvider);
    final approvalsCount = canApprove
        ? ref.watch(approvalsProvider).totalCount
        : 0;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!hideChrome)
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
            child: widget.child,
          ),
        ),
      ],
    );

    int bottomIndex() {
      for (var i = 0; i < bottom.length; i++) {
        if (location.startsWith(bottom[i].route)) return i;
      }
      // More tab is selected when on a business-more or overflow route.
      return bottom.length;
    }

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            if (hideChrome) {
              return Scaffold(
                backgroundColor: AppColors.background,
                resizeToAvoidBottomInset: false,
                body: SafeArea(bottom: false, child: body),
              );
            }
            if (wide) {
              return Scaffold(
                backgroundColor: AppColors.background,
                resizeToAvoidBottomInset: false,
                body: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      _SideNavRail(
                        primary: bottom,
                        more: businessMore,
                        overflow: overflow,
                        location: location,
                        approvalsCount: approvalsCount,
                        onLogout: () =>
                            ref.read(authControllerProvider.notifier).logout(),
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  ),
                ),
              );
            }
            final selected = bottomIndex();
            return Scaffold(
              backgroundColor: AppColors.background,
              resizeToAvoidBottomInset: false,
              appBar: AppBar(
                backgroundColor: AppColors.background,
                elevation: 0,
                scrolledUnderElevation: 0,
                titleSpacing: 0,
                title: Text(
                  _titleFor(location, bottom, [...businessMore, ...overflow]),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              drawer: _SideDrawer(
                overflow: overflow,
                location: location,
                displayName: session?.user.displayName ?? '',
                onLogout: () =>
                    ref.read(authControllerProvider.notifier).logout(),
              ),
              body: SafeArea(bottom: false, child: body),
              bottomNavigationBar: NavigationBar(
                key: const Key('shell_bottom_nav'),
                selectedIndex: selected.clamp(0, bottom.length),
                onDestinationSelected: (index) async {
                  if (index >= bottom.length) {
                    await _openBusinessMoreSheet(
                      context: context,
                      items: businessMore,
                      location: location,
                      approvalsCount: approvalsCount,
                    );
                    return;
                  }
                  context.go(bottom[index].route);
                },
                destinations: [
                  for (final item in bottom)
                    NavigationDestination(
                      key: item.key,
                      icon: _NavIcon(
                        icon: item.icon,
                        badge: item.route == AppRoutes.approvals
                            ? approvalsCount
                            : 0,
                      ),
                      label: item.label,
                    ),
                  const NavigationDestination(
                    key: Key('nav_more'),
                    icon: Icon(Icons.more_horiz),
                    label: 'More',
                  ),
                ],
              ),
            );
          },
        ),
        const StickyNotesGate(),
        const AppraisalGreeting(),
      ],
    );
  }

  String _titleFor(
    String location,
    List<_NavItem> primary,
    List<_NavItem> more,
  ) {
    for (final item in [...primary, ...more]) {
      if (location.startsWith(item.route)) return item.label;
    }
    return 'CompleteByte';
  }
}

class _SideNavRail extends StatelessWidget {
  const _SideNavRail({
    required this.primary,
    required this.more,
    required this.overflow,
    required this.location,
    required this.approvalsCount,
    required this.onLogout,
  });

  final List<_NavItem> primary;
  final List<_NavItem> more;
  final List<_NavItem> overflow;
  final String location;
  final int approvalsCount;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      key: const Key('shell_side_rail'),
      width: 220,
      child: Material(
        color: AppColors.background,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Business', style: theme.textTheme.titleSmall),
            ),
            for (final item in primary)
              ListTile(
                key: item.key,
                dense: true,
                leading: _NavIcon(
                  icon: item.icon,
                  badge: item.route == AppRoutes.approvals ? approvalsCount : 0,
                ),
                title: Text(item.label),
                selected: location.startsWith(item.route),
                onTap: () => context.go(item.route),
              ),
            if (more.isNotEmpty) ...[
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'More tools',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
              for (final item in more)
                ListTile(
                  key: item.key,
                  dense: true,
                  leading: Icon(item.icon, color: AppColors.primary),
                  title: Text(item.label),
                  selected: location.startsWith(item.route),
                  onTap: () => context.go(item.route),
                ),
            ],
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                'Other',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedForeground,
                ),
              ),
            ),
            for (final item in overflow)
              ListTile(
                key: item.key,
                dense: true,
                leading: Icon(item.icon, color: AppColors.primary),
                title: Text(item.label),
                selected: location.startsWith(item.route),
                onTap: () => context.go(item.route),
              ),
            ListTile(
              key: const Key('more_logout'),
              dense: true,
              leading: const Icon(Icons.logout, color: AppColors.primary),
              title: const Text('Sign out'),
              onTap: onLogout,
            ),
          ],
        ),
      ),
    );
  }
}

class _SideDrawer extends StatelessWidget {
  const _SideDrawer({
    required this.overflow,
    required this.location,
    required this.displayName,
    required this.onLogout,
  });

  final List<_NavItem> overflow;
  final String location;
  final String displayName;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      key: const Key('shell_side_drawer'),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Other', style: Theme.of(context).textTheme.titleLarge),
                  if (displayName.isNotEmpty)
                    Text(
                      displayName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                ],
              ),
            ),
            for (final item in overflow)
              ListTile(
                key: item.key,
                leading: Icon(item.icon, color: AppColors.primary),
                title: Text(item.label),
                selected: location.startsWith(item.route),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.route);
                },
              ),
            ListTile(
              key: const Key('more_logout'),
              leading: const Icon(Icons.logout, color: AppColors.primary),
              title: const Text('Sign out'),
              onTap: () {
                Navigator.of(context).pop();
                onLogout();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, this.badge = 0});
  final IconData icon;
  final int badge;

  @override
  Widget build(BuildContext context) {
    if (badge <= 0) return Icon(icon);
    return Badge(
      label: Text('$badge'),
      child: Icon(icon),
    );
  }
}

class MorePage extends ConsumerWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    final perms = session?.permissions;
    final canHistory = session != null &&
        sessionCanViewDeliveryHistory(
          permissions: session.permissions,
          profile: session.profile,
          isSuperuser: session.user.isSuperuser,
        );
    final canApprove =
        (perms?.canApproveSales ?? false) ||
        (perms?.canApproveDebtManagement ?? false) ||
        sessionCanApproveExpenses(session);
    final items = _moreNav(
      perms: perms,
      canHistory: canHistory,
      canApprove: canApprove,
      includePrimaryDupes: true,
    );
    final overflow = _sideOverflowNav();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
        children: [
          Text('More', style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Business tools for your role.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          for (final item in items)
            ListTile(
              key: item.key,
              leading: Icon(item.icon, color: AppColors.primary),
              title: Text(item.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(item.route),
            ),
          const Divider(),
          for (final item in overflow)
            ListTile(
              key: item.key,
              leading: Icon(item.icon, color: AppColors.primary),
              title: Text(item.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(item.route),
            ),
          ListTile(
            key: const Key('more_logout'),
            leading: const Icon(Icons.logout, color: AppColors.primary),
            title: const Text('Sign out'),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}

// —— Home personas (unchanged behaviour) ——

class PersonaHomePage extends ConsumerWidget {
  const PersonaHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).session;
    if (session == null) {
      return const Center(child: Text('Signed out'));
    }

    final canHistory = sessionCanViewDeliveryHistory(
      permissions: session.permissions,
      profile: session.profile,
      isSuperuser: session.user.isSuperuser,
    );
    final canApprove = session.permissions.canApproveSales ||
        session.permissions.canApproveDebtManagement;

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
          canViewDeliveryHistory: canHistory,
          canApprove: canApprove,
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
          canViewDeliveryHistory: canHistory,
          canApprove: canApprove,
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

  Future<void> _confirmClaim(FieldOrderSummary order) async {
    final confirmed = await showCommitConfirm(
      context: context,
      title: 'Claim this order?',
      description: 'It will be added to your delivery route.',
      rows: deliveryClaimRows(order),
      confirmLabel: 'Confirm & claim',
      confirmKey: const Key('delivery_claim_confirm'),
      cancelKey: const Key('delivery_claim_cancel'),
    );
    if (!confirmed || !mounted) return;
    await ref.read(deliveryBoardProvider.notifier).claim(order.id);
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
              for (final stop in board.assigned) _AssignedStopTile(stop: stop),
            const SizedBox(height: 20),
            Text('Ready to pick up', style: theme.textTheme.titleSmall),
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
                  onClaim: () => _confirmClaim(order),
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
        : (stop.site.label.isNotEmpty ? stop.site.label : 'Stop #${stop.id}');
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
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
