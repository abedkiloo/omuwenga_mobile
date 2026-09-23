import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/client_channel_icon.dart';
import '../../../design_system/design_system.dart';
import '../../customers/presentation/debt_collection_list.dart';
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
                    selected:
                        state.statusFilter == null && !state.showingCollections,
                    onSelected: () => ref
                        .read(dailySalesProvider.notifier)
                        .setStatusFilter(null),
                  ),
                  _StatusChip(
                    key: const Key('daily_tab_paid'),
                    label: 'Paid',
                    selected:
                        state.statusFilter == PaymentStatusDisplay.paid &&
                        !state.showingCollections,
                    onSelected: () => ref
                        .read(dailySalesProvider.notifier)
                        .setStatusFilter(PaymentStatusDisplay.paid),
                  ),
                  _StatusChip(
                    key: const Key('daily_tab_debt'),
                    label: 'Debt',
                    selected:
                        state.statusFilter == PaymentStatusDisplay.debt &&
                        !state.showingCollections,
                    onSelected: () => ref
                        .read(dailySalesProvider.notifier)
                        .setStatusFilter(PaymentStatusDisplay.debt),
                  ),
                  _StatusChip(
                    key: const Key('daily_tab_partial'),
                    label: 'Partial',
                    selected:
                        state.statusFilter == PaymentStatusDisplay.partial &&
                        !state.showingCollections,
                    onSelected: () => ref
                        .read(dailySalesProvider.notifier)
                        .setStatusFilter(PaymentStatusDisplay.partial),
                  ),
                  _StatusChip(
                    key: const Key('daily_tab_collected'),
                    label: 'Debt collected',
                    selected: state.showingCollections,
                    onSelected: () => ref
                        .read(dailySalesProvider.notifier)
                        .showCollectionsTab(),
                  ),
                ],
              ),
            ),
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            if (report != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: _SummaryStrip(
                  summary: report.summary,
                  collectedSelected: state.showingCollections,
                  onCollectedTap: () => ref
                      .read(dailySalesProvider.notifier)
                      .showCollectionsTab(),
                  onDebtTap: () => ref
                      .read(dailySalesProvider.notifier)
                      .setStatusFilter(PaymentStatusDisplay.debt),
                  onPaidTap: () => ref
                      .read(dailySalesProvider.notifier)
                      .setStatusFilter(PaymentStatusDisplay.paid),
                ),
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
    if (state.showingCollections) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        children: [
          DebtCollectionsPanel(
            date: state.dateApi,
            collections: state.report?.collections,
            loading: state.loading,
            showDateNav: false,
            onOpenCustomer: (row) => context.push(
              AppRoutes.customerDetail(row.customerId, tab: 'ledger'),
            ),
            onRetry: () => ref.read(dailySalesProvider.notifier).load(),
          ),
        ],
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
          title: SaleNumberLabel(
            saleNumber: order.saleNumber,
            channel: order.clientChannel,
          ),
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
  const _SummaryStrip({
    required this.summary,
    required this.onCollectedTap,
    required this.onDebtTap,
    required this.onPaidTap,
    this.collectedSelected = false,
  });

  final DailySummary summary;
  final VoidCallback onCollectedTap;
  final VoidCallback onDebtTap;
  final VoidCallback onPaidTap;
  final bool collectedSelected;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: AppColors.mutedForeground);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: const Key('daily_summary_sales'),
          'Sales ${summary.totalSales.toStringAsFixed(2)} · ${summary.ordersCount} orders',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _SummaryLink(
              key: const Key('daily_summary_paid'),
              label:
                  'Paid ${summary.totalPaid.toStringAsFixed(2)}',
              onTap: onPaidTap,
              style: muted,
            ),
            _SummaryLink(
              key: const Key('daily_summary_debt'),
              label:
                  'Debt ${summary.totalDebtIncurred.toStringAsFixed(2)}',
              onTap: onDebtTap,
              style: muted,
            ),
            _SummaryLink(
              key: const Key('daily_summary_collected'),
              label:
                  'Collected ${summary.totalDebtCollected.toStringAsFixed(2)} · ${summary.debtSettlementCount} payment${summary.debtSettlementCount == 1 ? '' : 's'}',
              onTap: onCollectedTap,
              selected: collectedSelected,
              style: muted?.copyWith(
                color: collectedSelected
                    ? AppColors.primary
                    : (summary.totalDebtCollected > 0
                          ? AppColors.success
                          : AppColors.mutedForeground),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryLink extends StatelessWidget {
  const _SummaryLink({
    super.key,
    required this.label,
    required this.onTap,
    this.style,
    this.selected = false,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle? style;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: style?.copyWith(
            decoration: TextDecoration.underline,
            fontWeight: selected ? FontWeight.w700 : style?.fontWeight,
          ),
        ),
      ),
    );
  }
}
