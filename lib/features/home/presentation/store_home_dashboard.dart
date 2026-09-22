import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/client_channel_icon.dart';
import '../../../design_system/design_system.dart';
import '../../daily_sales/domain/daily_report.dart';
import '../../sales_history/domain/payment_status.dart';
import '../application/home_daily_controller.dart';

/// Shared store home: daily summary + Start New Sale / web-like Quick actions.
class StoreHomeDashboard extends ConsumerWidget {
  const StoreHomeDashboard({
    super.key,
    required this.title,
    required this.canAccessPos,
    required this.canViewCustomers,
    this.canViewDailySales = false,
    this.canViewSales = false,
    this.canViewDebtors = false,
    this.canDispatch = false,
    this.canPlaceVisitOrders = false,
    this.canAccessDelivery = false,
  });

  final String title;
  final bool canAccessPos;
  final bool canViewCustomers;
  final bool canViewDailySales;
  final bool canViewSales;
  final bool canViewDebtors;
  final bool canDispatch;
  final bool canPlaceVisitOrders;
  final bool canAccessDelivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDailyProvider);
    final theme = Theme.of(context);
    final tools = _buildTools(context);

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: () => ref.read(homeDailyProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        home.summary?.scopeAll == true
                            ? 'Today’s sales — all cashiers'
                            : 'Today’s sales — yours only',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const CbStatusPill(
                  label: 'Online · Synced',
                  variant: CbStatusPillVariant.online,
                  showOnlineDot: true,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SummarySection(state: home),
            const SizedBox(height: 12),
            if (canAccessPos)
              CbPrimaryButton(
                key: const Key('home_primary_cta'),
                label: 'Start New Sale',
                onPressed: () => context.go(AppRoutes.pos),
              )
            else if (canViewCustomers)
              CbPrimaryButton(
                key: const Key('home_primary_cta'),
                label: 'Customers',
                onPressed: () => context.go(AppRoutes.customers),
              ),
            if (tools.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'QUICK ACTIONS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedForeground,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              _QuickActionsGrid(actions: tools),
            ],
            if (home.summary != null && home.summary!.orders.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: CbSectionLabel(
                      label: 'Recent Completed Receipts',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                  const CbStatusPill(
                    label: 'Live',
                    variant: CbStatusPillVariant.online,
                    showOnlineDot: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final order in home.summary!.orders)
                _OrderTile(order: order),
            ],
          ],
        ),
      ),
    );
  }

  List<_HomeTool> _buildTools(BuildContext context) {
    final tools = <_HomeTool>[];

    // Mirror web Quick actions — only tools that exist on mobile.
    if (canAccessPos) {
      tools.add(
        _HomeTool(
          key: const Key('home_tool_pos'),
          icon: Icons.point_of_sale_outlined,
          label: 'Retail POS',
          description: 'Fast checkout',
          onTap: () => context.go(AppRoutes.pos),
        ),
      );
    }
    if (canViewCustomers) {
      tools.add(
        _HomeTool(
          key: const Key('home_customers'),
          icon: Icons.people_outline,
          label: 'Customers',
          description: 'Accounts & credit',
          onTap: () => context.go(AppRoutes.customers),
        ),
      );
    }
    if (canViewDebtors) {
      tools.add(
        _HomeTool(
          key: const Key('home_debtors'),
          icon: Icons.account_balance_wallet_outlined,
          label: 'Debtors',
          description: 'Collect outstanding',
          onTap: () => context.go(AppRoutes.debtors),
        ),
      );
    }
    if (canViewSales) {
      tools.add(
        _HomeTool(
          key: const Key('home_sales_history'),
          icon: Icons.receipt_long_outlined,
          label: 'Sales history',
          description: 'Receipts & audit',
          onTap: () => context.go(AppRoutes.salesHistory),
        ),
      );
    }
    if (canViewDailySales) {
      tools.add(
        _HomeTool(
          key: const Key('home_daily_sales'),
          icon: Icons.calendar_today_outlined,
          label: 'Daily sales',
          description: 'Today’s report',
          onTap: () => context.go(AppRoutes.dailySales),
        ),
      );
    }
    if (canPlaceVisitOrders) {
      tools.add(
        _HomeTool(
          key: const Key('home_visit_order'),
          icon: Icons.location_on_outlined,
          label: 'Visit order',
          description: 'Order on site',
          onTap: () => context.go(AppRoutes.siteVisit),
        ),
      );
    }
    if (canDispatch) {
      tools.add(
        _HomeTool(
          key: const Key('home_dispatch'),
          icon: Icons.inventory_2_outlined,
          label: 'Field sales',
          description: 'Pack & assign',
          onTap: () => context.go(AppRoutes.dispatchQueue),
        ),
      );
    }
    if (canAccessDelivery) {
      tools.add(
        _HomeTool(
          key: const Key('home_delivery'),
          icon: Icons.map_outlined,
          label: 'Today’s route',
          description: 'Deliver & collect',
          onTap: () => context.go(AppRoutes.deliveryRoute),
        ),
      );
    }

    return tools;
  }
}

class _HomeTool {
  const _HomeTool({
    required this.key,
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final Key key;
  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({required this.actions});

  final List<_HomeTool> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoCol = constraints.maxWidth >= 420;
        if (!twoCol) {
          return Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _QuickActionTile(action: actions[i]),
              ],
            ],
          );
        }

        final rows = <Widget>[];
        for (var i = 0; i < actions.length; i += 2) {
          if (i > 0) rows.add(const SizedBox(height: 8));
          final left = actions[i];
          final right = i + 1 < actions.length ? actions[i + 1] : null;
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _QuickActionTile(action: left)),
                const SizedBox(width: 8),
                Expanded(
                  child: right == null
                      ? const SizedBox.shrink()
                      : _QuickActionTile(action: right),
                ),
              ],
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _HomeTool action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CbSurfaceCard(
      key: action.key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: action.onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(action.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  action.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.mutedForeground,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.state});

  final HomeDailyState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (state.loading && state.summary == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.error != null && state.summary == null) {
      return Text(
        key: const Key('home_summary_error'),
        state.error!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.destructive,
        ),
      );
    }
    final summary = state.summary?.summary;
    if (summary == null) {
      return Text(
        'No sales yet today.',
        key: const Key('home_summary_empty'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: AppColors.mutedForeground,
        ),
      );
    }

    return Column(
      key: const Key('home_daily_summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricCard(
          label: 'Gross Collections',
          value: summary.totalSales,
          subtitle: '${summary.ordersCount} orders today',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Paid / Collected',
                value: summary.totalPaid > 0
                    ? summary.totalPaid
                    : summary.totalCollected,
                subtitle: '${summary.paidOrdersCount} paid',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricCard(
                label: 'Credit Slips',
                value: summary.totalDebtIncurred,
                subtitle: summary.debtOrdersCount > 0
                    ? '${summary.debtOrdersCount} pending'
                    : 'None today',
                trailing: summary.debtOrdersCount > 0
                    ? CbStatusPill(
                        label: '${summary.debtOrdersCount} Pending',
                        variant: CbStatusPillVariant.warning,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.subtitle,
    this.trailing,
  });

  final String label;
  final double value;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CbSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'KES ${value.toStringAsFixed(2)}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

CbStatusPillVariant _paymentMethodPillVariant(String? method) {
  final m = (method ?? '').toLowerCase();
  if (m.contains('mpesa') || m.contains('m-pesa')) {
    return CbStatusPillVariant.success;
  }
  if (m.contains('cash')) {
    return CbStatusPillVariant.info;
  }
  return CbStatusPillVariant.neutral;
}

String _paymentMethodLabel(String? method) {
  if (method == null || method.isEmpty) return 'Sale';
  return method;
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final DailyOrder order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saleLabel = order.saleNumber.isEmpty
        ? '#${order.id}'
        : order.saleNumber;

    return CbSurfaceCard(
      margin: const EdgeInsets.only(bottom: 8),
      onTap: () => context.push(AppRoutes.saleDetail(order.id)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SaleNumberLabel(
                  key: Key('home_order_${order.id}'),
                  saleNumber: saleLabel,
                  channel: order.clientChannel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (order.customerName != null &&
                    order.customerName!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    order.customerName!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    CbStatusPill(
                      label: _paymentMethodLabel(order.paymentMethod),
                      variant: _paymentMethodPillVariant(order.paymentMethod),
                    ),
                    CbStatusPill(
                      label: paymentStatusLabel(order.paymentStatus),
                      variant: CbStatusPillVariant.neutral,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'KES ${order.total.toStringAsFixed(2)}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
