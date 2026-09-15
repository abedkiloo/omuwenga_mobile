import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/design_system.dart';
import '../data/pos_api.dart';

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.receipt});

  final SaleReceipt receipt;

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
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: synced
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(AppColors.radius),
            ),
            child: Row(
              children: [
                Icon(
                  synced ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                CbSurfaceCard(
                  child: Column(
                    children: [
                      Icon(
                        synced
                            ? Icons.check_circle
                            : Icons.cloud_upload_outlined,
                        color:
                            synced ? AppColors.success : AppColors.warning,
                        size: 52,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        titleText,
                        key: const Key('receipt_title'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${receipt.paymentMethod}'
                        '${receipt.queuedOffline ? ' · Queued offline' : ''}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CbSurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.description_outlined,
                              color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Sale #${receipt.saleNumber}',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (receipt.customerName != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          receipt.customerName!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      for (final line in receipt.items) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${line.quantity.round()}x ${line.displayName}',
                                    ),
                                    Text(
                                      '@ ${line.unitPrice.toStringAsFixed(2)} each',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'KES ${line.lineTotal.toStringAsFixed(2)}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 1, thickness: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TOTAL NET',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            key: const Key('receipt_total'),
                            'KES ${receipt.total.toStringAsFixed(2)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${receipt.paymentMethod} · paid ${receipt.amountPaid.toStringAsFixed(2)}'
                        '${receipt.change > 0 ? ' · change ${receipt.change.toStringAsFixed(2)}' : ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Asante kwa biashara yako. Karibu tena.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CbStickyActionBar(
            summary: 'CART CLEARED',
            summaryTrailing: 'KES 0.00',
            primaryLabel: 'Start Next Sale',
            primaryKey: const Key('receipt_done'),
            onPrimary: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
