import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/pos_api.dart';
import '../domain/cart.dart';
import 'receipt_layout.dart';

export 'receipt_layout.dart'
    show
        kReceiptReachUsPhone,
        kReceiptReachUsLabel,
        ReceiptStoreInfo,
        buildThermalReceiptText,
        formatReceiptMoney,
        formatReceiptDate,
        receiptPaymentLabel;

const _priceGreen = PdfColor.fromInt(0xFF15803D);

PdfPageFormat receiptPdfPageFormat() => PdfPageFormat(
  80 * PdfPageFormat.mm,
  double.infinity,
  marginAll: 2.5 * PdfPageFormat.mm,
);

String receiptFileName(SaleReceipt receipt) {
  final safeNumber = receipt.saleNumber.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '-',
  );
  return 'receipt-$safeNumber.pdf';
}

Future<Uint8List> buildReceiptPdf(
  SaleReceipt receipt, {
  ReceiptStoreInfo store = const ReceiptStoreInfo(),
}) async {
  final document = pw.Document(
    title: 'Receipt ${receipt.saleNumber}',
    author: 'CompleteByte POS',
  );

  document.addPage(
    pw.Page(
      pageFormat: receiptPdfPageFormat(),
      build: (_) => pw.DefaultTextStyle(
        style: const pw.TextStyle(
          fontSize: 8.5,
          color: PdfColors.black,
          lineSpacing: 1.1,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    store.storeName.toUpperCase(),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  if (store.header.isNotEmpty)
                    pw.Text(
                      store.header,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  if (store.branchName.isNotEmpty &&
                      store.branchName.toLowerCase() !=
                          store.storeName.toLowerCase())
                    pw.Text(
                      store.branchName,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  if (store.address.isNotEmpty)
                    pw.Text(
                      store.address,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  if (store.phone.isNotEmpty)
                    pw.Text(
                      store.phone,
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  if (store.taxId.isNotEmpty)
                    pw.Text(
                      'PIN: ${store.taxId}',
                      textAlign: pw.TextAlign.center,
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                ],
              ),
            ),
            pw.SizedBox(height: 4),
            _doubleRule(),
            pw.SizedBox(height: 3),
            _pdfPair(
              'Receipt',
              receipt.saleNumber.isEmpty ? '—' : receipt.saleNumber,
              bold: true,
            ),
            if (formatReceiptDate(receipt.createdAt).isNotEmpty)
              _pdfPair('Date', formatReceiptDate(receipt.createdAt)),
            if (receipt.servedByName?.trim().isNotEmpty == true)
              _pdfPair('Served by', receipt.servedByName!.trim()),
            pw.SizedBox(height: 3),
            _singleRule(),
            pw.SizedBox(height: 2),
            if (receipt.items.isEmpty)
              pw.Text('No items.', style: const pw.TextStyle(fontSize: 8))
            else
              for (final line in receipt.items) ..._itemBlock(line, store),
            _singleRule(),
            pw.SizedBox(height: 2),
            _pdfPair('Subtotal', formatReceiptMoney(receiptSubtotal(receipt))),
            if (receipt.discountAmount > 0)
              _pdfPair(
                'Discount',
                '-${formatReceiptMoney(receipt.discountAmount)}',
              ),
            if (receipt.taxAmount > 0)
              _pdfPair(
                receipt.taxRate > 0
                    ? 'VAT (${receipt.taxRate.toStringAsFixed(0)}%)'
                    : 'VAT',
                formatReceiptMoney(receipt.taxAmount),
              ),
            if (receipt.deliveryCost > 0)
              _pdfPair('Delivery', formatReceiptMoney(receipt.deliveryCost)),
            pw.SizedBox(height: 2),
            _doubleRule(),
            _pdfPair(
              'TOTAL',
              formatReceiptMoney(receipt.total),
              bold: true,
              fontSize: 11,
              emphasised: true,
            ),
            _doubleRule(),
            pw.SizedBox(height: 2),
            _pdfPair(
              receiptPaymentLabel(receipt.paymentMethod),
              formatReceiptMoney(receipt.amountPaid),
            ),
            if ((receipt.paymentReference?.trim() ?? '').isNotEmpty)
              _pdfPair('Ref', receipt.paymentReference!.trim()),
            if (receiptShowsChange(receipt))
              _pdfPair(
                'Change',
                formatReceiptMoney(receipt.change),
                bold: true,
              ),
            if (receiptBalanceOwed(receipt) > 0.005)
              _pdfPair(
                'Balance (owed)',
                formatReceiptMoney(receiptBalanceOwed(receipt)),
                bold: true,
              ),
            if (receipt.paymentMethod.trim().toLowerCase() == 'wallet')
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 3),
                child: pw.Text(
                  'Paid from customer wallet.',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
            pw.SizedBox(height: 3),
            _singleRule(),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Text(
                store.footer,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 8.5,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Center(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.7),
                  borderRadius: pw.BorderRadius.circular(2),
                ),
                child: pw.Text(
                  kReceiptReachUsLabel,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            if (receipt.saleNumber.isNotEmpty) ...[
              pw.SizedBox(height: 3),
              pw.Center(
                child: pw.Text(
                  receipt.saleNumber,
                  style: const pw.TextStyle(fontSize: 8, letterSpacing: 0.5),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  return document.save();
}

List<pw.Widget> _itemBlock(CartLine line, ReceiptStoreInfo store) {
  final variant = receiptItemVariant(line);
  final sku = line.sku?.trim() ?? '';
  return [
    pw.Text(
      variant == null
          ? receiptItemName(line)
          : '${receiptItemName(line)} ($variant)',
      style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
    ),
    if (store.showSku && sku.isNotEmpty)
      pw.Text(
        sku,
        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
      ),
    _pdfPair(receiptItemQtyLine(line), formatReceiptMoney(line.lineTotal)),
    pw.SizedBox(height: 2),
  ];
}

pw.Widget _doubleRule() => pw.Container(
  margin: const pw.EdgeInsets.symmetric(vertical: 1),
  decoration: const pw.BoxDecoration(
    border: pw.Border(
      top: pw.BorderSide(color: PdfColors.black, width: 0.8),
      bottom: pw.BorderSide(color: PdfColors.black, width: 0.8),
    ),
  ),
  height: 1.4,
);

pw.Widget _singleRule() => pw.Container(
  margin: const pw.EdgeInsets.symmetric(vertical: 1),
  height: 0,
  decoration: const pw.BoxDecoration(
    border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.5)),
  ),
);

pw.Widget _pdfPair(
  String label,
  String value, {
  bool bold = false,
  double fontSize = 8.5,
  bool emphasised = false,
}) {
  final style = pw.TextStyle(
    fontSize: emphasised ? 11 : fontSize,
    fontWeight: bold || emphasised ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 0.6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.SizedBox(width: 6),
        pw.Text(
          value,
          style: style.copyWith(
            color: _priceGreen,
            fontWeight: pw.FontWeight.bold,
          ),
          textAlign: pw.TextAlign.right,
        ),
      ],
    ),
  );
}
