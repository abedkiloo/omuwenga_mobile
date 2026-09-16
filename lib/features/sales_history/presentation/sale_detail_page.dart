import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../../pos/data/pos_api.dart';
import '../../pos/domain/cart.dart';
import '../../pos/presentation/receipt_document.dart';
import '../application/sales_history_controllers.dart';
import '../domain/payment_status.dart';
import '../domain/sale.dart';

class SaleDetailPage extends ConsumerStatefulWidget {
  const SaleDetailPage({super.key, required this.saleId});

  final int saleId;

  @override
  ConsumerState<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends ConsumerState<SaleDetailPage> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(saleDetailProvider(widget.saleId));
    final canRefundPerm =
        ref.watch(authControllerProvider).session?.permissions.canRefundSales ??
        false;
    final detail = state.detail;
    final showRefund =
        canRefundPerm &&
        detail != null &&
        detail.canRefund &&
        detail.status == 'completed';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          detail == null ? 'Sale Detail' : 'Sale Detail #${detail.saleNumber}',
        ),
        actions: [
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: CbStatusPill(
                label: (detail.saleType ?? 'POS').toUpperCase(),
                variant: CbStatusPillVariant.info,
              ),
            ),
        ],
      ),
      body: _body(context, ref, state),
      bottomNavigationBar: detail == null
          ? null
          : _SaleActions(
              exporting: _exporting,
              showRefund: showRefund,
              onPrint: () =>
                  _export(() => downloadOrPrintReceipt(_receipt(detail))),
              onShare: () => _export(() => shareReceipt(_receipt(detail))),
              onRefund: () => _openRefund(context, ref),
            ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, SaleDetailState state) {
    if (state.loading && state.detail == null) {
      return const LoadingState(label: 'Loading sale…');
    }
    if (state.error != null && state.detail == null) {
      return ErrorState(
        message: state.error!,
        onRetry: () => ref
            .read(saleDetailProvider(widget.saleId).notifier)
            .load(widget.saleId),
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

    final subtotal = detail.subtotal > 0
        ? detail.subtotal
        : detail.items.fold<double>(0, (sum, item) => sum + item.lineTotal);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        if (state.error != null) ...[
          Container(
            key: const Key('sale_detail_error'),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              state.error!,
              style: const TextStyle(color: AppColors.destructive),
            ),
          ),
          const SizedBox(height: 10),
        ],
        _CompletionBanner(detail: detail),
        const SizedBox(height: 12),
        _AccountCard(detail: detail),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                'Itemized SKUs',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            CbStatusPill(
              label: '${detail.items.length} LINES',
              variant: CbStatusPillVariant.neutral,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (detail.items.isEmpty)
          const CbSurfaceCard(
            child: Text('No line items were returned for this sale.'),
          )
        else
          for (final line in detail.items) ...[
            _SaleLineCard(line: line),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 8),
        _FinancialAccounting(detail: detail, subtotal: subtotal),
        const SizedBox(height: 12),
        _TenderAudit(detail: detail),
      ],
    );
  }

  Future<void> _export(Future<void> Function() action) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Receipt action failed: $error')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  SaleReceipt _receipt(SaleDetail detail) {
    return SaleReceipt(
      id: detail.id,
      saleNumber: detail.saleNumber,
      total: detail.total,
      paymentMethod: detail.paymentMethod ?? '',
      amountPaid: detail.amountPaid,
      change: detail.change,
      items: [
        for (final line in detail.items)
          CartLine(
            productId: line.productId ?? 0,
            name: line.productName,
            sku: line.sku,
            unitPrice: line.unitPrice,
            quantity: line.quantity,
          ),
      ],
      customerName: detail.customerName,
      subtotal: detail.subtotal,
      taxAmount: detail.taxAmount,
      discountAmount: detail.discountAmount,
      paymentReference: detail.paymentReference,
      createdAt: DateTime.tryParse(detail.occurredAt ?? ''),
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
    await ref
        .read(saleDetailProvider(widget.saleId).notifier)
        .refund(reason: reason);
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.detail});
  final SaleDetail detail;

  @override
  Widget build(BuildContext context) {
    final settled = detail.paymentStatus == PaymentStatusDisplay.paid;
    return Container(
      key: const Key('sale_status_hero'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: settled ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            settled ? Icons.verified_outlined : Icons.schedule_outlined,
            color: settled ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settled
                      ? 'Completed & Settled'
                      : paymentStatusLabel(detail.paymentStatus),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  detail.occurredAt ?? 'Recorded sale',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.detail});
  final SaleDetail detail;

  @override
  Widget build(BuildContext context) {
    return CbSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CbStatusPill(
            label: 'CUSTOMER ACCOUNT',
            variant: CbStatusPillVariant.info,
          ),
          const SizedBox(height: 8),
          Text(
            detail.customerName?.trim().isNotEmpty == true
                ? detail.customerName!
                : 'Walk-in Retail',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Divider(height: 22),
          Row(
            children: [
              Expanded(
                child: _Meta(
                  label: 'SALE / ORDER REF',
                  value: '#${detail.saleNumber}',
                ),
              ),
              Expanded(
                child: _Meta(
                  label: 'LOGGED CASHIER',
                  value: detail.cashierName ?? '—',
                ),
              ),
            ],
          ),
          if (detail.servedByName != null) ...[
            const SizedBox(height: 10),
            _Meta(label: 'SERVED BY', value: detail.servedByName!),
          ],
          if (detail.refundStatus != null && detail.refundStatus != 'none') ...[
            const SizedBox(height: 10),
            _Meta(label: 'REFUND STATUS', value: detail.refundStatus!),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.mutedForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _SaleLineCard extends StatelessWidget {
  const _SaleLineCard({required this.line});
  final SaleLine line;

  @override
  Widget build(BuildContext context) {
    return CbSurfaceCard(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (line.sku?.isNotEmpty == true)
                  Text(
                    'SKU: ${line.sku}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                Text(
                  'Unit Price: ${_money(line.unitPrice)}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _money(line.lineTotal),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                'Qty: ${line.quantity.toStringAsFixed(line.quantity % 1 == 0 ? 0 : 2)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinancialAccounting extends StatelessWidget {
  const _FinancialAccounting({required this.detail, required this.subtotal});
  final SaleDetail detail;
  final double subtotal;

  @override
  Widget build(BuildContext context) {
    return CbSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Financial Accounting',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _AmountRow(label: 'Subtotal (Gross Itemized)', value: subtotal),
          if (detail.discountAmount > 0)
            _AmountRow(
              label: 'Discount Applied',
              value: -detail.discountAmount,
              highlight: true,
            ),
          _AmountRow(label: 'Tax Amount', value: detail.taxAmount),
          const Divider(),
          _AmountRow(
            label: 'TOTAL NET SETTLED',
            value: detail.total,
            strong: true,
          ),
          _AmountRow(
            label: 'Outstanding Balance',
            value: (detail.total - detail.amountPaid).clamp(0, double.infinity),
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.highlight = false,
  });
  final String label;
  final double value;
  final bool strong;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
                color: highlight ? AppColors.success : null,
              ),
            ),
          ),
          Text(
            _money(value),
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              color: highlight ? AppColors.success : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _TenderAudit extends StatelessWidget {
  const _TenderAudit({required this.detail});
  final SaleDetail detail;

  @override
  Widget build(BuildContext context) {
    return CbSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 9, color: AppColors.success),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Tender & Gateway Audit',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              const CbStatusPill(
                label: 'SETTLED',
                variant: CbStatusPillVariant.success,
              ),
            ],
          ),
          const Divider(height: 22),
          _Meta(
            label: 'PAYMENT METHOD',
            value: (detail.paymentMethod ?? 'Unknown').toUpperCase(),
          ),
          if (detail.paymentReference?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Meta(
                    label: 'PAYMENT REFERENCE',
                    value: detail.paymentReference!,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy reference',
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: detail.paymentReference!),
                  ),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            'Transaction ${detail.id} · ${detail.occurredAt ?? 'Time unavailable'}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _SaleActions extends StatelessWidget {
  const _SaleActions({
    required this.exporting,
    required this.showRefund,
    required this.onPrint,
    required this.onShare,
    required this.onRefund,
  });
  final bool exporting;
  final bool showRefund;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        elevation: 10,
        color: AppColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('sale_print_receipt'),
                  onPressed: exporting ? null : onPrint,
                  icon: const Icon(Icons.print_outlined),
                  label: Text(
                    exporting
                        ? 'Preparing receipt…'
                        : 'Print Duplicate Receipt',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('sale_share_receipt'),
                      onPressed: exporting ? null : onShare,
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('WhatsApp Receipt'),
                    ),
                  ),
                  if (showRefund) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('sale_refund'),
                        onPressed: onRefund,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.destructive,
                        ),
                        icon: const Icon(Icons.block_outlined),
                        label: const Text('Void / Refund'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _money(double value) {
  final sign = value < 0 ? '-' : '';
  return '${sign}KES ${value.abs().toStringAsFixed(2)}';
}
