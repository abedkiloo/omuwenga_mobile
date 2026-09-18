import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../sales_history/domain/payment_status.dart';
import '../application/daily_sales_controllers.dart';
import '../domain/daily_navigation.dart';
import '../domain/daily_report.dart';

String _friendlyDayLabel(DateTime day) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[day.weekday - 1];
  return '$weekday, ${day.day} ${months[day.month - 1]}';
}

class DailySalesPage extends ConsumerWidget {
  const DailySalesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dailySalesProvider);
    final report = state.report;

    return Scaffold(
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              child: Text(
                'Daily sales',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: CbSurfaceCard(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('daily_prev_day'),
                      onPressed: state.loading
                          ? null
                          : () => ref
                                .read(dailySalesProvider.notifier)
                                .goToPreviousDay(),
                      icon: const Icon(Icons.chevron_left),
                      color: AppColors.primary,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            'Day',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.mutedForeground,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            key: const Key('daily_date_label'),
                            _friendlyDayLabel(state.day),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('daily_next_day'),
                      onPressed: state.loading
                          ? null
                          : () => ref
                                .read(dailySalesProvider.notifier)
                                .goToNextDay(),
                      icon: const Icon(Icons.chevron_right),
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(
                children: [
                  _StatusChip(
                    key: const Key('daily_tab_all'),
                    label: 'All',
                    selected: state.statusFilter == null,
                    onSelected: () => ref
                        .read(dailySalesProvider.notifier)
                        .setStatusFilter(null),
                  ),
                  _StatusChip(
                    key: const Key('daily_tab_paid'),
                    label: 'Paid',
                    selected: state.statusFilter == PaymentStatusDisplay.paid,
                    onSelected: () => ref
                        .read(dailySalesProvider.notifier)
                        .setStatusFilter(PaymentStatusDisplay.paid),
                  ),
                  _StatusChip(
                    key: const Key('daily_tab_debt'),
                    label: 'Debt',
                    selected: state.statusFilter == PaymentStatusDisplay.debt,
                    onSelected: () => ref
                        .read(dailySalesProvider.notifier)
                        .setStatusFilter(PaymentStatusDisplay.debt),
                  ),
                  _StatusChip(
                    key: const Key('daily_tab_partial'),
                    label: 'Partial',
                    selected:
                        state.statusFilter == PaymentStatusDisplay.partial,
                    onSelected: () => ref
                        .read(dailySalesProvider.notifier)
                        .setStatusFilter(PaymentStatusDisplay.partial),
                  ),
                ],
              ),
            ),
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            if (report != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _SummaryStrip(summary: report.summary),
              ),
            Expanded(child: _body(context, ref, state)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, DailySalesState state) {
    if (state.loading && state.report == null) {
      return const LoadingState(label: 'Loading daily sales…');
    }
    if (state.error != null && state.report == null) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref.read(dailySalesProvider.notifier).load(),
      );
    }
    final orders = state.report?.orders ?? const [];
    if (orders.isEmpty) {
      return EmptyState(
        key: const Key('daily_empty'),
        title: 'No orders',
        message: 'Nothing for this day and filter.',
        primaryLabel: 'Refresh',
        onPrimary: () => ref.read(dailySalesProvider.notifier).load(),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final order = orders[i];
        return ListTile(
          key: Key('daily_order_${order.id}'),
          contentPadding: EdgeInsets.zero,
          title: Text(order.saleNumber),
          subtitle: Text(
            [
              if (order.customerName != null && order.customerName!.isNotEmpty)
                order.customerName,
              paymentStatusLabel(order.paymentStatus),
            ].whereType<String>().join(' · '),
          ),
          trailing: Text(order.total.toStringAsFixed(2)),
          onTap: () =>
              context.push(dailyOrderRoute(order, date: state.dateApi)),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: CbFilterChip(
        label: label,
        selected: selected,
        compact: true,
        onTap: onSelected,
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const Key('daily_summary_sales'),
          'Sales ${summary.totalSales.toStringAsFixed(2)} · ${summary.ordersCount} orders',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        Text(
          'Paid ${summary.totalPaid.toStringAsFixed(2)} · Debt ${summary.totalDebtIncurred.toStringAsFixed(2)} · Collected ${summary.totalCollected.toStringAsFixed(2)}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground),
        ),
      ],
    );
  }
}
