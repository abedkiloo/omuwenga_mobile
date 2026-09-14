import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../design_system/buttons/cb_primary_button.dart';
import '../data/pos_api.dart';

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({super.key, required this.receipt});

  final SaleReceipt receipt;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                receipt.queuedOffline ? 'Saved — waiting to sync' : 'Sale complete',
                key: const Key('receipt_title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text('Sale #${receipt.saleNumber}'),
              if (receipt.customerName != null) Text(receipt.customerName!),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: receipt.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final line = receipt.items[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(line.displayName),
                      subtitle: Text(
                        '${line.quantity} × ${line.unitPrice.toStringAsFixed(2)}',
                      ),
                      trailing: Text(line.lineTotal.toStringAsFixed(2)),
                    );
                  },
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total'),
                  Text(
                    key: const Key('receipt_total'),
                    receipt.total.toStringAsFixed(2),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${receipt.paymentMethod} · paid ${receipt.amountPaid.toStringAsFixed(2)}'
                '${receipt.change > 0 ? ' · change ${receipt.change.toStringAsFixed(2)}' : ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedForeground,
                    ),
              ),
              const SizedBox(height: 24),
              CbPrimaryButton(
                key: const Key('receipt_done'),
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
