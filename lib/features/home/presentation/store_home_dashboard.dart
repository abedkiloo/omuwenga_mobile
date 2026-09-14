import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../../daily_sales/domain/daily_report.dart';
import '../../sales_history/domain/payment_status.dart';
import '../application/home_daily_controller.dart';

/// Shared store home: daily summary + New sale / Customers.
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

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => ref.read(homeDailyProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
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
            const SizedBox(height: 20),
            if (canAccessPos)
              CbPrimaryButton(
                key: const Key('home_primary_cta'),
                label: 'New sale',
                onPressed: () => context.go(AppRoutes.pos),
              )
            else if (canViewCustomers)
              CbPrimaryButton(
                key: const Key('home_primary_cta'),
                label: 'Customers',
                onPressed: () => context.go(AppRoutes.customers),
              ),
            if (canAccessPos && canViewCustomers) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('home_customers'),
                onPressed: () => context.go(AppRoutes.customers),
                child: const Text('Customers'),
              ),
            ],
            if (canPlaceVisitOrders) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('home_visit_order'),
                onPressed: () => context.go(AppRoutes.siteVisit),
                child: const Text('New visit order'),
              ),
            ],
            if (canDispatch) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                key: const Key('home_dispatch'),
                onPressed: () => context.go(AppRoutes.dispatchQueue),
                child: const Text('Field sales'),
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
            const SizedBox(height: 24),
            _SummarySection(state: home),
            if (home.summary != null && home.summary!.orders.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Recent today', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (final order in home.summary!.orders)
                _OrderTile(order: order),
            ],
          ],
        ),
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
    return Container(
      key: const Key('home_daily_summary'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sales ${summary.totalSales.toStringAsFixed(2)} · ${summary.ordersCount} orders',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Paid ${summary.totalPaid.toStringAsFixed(2)} · '
            'Debt ${summary.totalDebtIncurred.toStringAsFixed(2)} · '
            'Collected ${summary.totalCollected.toStringAsFixed(2)}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderTile extends StatelessWidget {
  const _OrderTile({required this.order});

  final DailyOrder order;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: Key('home_order_${order.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(order.saleNumber.isEmpty ? '#${order.id}' : order.saleNumber),
      subtitle: Text(
        [
          if (order.customerName != null && order.customerName!.isNotEmpty)
            order.customerName!,
          paymentStatusLabel(order.paymentStatus),
        ].join(' · '),
      ),
      trailing: Text(order.total.toStringAsFixed(2)),
      onTap: () => context.push(AppRoutes.saleDetail(order.id)),
    );
  }
}
