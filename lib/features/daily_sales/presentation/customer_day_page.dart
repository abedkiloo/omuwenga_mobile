import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/client_channel_icon.dart';
import '../../../design_system/states/async_states.dart';
import '../../sales_history/domain/payment_status.dart';
import '../application/daily_sales_controllers.dart';

class CustomerDayPage extends ConsumerWidget {
  const CustomerDayPage({
    super.key,
    required this.customerId,
    required this.date,
  });

  final int customerId;
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (customerId: customerId, date: date);
    final state = ref.watch(customerDayProvider(key));
    final detail = state.detail;

    return Scaffold(
      appBar: AppBar(title: Text(detail?.customerName ?? 'Customer day')),
      body: () {
        if (state.loading && detail == null) {
          return const LoadingState(label: 'Loading customer day…');
        }
        if (state.error != null && detail == null) {
          return ErrorState(
            message: state.error!,
            onRetry: () => ref
                .read(customerDayProvider(key).notifier)
                .load(customerId: customerId, date: date),
          );
        }
        if (detail == null) {
          return EmptyState(
            title: 'No day data',
            message: 'Could not load this customer day.',
            primaryLabel: 'Back',
            onPrimary: () => Navigator.of(context).maybePop(),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(
              key: const Key('customer_day_standing'),
              'Day standing: ${detail.dayStanding}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${detail.ordersCount} orders on $date',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            for (final order in detail.orders)
              ListTile(
                key: Key('customer_day_order_${order.id}'),
                contentPadding: EdgeInsets.zero,
                title: SaleNumberLabel(
                  saleNumber: order.saleNumber,
                  channel: order.clientChannel,
                ),
                subtitle: Text(paymentStatusLabel(order.paymentStatus)),
                trailing: Text(order.total.toStringAsFixed(2)),
                onTap: () => context.push(AppRoutes.saleDetail(order.id)),
              ),
          ],
        );
      }(),
    );
  }
}
