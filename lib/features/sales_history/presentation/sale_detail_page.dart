import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/states/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../application/sales_history_controllers.dart';
import '../domain/payment_status.dart';

class SaleDetailPage extends ConsumerWidget {
  const SaleDetailPage({super.key, required this.saleId});

  final int saleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleDetailProvider(saleId));
    final canRefundPerm =
        ref.watch(authControllerProvider).session?.permissions.canRefundSales ??
            false;
    final detail = state.detail;
    final showRefund = canRefundPerm &&
        detail != null &&
        detail.canRefund &&
        detail.status == 'completed';

    return Scaffold(
      appBar: AppBar(title: Text(detail?.saleNumber ?? 'Sale')),
      body: _body(context, ref, state),
      bottomNavigationBar: showRefund
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: CbPrimaryButton(
                  key: const Key('sale_refund'),
                  label: 'Refund',
                  onPressed: () => _openRefund(context, ref),
                ),
              ),
            )
          : null,
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, SaleDetailState state) {
    if (state.loading && state.detail == null) {
      return const LoadingState(label: 'Loading sale…');
    }
    if (state.error != null && state.detail == null) {
      return ErrorState(
        message: state.error!,
        onRetry: () =>
            ref.read(saleDetailProvider(saleId).notifier).load(saleId),
      );
    }
    final detail = state.detail;
    if (detail == null) {
      return EmptyState(
        title: 'Sale not found',
        message: 'This sale may have been removed.',
        primaryLabel: 'Back',
        onPrimary: () => Navigator.of(context).maybePop(),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          key: const Key('sale_status_hero'),
          paymentStatusLabel(detail.paymentStatus),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Total ${detail.total.toStringAsFixed(2)} · Paid ${detail.amountPaid.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
        ),
        const SizedBox(height: 16),
        if (detail.customerName != null && detail.customerName!.isNotEmpty)
          _row('Customer', detail.customerName!),
        if (detail.paymentMethod != null)
          _row('Method', detail.paymentMethod!),
        if (detail.cashierName != null) _row('Cashier', detail.cashierName!),
        if (detail.occurredAt != null) _row('When', detail.occurredAt!),
        if (detail.refundStatus != null && detail.refundStatus != 'none')
          _row('Refund', detail.refundStatus!),
        const SizedBox(height: 16),
        Text('Items', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (detail.items.isEmpty)
          Text(
            'No line items',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.mutedForeground,
                ),
          )
        else
          for (final line in detail.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(line.productName),
              subtitle: Text(
                '${line.quantity} × ${line.unitPrice.toStringAsFixed(2)}',
              ),
              trailing: Text(line.lineTotal.toStringAsFixed(2)),
            ),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          Text(
            state.error!,
            key: const Key('sale_detail_error'),
            style: const TextStyle(color: AppColors.destructive),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: const TextStyle(color: AppColors.mutedForeground)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Future<void> _openRefund(BuildContext context, WidgetRef ref) async {
    var reason = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Refund sale'),
          content: TextField(
            key: const Key('refund_reason'),
            onChanged: (value) => reason = value,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('refund_confirm'),
              onPressed: () {
                if (reason.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    await ref.read(saleDetailProvider(saleId).notifier).refund(
          reason: reason,
        );
  }
}
