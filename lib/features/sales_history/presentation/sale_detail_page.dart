import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/client_channel_icon.dart';
import '../../../design_system/design_system.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/persona.dart';
import '../../pos/data/pos_api.dart';
import '../../pos/domain/cart.dart';
import '../../pos/application/pos_controllers.dart';
import '../../pos/presentation/receipt_document.dart';
import '../../pos/presentation/receipt_layout.dart';
import '../../pos/presentation/receipt_share.dart';
import '../../pos/presentation/thermal_receipt.dart';
import '../../pos/domain/payment.dart';
import '../application/sales_history_controllers.dart';
import '../domain/sale.dart';
import '../domain/sale_action_help.dart';
import '../domain/sale_status_display.dart';
import 'sale_action_help_icon.dart';

class SaleDetailPage extends ConsumerStatefulWidget {
  const SaleDetailPage({super.key, required this.saleId});

  final int saleId;

  @override
  ConsumerState<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends ConsumerState<SaleDetailPage> {
  final GlobalKey _receiptSnapshotKey = GlobalKey();
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(saleDetailProvider(widget.saleId));
    final canRefundPerm =
        ref.watch(authControllerProvider).session?.permissions.canRefundSales ??
        false;
    final canRollbackPerm =
        ref
            .watch(authControllerProvider)
            .session
            ?.permissions
            .canRollbackSales ??
        false;
    final session = ref.watch(authControllerProvider).session;
    final detail = state.detail;
    final awaitingApproval = detail?.status == 'pending_approval';
    final showRefund =
        canRefundPerm &&
        detail != null &&
        detail.canRefund &&
        detail.status == 'completed';
    final showRollback =
        canRollbackPerm &&
        detail != null &&
        detail.canRollback &&
        detail.status == 'completed';
    final refundNone =
        detail?.refundStatus == null || detail?.refundStatus == 'none';
    final showReturnForCorrection =
        session != null &&
        sessionCanAdminReturnSale(
          profile: session.profile,
          isSuperuser: session.user.isSuperuser,
        ) &&
        detail != null &&
        detail.status == 'completed' &&
        refundNone;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          detail == null ? 'Sale Detail' : 'Sale Detail #${detail.saleNumber}',
        ),
      ),
      body: _body(context, ref, state),
      bottomNavigationBar: detail == null
          ? null
          : _SaleActions(
              exporting: _exporting,
              showRefund: showRefund,
              showRollback: showRollback,
              showReturnForCorrection: showReturnForCorrection,
              receiptReady: detail.status == 'completed',
              onPrint: () {
                if (awaitingApproval) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A manager will approve this sale. Stock, books, and the receipt update after they approve.',
                      ),
                    ),
                  );
                  return;
                }
                _export(
                () => downloadOrPrintReceipt(
                  _receipt(detail),
                  store: _storeInfo(),
                ),
              );
              },
              onShare: () {
                if (awaitingApproval) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'A manager will approve this sale. Stock, books, and the receipt update after they approve.',
                      ),
                    ),
                  );
                  return;
                }
                _export(() async {
                final png = await snapshotWidgetPng(_receiptSnapshotKey);
                await shareReceipt(
                  _receipt(detail),
                  store: _storeInfo(),
                  pngBytes: png,
                );
              });
              },
              onRefund: () => _openRefund(context, ref),
              onRollback: () => _openRollback(context, ref),
              onReturnForCorrection: () => _openReturnForCorrection(context, ref),
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
    final session = ref.watch(authControllerProvider).session;
    final canCorrectDate =
        detail.status != 'cancelled' &&
        (detail.canCorrectDate ||
            (session?.permissions.canApproveSales ?? false));

    return Stack(
      children: [
        Positioned(
          left: -4000,
          top: 0,
          child: SizedBox(
            width: 280,
            child: RepaintBoundary(
              key: _receiptSnapshotKey,
              child: Material(
                color: Colors.white,
                child: ThermalReceiptView(
                  receipt: _receipt(detail),
                  store: _storeInfo(),
                ),
              ),
            ),
          ),
        ),
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          children: [
            if (detail.status == 'pending_approval') ...[
              CbSurfaceCard(
                child: Text(
                  'A manager will approve this sale. Stock, books, and the receipt update after they approve.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (detail.needsSalespersonAction) ...[
              CbSurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Needs salesperson action',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This sale was returned. Open it on POS, resolve the manager comment, then send it back for approval.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    if ((detail.rejectionReason ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Manager comment: ${detail.rejectionReason!.trim()}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 8),
                    FilledButton(
                      key: const Key('sale_detail_open_pos'),
                      onPressed: () => context.go(AppRoutes.posForSale(detail.id)),
                      child: const Text('Open sale'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
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
            if (canCorrectDate) _SaleDateEditor(detail: detail, saleId: widget.saleId),
            if (canCorrectDate) const SizedBox(height: 12),
            _AccountCard(detail: detail),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Itemized SKUs',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
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
        ),
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

  ReceiptStoreInfo _storeInfo() {
    final settings = ref
        .read(posSettingsProvider)
        .maybeWhen(data: (value) => value, orElse: () => const PosSettings());
    return ReceiptStoreInfo.fromPosSettings(settings);
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
            variantLabel: line.variantName,
          ),
      ],
      customerName: detail.customerName,
      subtotal: detail.subtotal,
      taxAmount: detail.taxAmount,
      discountAmount: detail.discountAmount,
      paymentReference: detail.paymentReference,
      createdAt: DateTime.tryParse(detail.occurredAt ?? ''),
      servedByName: detail.servedByName ?? detail.cashierName,
    );
  }

  Future<void> _openRefund(BuildContext context, WidgetRef ref) async {
    var reason = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Void or refund sale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SaleActionHelp.refund.body),
                const SizedBox(height: 8),
                Text(
                  SaleActionHelp.refund.contrast,
                  style: const TextStyle(color: AppColors.warning),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('refund_reason'),
                  onChanged: (value) => reason = value,
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
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
              child: const Text('Confirm void / refund'),
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

  Future<void> _openRollback(BuildContext context, WidgetRef ref) async {
    var reason = '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Roll back a mistaken sale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SaleActionHelp.rollback.body),
                const SizedBox(height: 8),
                Text(
                  SaleActionHelp.rollback.contrast,
                  style: const TextStyle(color: AppColors.warning),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('rollback_reason'),
                  onChanged: (value) => reason = value,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    helperText:
                        'Goes to Pending approvals. Stock and books change only after an admin approves.',
                    helperMaxLines: 2,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('rollback_confirm'),
              onPressed: () {
                if (reason.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Roll back'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    final applied = await ref
        .read(saleDetailProvider(widget.saleId).notifier)
        .rollback(reason: reason);
    if (!context.mounted) return;
    final stillOpen =
        ref.read(saleDetailProvider(widget.saleId)).detail?.canRollback ??
        false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied && stillOpen
              ? 'Rollback sent for admin approval. Books stay unchanged until it is approved.'
              : applied
              ? 'Sale rolled back.'
              : 'Could not roll back this sale.',
        ),
      ),
    );
  }

  Future<void> _openReturnForCorrection(
    BuildContext context,
    WidgetRef ref,
  ) async {
    var reason = '';
    final posted =
        ref.read(saleDetailProvider(widget.saleId)).detail?.status ==
        'completed';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Return sale for correction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(SaleActionHelp.returnForCorrection.body),
                const SizedBox(height: 8),
                Text(
                  posted
                      ? 'Stock, journal, and accounting will be reversed first.'
                      : SaleActionHelp.returnForCorrection.contrast,
                  style: const TextStyle(color: AppColors.warning),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('return_correction_reason'),
                  onChanged: (value) => reason = value,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Reason (required)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              key: const Key('return_correction_confirm'),
              onPressed: () {
                if (reason.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('Return for correction'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    final applied = await ref
        .read(saleDetailProvider(widget.saleId).notifier)
        .returnForCorrection(reason: reason);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          applied
              ? 'Sale returned to the salesperson for correction.'
              : 'Could not return this sale.',
        ),
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.detail});
  final SaleDetail detail;

  @override
  Widget build(BuildContext context) {
    final lifecycle = detail.lifecycle;
    final Color background;
    final Color iconColor;
    final IconData icon;
    switch (lifecycle.tone) {
      case SaleLifecycleTone.success:
        background = const Color(0xFFDCFCE7);
        iconColor = AppColors.success;
        icon = Icons.verified_outlined;
      case SaleLifecycleTone.danger:
        background = const Color(0xFFFEE2E2);
        iconColor = AppColors.destructive;
        icon = Icons.cancel_outlined;
      case SaleLifecycleTone.warning:
        background = const Color(0xFFFEF3C7);
        iconColor = AppColors.warning;
        icon = Icons.schedule_outlined;
      case SaleLifecycleTone.info:
        background = const Color(0xFFE0F2FE);
        iconColor = AppColors.primary;
        icon = Icons.hourglass_top_outlined;
      case SaleLifecycleTone.neutral:
        background = const Color(0xFFF1F5F9);
        iconColor = AppColors.mutedForeground;
        icon = Icons.info_outline;
    }
    return Container(
      key: const Key('sale_status_hero'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lifecycle.label,
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

class _SaleDateEditor extends ConsumerWidget {
  const _SaleDateEditor({required this.detail, required this.saleId});

  final SaleDetail detail;
  final int saleId;

  DateTime? _parsed() {
    final raw = detail.occurredAt;
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  String _label(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _parsed() ?? DateTime.now();
    return CbSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'SALE DATE',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Daily sales, reports, and the books use this date.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const Key('sale_detail_change_date'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: current,
                firstDate: DateTime(current.year - 10),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked == null) return;
              final ok = await ref
                  .read(saleDetailProvider(saleId).notifier)
                  .correctDate(occurredOn: picked);
              if (!context.mounted) return;
              final error = ref.read(saleDetailProvider(saleId)).error;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Sale date updated. Daily sales, reports, and books follow the new date.'
                        : (error ?? 'Could not change the sale date'),
                  ),
                ),
              );
            },
            child: Text('Change date · ${_label(current)}'),
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
                  leading:
                      detail.clientChannel == 'web' ||
                          detail.clientChannel == 'mobile'
                      ? ClientChannelIcon(channel: detail.clientChannel)
                      : null,
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
            _Meta(label: 'REFUND STATUS', value: detail.lifecycle.label),
          ],
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value, this.leading});
  final String label;
  final String value;
  final Widget? leading;

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
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Expanded(
              child: Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
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
                    line.sku!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  _money(line.lineTotal),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
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
            value: (detail.total -
                    (detail.amountPaid > detail.total
                        ? detail.total
                        : detail.amountPaid))
                .clamp(0, double.infinity),
          ),
          if ((detail.change > 0.005) ||
              (detail.amountPaid - detail.total) > 0.005)
            _AmountRow(
              label: 'Change given',
              value: detail.change > 0.005
                  ? detail.change
                  : detail.amountPaid - detail.total,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
                color: highlight ? AppColors.success : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              _money(value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
                color: highlight ? AppColors.success : null,
              ),
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
    required this.showRollback,
    required this.showReturnForCorrection,
    required this.receiptReady,
    required this.onPrint,
    required this.onShare,
    required this.onRefund,
    required this.onRollback,
    required this.onReturnForCorrection,
  });
  final bool exporting;
  final bool showRefund;
  final bool showRollback;
  final bool showReturnForCorrection;
  final bool receiptReady;
  final VoidCallback onPrint;
  final VoidCallback onShare;
  final VoidCallback onRefund;
  final VoidCallback onRollback;
  final VoidCallback onReturnForCorrection;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 10,
      color: AppColors.surface,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('sale_print_receipt'),
                  onPressed: exporting || !receiptReady ? null : onPrint,
                  icon: const Icon(Icons.print_outlined),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      exporting
                          ? 'Preparing receipt…'
                          : 'Print Duplicate Receipt',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final stacked = showRefund && constraints.maxWidth < 400;
                  final share = OutlinedButton.icon(
                    key: const Key('sale_share_receipt'),
                    onPressed: exporting || !receiptReady ? null : onShare,
                    icon: const Icon(Icons.share_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('WhatsApp Receipt'),
                    ),
                  );
                  if (!showRefund) {
                    return SizedBox(width: double.infinity, child: share);
                  }
                  final refund = OutlinedButton.icon(
                    key: const Key('sale_refund'),
                    onPressed: onRefund,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                    ),
                    icon: const Icon(Icons.block_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Void / refund'),
                    ),
                  );
                  if (stacked) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        share,
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: refund),
                            SaleActionHelpIcon(help: SaleActionHelp.refund),
                          ],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: share),
                      const SizedBox(width: 8),
                      Expanded(child: refund),
                      SaleActionHelpIcon(help: SaleActionHelp.refund),
                    ],
                  );
                },
              ),
              if (showRollback) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('sale_rollback'),
                          onPressed: onRollback,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.destructive,
                          ),
                          icon: const Icon(Icons.undo_outlined),
                          label: const Text('Roll back sale'),
                        ),
                      ),
                      SaleActionHelpIcon(help: SaleActionHelp.rollback),
                    ],
                  ),
                ),
              ],
              if (showReturnForCorrection) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const Key('sale_return_correction'),
                          onPressed: onReturnForCorrection,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.destructive,
                          ),
                          icon: const Icon(Icons.assignment_return_outlined),
                          label: const Text('Return for correction'),
                        ),
                      ),
                      SaleActionHelpIcon(
                        help: SaleActionHelp.returnForCorrection,
                      ),
                    ],
                  ),
                ),
              ],
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
