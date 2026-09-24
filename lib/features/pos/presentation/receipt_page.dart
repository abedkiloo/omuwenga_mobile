import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../data/pos_api.dart';
import 'receipt_layout.dart';
import 'receipt_share.dart';
import 'thermal_receipt.dart';

typedef ReceiptExport =
    Future<void> Function(SaleReceipt receipt, {ReceiptStoreInfo store});

class ReceiptPage extends StatefulWidget {
  const ReceiptPage({
    super.key,
    required this.receipt,
    this.store = const ReceiptStoreInfo(),
    this.onPrint = downloadOrPrintReceipt,
    this.onShare = shareReceipt,
  });

  final SaleReceipt receipt;
  final ReceiptStoreInfo store;
  final ReceiptExport onPrint;
  final ReceiptExport onShare;

  @override
  State<ReceiptPage> createState() => _ReceiptPageState();
}

class _ReceiptPageState extends State<ReceiptPage> {
  bool _exporting = false;

  SaleReceipt get receipt => widget.receipt;
  ReceiptStoreInfo get store => widget.store;

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
    final customer = receipt.customerName?.trim() ?? '';

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
                              '${receiptPaymentLabel(receipt.paymentMethod)}'
                              '${receipt.paymentReference?.trim().isNotEmpty == true ? ' Ref: ${receipt.paymentReference}' : ''}'
                              '${receipt.queuedOffline ? ' · Queued offline' : ' · Recorded to sales ledger'}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            if (customer.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                customer,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Material(
                      color: Colors.white,
                      elevation: 1,
                      child: ThermalReceiptView(receipt: receipt, store: store),
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
                                () => widget.onPrint(receipt, store: store),
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
                            : () => _runExport(
                                () => widget.onShare(receipt, store: store),
                              ),
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
