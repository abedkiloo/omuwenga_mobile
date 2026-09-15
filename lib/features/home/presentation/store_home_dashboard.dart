import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../daily_sales/domain/daily_report.dart';
import '../../sales_history/domain/payment_status.dart';
import '../application/home_daily_controller.dart';

/// Shared store home: daily summary + Start New Sale / Customers.
class StoreHomeDashboard extends ConsumerWidget {
  const StoreHomeDashboard({
    super.key,
    required this.title,
    required this.canAccessPos,
    required this.canViewCustomers,
    this.canViewDailySales = false,
    this.canDispatch = false,
    this.canPlaceVisitOrders = false,
  });

  final String title;
  final bool canAccessPos;
  final bool canViewCustomers;
  final bool canViewDailySales;
  final bool canDispatch;
  final bool canPlaceVisitOrders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeDailyProvider);
    final theme = Theme.of(context);

    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(homeDailyProvider.notifier).load(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
                              : 'Today’s sales — yours',
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
              const SizedBox(height: 20),
              _SummarySection(state: home),
              const SizedBox(height: 20),
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
              if (_hasQuickActions) ...[
                const SizedBox(height: 16),
                _QuickActionsRow(
                  canViewCustomers: canViewCustomers && canAccessPos,
                  canPlaceVisitOrders: canPlaceVisitOrders,
                  canDispatch: canDispatch,
                ),
              ],
              if (canViewDailySales) ...[
                const SizedBox(height: 12),
                TextButton(
                  key: const Key('home_daily_sales'),
                  onPressed: () => context.go(AppRoutes.dailySales),
                  child: const Text('Full daily sales'),
                ),
              ],
              if (home.summary != null && home.summary!.orders.isNotEmpty) ...[
                const SizedBox(height: 24),
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
      ),
    );
  }

  bool get _hasQuickActions =>
      (canViewCustomers && canAccessPos) ||
      canPlaceVisitOrders ||
      canDispatch;
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({
    required this.canViewCustomers,
    required this.canPlaceVisitOrders,
    required this.canDispatch,
  });

  final bool canViewCustomers;
  final bool canPlaceVisitOrders;
  final bool canDispatch;

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[];
    if (canViewCustomers) {
      actions.add(
        _QuickAction(
          key: const Key('home_customers'),
          icon: Icons.people_outline,
          label: 'Customers',
          onTap: () => context.go(AppRoutes.customers),
        ),
      );
    }
    if (canPlaceVisitOrders) {
      actions.add(
        _QuickAction(
          key: const Key('home_visit_order'),
          icon: Icons.location_on_outlined,
          label: 'Visit order',
          onTap: () => context.go(AppRoutes.siteVisit),
        ),
      );
    }
    if (canDispatch) {
      actions.add(
        _QuickAction(
          key: const Key('home_dispatch'),
          icon: Icons.local_shipping_outlined,
          label: 'Field sales',
          onTap: () => context.go(AppRoutes.dispatchQueue),
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: actions[i]),
        ],
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CbSurfaceCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: AppColors.accentSoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
        style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.destructive),
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
              if (trailing != null) trailing!,
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
    final saleLabel =
        order.saleNumber.isEmpty ? '#${order.id}' : order.saleNumber;

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
                Text(
                  saleLabel,
                  key: Key('home_order_${order.id}'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (order.customerName != null && order.customerName!.isNotEmpty) ...[
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
