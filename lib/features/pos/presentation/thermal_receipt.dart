import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../data/pos_api.dart';
import '../domain/cart.dart';
import 'receipt_layout.dart';

const _priceGreen = Color(0xFF15803D);
const _receiptBlack = Color(0xFF111111);

/// On-screen thermal receipt matching the web share/print layout.
class ThermalReceiptView extends StatelessWidget {
  const ThermalReceiptView({
    super.key,
    required this.receipt,
    this.store = const ReceiptStoreInfo(),
  });

  final SaleReceipt receipt;
  final ReceiptStoreInfo store;

  @override
  Widget build(BuildContext context) {
    final served = receipt.servedByName?.trim() ?? '';
    final date = formatReceiptDate(receipt.createdAt);
    final reference = receipt.paymentReference?.trim() ?? '';
    final owed = receiptBalanceOwed(receipt);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: DefaultTextStyle(
        style: const TextStyle(
          fontFamily: 'Courier',
          fontFamilyFallback: ['Menlo', 'monospace'],
          fontSize: 12,
          height: 1.22,
          color: _receiptBlack,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              store.storeName.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                letterSpacing: 0.4,
              ),
            ),
            if (store.header.isNotEmpty)
              Text(
                store.header,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            if (store.branchName.isNotEmpty &&
                store.branchName.toLowerCase() != store.storeName.toLowerCase())
              Text(
                store.branchName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            if (store.address.isNotEmpty)
              Text(
                store.address,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            if (store.phone.isNotEmpty)
              Text(
                store.phone,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            if (store.taxId.isNotEmpty)
              Text(
                'PIN: ${store.taxId}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            const SizedBox(height: 6),
            const _DoubleRule(),
            _ReceiptRow(
              left: 'Receipt',
              right: receipt.saleNumber.isEmpty ? '—' : receipt.saleNumber,
              bold: true,
              price: false,
            ),
            if (date.isNotEmpty)
              _ReceiptRow(left: 'Date', right: date, price: false),
            if (served.isNotEmpty)
              _ReceiptRow(left: 'Served by', right: served, price: false),
            const _SingleRule(),
            if (receipt.items.isEmpty)
              const Text('No items.', style: TextStyle(fontSize: 11))
            else
              for (final line in receipt.items)
                _ItemBlock(line: line, showSku: store.showSku),
            const _SingleRule(),
            _ReceiptRow(
              left: 'Subtotal',
              right: formatReceiptMoney(receiptSubtotal(receipt)),
            ),
            if (receipt.discountAmount > 0)
              _ReceiptRow(
                left: 'Discount',
                right: '-${formatReceiptMoney(receipt.discountAmount)}',
              ),
            if (receipt.taxAmount > 0)
              _ReceiptRow(
                left: receipt.taxRate > 0
                    ? 'VAT (${receipt.taxRate.toStringAsFixed(0)}%)'
                    : 'VAT',
                right: formatReceiptMoney(receipt.taxAmount),
              ),
            if (receipt.deliveryCost > 0)
              _ReceiptRow(
                left: 'Delivery',
                right: formatReceiptMoney(receipt.deliveryCost),
              ),
            const _DoubleRule(),
            _ReceiptRow(
              left: 'TOTAL',
              right: formatReceiptMoney(receipt.total),
              bold: true,
              emphasised: true,
              amountKey: const Key('receipt_total'),
            ),
            const _DoubleRule(),
            _ReceiptRow(
              left: receiptPaymentLabel(receipt.paymentMethod),
              right: formatReceiptMoney(receipt.amountPaid),
            ),
            if (reference.isNotEmpty)
              _ReceiptRow(left: 'Ref', right: reference, price: false),
            if (receiptShowsChange(receipt))
              _ReceiptRow(
                left: 'Change',
                right: formatReceiptMoney(receipt.change),
                bold: true,
              ),
            if (owed > 0.005)
              _ReceiptRow(
                left: 'Balance (owed)',
                right: formatReceiptMoney(owed),
                bold: true,
              ),
            if (receipt.paymentMethod.trim().toLowerCase() == 'wallet')
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Paid from customer wallet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ),
            const _SingleRule(),
            const SizedBox(height: 4),
            Text(
              store.footer,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Center(
              child: OutlinedButton(
                key: const Key('receipt_reach_us'),
                onPressed: () {
                  Clipboard.setData(
                    const ClipboardData(text: kReceiptReachUsPhone),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied $kReceiptReachUsPhone'),
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _receiptBlack,
                  side: const BorderSide(color: _receiptBlack),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child: const Text(
                  kReceiptReachUsLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            if (receipt.saleNumber.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                receipt.saleNumber,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.6,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ItemBlock extends StatelessWidget {
  const _ItemBlock({required this.line, required this.showSku});

  final CartLine line;
  final bool showSku;

  @override
  Widget build(BuildContext context) {
    final variant = receiptItemVariant(line);
    final sku = line.sku?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              text: receiptItemName(line),
              style: const TextStyle(fontWeight: FontWeight.w700),
              children: [
                if (variant != null)
                  TextSpan(
                    text: ' ($variant)',
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          if (showSku && sku.isNotEmpty)
            Text(
              sku,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.mutedForeground,
              ),
            ),
          _ReceiptRow(
            left: receiptItemQtyLine(line),
            right: formatReceiptMoney(line.lineTotal),
          ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.left,
    required this.right,
    this.bold = false,
    this.emphasised = false,
    this.price = true,
    this.amountKey,
  });

  final String left;
  final String right;
  final bool bold;
  final bool emphasised;
  final bool price;
  final Key? amountKey;

  @override
  Widget build(BuildContext context) {
    final weight = bold || emphasised ? FontWeight.w800 : FontWeight.w500;
    final size = emphasised ? 14.0 : 12.0;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: emphasised ? 3 : 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(fontWeight: weight, fontSize: size),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            key: amountKey,
            right,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: emphasised ? 15 : size,
              color: price ? _priceGreen : _receiptBlack,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoubleRule extends StatelessWidget {
  const _DoubleRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Divider(height: 1, thickness: 1, color: _receiptBlack),
          SizedBox(height: 1.5),
          Divider(height: 1, thickness: 1, color: _receiptBlack),
        ],
      ),
    );
  }
}

class _SingleRule extends StatelessWidget {
  const _SingleRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Divider(height: 1, thickness: 1, color: _receiptBlack),
    );
  }
}
