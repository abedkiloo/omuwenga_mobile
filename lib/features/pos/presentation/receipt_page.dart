import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../data/pos_api.dart';
import 'receipt_document.dart';

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({super.key, required this.receipt});

  final SaleReceipt receipt;

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  bool _exporting = false;

  SaleReceipt get receipt => widget.receipt;

  Future<void> _runExport(Future<void> Function() action) async {
    if (_exporting || receipt.queuedOffline) return;
    setState(() => _exporting = true);
    try {
      await action();
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create receipt: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final synced = !receipt.queuedOffline;
    final titleText = synced
        ? 'Payment Confirmed & Sale Recorded'
        : 'Saved — waiting to sync';
    final bannerLabel = synced
        ? 'Synced to central ledger'
        : 'Pending sync — saved locally';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const CbFlowHeader(
        title: 'Receipt Details',
        leadingIcon: Icons.receipt_long_outlined,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: synced ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            child: Row(
              children: [
                Icon(
                  synced
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_upload_outlined,
                  color: synced ? AppColors.success : AppColors.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    bannerLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '#${receipt.saleNumber}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.mutedForeground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              children: [
                CbSurfaceCard(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          color: Color(0xFFDCFCE7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          synced
                              ? Icons.check_circle
                              : Icons.cloud_upload_outlined,
                          color: synced ? AppColors.success : AppColors.warning,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              titleText,
                              key: const Key('receipt_title'),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_paymentLabel(receipt.paymentMethod)}'
                              '${receipt.paymentReference?.trim().isNotEmpty == true ? ' Ref: ${receipt.paymentReference}' : ''}'
                              '${receipt.queuedOffline ? ' · Queued offline' : ' · Recorded to sales ledger'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 248),
                    child: CbSurfaceCard(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.receipt_long_outlined,
                        color: AppColors.primary,
                        size: 16,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'COMPLETEBYTE POS',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Sale ${receipt.saleNumber}'
                        '${receipt.createdAt == null ? '' : ' · ${_dateTime(receipt.createdAt!)}'}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                          fontSize: 11,
                        ),
                      ),
                      if (receipt.customerName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Customer: ${receipt.customerName!}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                            fontSize: 11,
                          ),
                        ),
                      ],
                      if (receipt.servedByName?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Served by: ${receipt.servedByName!.trim()}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedForeground,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      for (final line in receipt.items) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${_quantity(line.quantity)}x ${line.displayName}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                    ),
                                    Text(
                                      '@ ${_kes(line.unitPrice)} each',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppColors.mutedForeground,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _kes(line.lineTotal),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 4),
                      _ReceiptAmountRow(
                        label: 'Subtotal',
                        amount:
                            receipt.subtotal ??
                            receipt.items.fold<double>(
                              0,
                              (sum, line) => sum + line.lineTotal,
                            ),
                      ),
                      if (receipt.taxAmount > 0)
                        _ReceiptAmountRow(
                          label: 'Tax',
                          amount: receipt.taxAmount,
                        ),
                      if (receipt.discountAmount > 0)
                        _ReceiptAmountRow(
                          label: 'Discount',
                          amount: -receipt.discountAmount,
                          color: AppColors.success,
                        ),
                      const SizedBox(height: 3),
                      _ReceiptAmountRow(
                        label: 'TOTAL NET',
                        amount: receipt.total,
                        total: true,
                        amountKey: const Key('receipt_total'),
                      ),
                      const SizedBox(height: 6),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      _ReceiptDetailRow(
                        label: 'Payment Method',
                        value: _paymentLabel(receipt.paymentMethod),
                      ),
                      _ReceiptDetailRow(
                        label: 'Amount Paid',
                        value: _kes(receipt.amountPaid),
                      ),
                      if (receipt.change > 0)
                        _ReceiptDetailRow(
                          label: 'Change',
                          value: _kes(receipt.change),
                        ),
                      if (receipt.paymentReference?.trim().isNotEmpty == true)
                        _ReceiptDetailRow(
                          label: 'Transaction ID',
                          value: receipt.paymentReference!.trim(),
                        ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      _BarcodeBars(seed: receipt.saleNumber),
                      const SizedBox(height: 3),
                      Text(
                        receipt.saleNumber,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.2,
                          color: AppColors.mutedForeground,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const Key('receipt_reach_us'),
                        onPressed: () async {
                          await Clipboard.setData(
                            const ClipboardData(text: kReceiptReachUsPhone),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied $kReceiptReachUsPhone'),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.phone_outlined, size: 14),
                        label: const Text(
                          kReceiptReachUsLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Asante kwa biashara yako. Karibu tena.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.mutedForeground,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                  ),
                ),
                if (receipt.queuedOffline) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Receipt export becomes available after this sale syncs.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Material(
            color: AppColors.surface,
            elevation: 8,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 42,
                      child: FilledButton.icon(
                        key: const Key('receipt_download'),
                        onPressed: !synced || _exporting
                            ? null
                            : () => _runExport(
                                () => downloadOrPrintReceipt(receipt),
                              ),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.primaryForeground,
                        ),
                        icon: _exporting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.print_outlined, size: 19),
                        label: const Text('Download / Print Receipt'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 38,
                      child: OutlinedButton.icon(
                        key: const Key('receipt_share'),
                        onPressed: !synced || _exporting
                            ? null
                            : () => _runExport(() => shareReceipt(receipt)),
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Share via WhatsApp / SMS'),
                      ),
                    ),
                    TextButton(
                      key: const Key('receipt_done'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Start Next Sale'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptAmountRow extends StatelessWidget {
  const _ReceiptAmountRow({
    required this.label,
    required this.amount,
    this.total = false,
    this.color,
    this.amountKey,
  });

  final String label;
  final double amount;
  final bool total;
  final Color? color;
  final Key? amountKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = total
        ? theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color ?? AppColors.primary,
          )
        : theme.textTheme.bodySmall?.copyWith(
            color: color ?? AppColors.mutedForeground,
            fontWeight: FontWeight.w600,
          );
    final formatted = amount < 0 ? '-${_kes(-amount)}' : _kes(amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(key: amountKey, formatted, style: style),
        ],
      ),
    );
  }
}

class _ReceiptDetailRow extends StatelessWidget {
  const _ReceiptDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(color: AppColors.mutedForeground),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: style?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarcodeBars extends StatelessWidget {
  const _BarcodeBars({required this.seed});

  final String seed;

  @override
  Widget build(BuildContext context) {
    final codes = seed.codeUnits.isEmpty ? const [1] : seed.codeUnits;
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 42; i++) ...[
            Container(
              width: 1 + (codes[i % codes.length] + i) % 3,
              color: i.isEven ? AppColors.primary : Colors.transparent,
            ),
            const SizedBox(width: 1),
          ],
        ],
      ),
    );
  }
}

String _kes(num value) => 'KES ${value.toStringAsFixed(2)}';

String _quantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

String _paymentLabel(String raw) {
  switch (raw.trim().toLowerCase()) {
    case 'mpesa':
      return 'M-PESA';
    case 'cash':
      return 'Cash';
    case 'card':
      return 'Card';
    default:
      return raw.isEmpty ? 'Payment' : raw;
  }
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
