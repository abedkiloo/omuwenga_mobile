import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../data/pos_api.dart';

String _money(num value) => 'KES ${value.toStringAsFixed(2)}';

String _timestamp(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}

String receiptFileName(SaleReceipt receipt) {
  final safeNumber = receipt.saleNumber.replaceAll(
    RegExp(r'[^A-Za-z0-9_-]'),
    '-',
  );
  return 'receipt-$safeNumber.pdf';
}

Future<Uint8List> buildReceiptPdf(SaleReceipt receipt) async {
  final document = pw.Document(
    title: 'Receipt ${receipt.saleNumber}',
    author: 'CompleteBytePOS Mobile',
  );
  final printedAt = receipt.createdAt ?? DateTime.now();
  final subtotal =
      receipt.subtotal ??
      receipt.items.fold<double>(0, (sum, line) => sum + line.lineTotal);
  final reference = receipt.paymentReference?.trim() ?? '';

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat(
        58 * PdfPageFormat.mm,
        210 * PdfPageFormat.mm,
        marginAll: 4 * PdfPageFormat.mm,
      ),
      build: (_) => [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(
                'COMPLETEBYTE POS',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text('SALE RECEIPT', style: const pw.TextStyle(fontSize: 8)),
              pw.Text(
                _timestamp(printedAt),
                style: const pw.TextStyle(fontSize: 7),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        _pdfRule(),
        pw.SizedBox(height: 6),
        _pdfPair('Sale', receipt.saleNumber),
        if (receipt.customerName?.trim().isNotEmpty == true)
          _pdfPair('Customer', receipt.customerName!.trim()),
        pw.SizedBox(height: 6),
        _pdfRule(),
        pw.SizedBox(height: 4),
        for (final line in receipt.items) ...[
          pw.Text(
            '${_quantity(line.quantity)}x ${line.displayName}',
            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          ),
          _pdfPair(
            '@ ${_money(line.unitPrice)}',
            _money(line.lineTotal),
            fontSize: 7,
          ),
          pw.SizedBox(height: 3),
        ],
        _pdfRule(),
        pw.SizedBox(height: 5),
        _pdfPair('Subtotal', _money(subtotal)),
        if (receipt.taxAmount > 0) _pdfPair('Tax', _money(receipt.taxAmount)),
        if (receipt.discountAmount > 0)
          _pdfPair('Discount', '-${_money(receipt.discountAmount)}'),
        pw.SizedBox(height: 3),
        _pdfPair('TOTAL NET', _money(receipt.total), bold: true, fontSize: 9),
        pw.SizedBox(height: 6),
        _pdfRule(),
        pw.SizedBox(height: 5),
        _pdfPair('Payment', receipt.paymentMethod.toUpperCase()),
        _pdfPair('Paid', _money(receipt.amountPaid)),
        if (receipt.change > 0) _pdfPair('Change', _money(receipt.change)),
        if (reference.isNotEmpty) _pdfPair('Reference', reference),
        pw.SizedBox(height: 8),
        pw.BarcodeWidget(
          barcode: pw.Barcode.code128(),
          data: receipt.saleNumber,
          height: 24,
          drawText: false,
        ),
        pw.SizedBox(height: 3),
        pw.Center(
          child: pw.Text(
            receipt.saleNumber,
            style: const pw.TextStyle(fontSize: 7),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Center(
          child: pw.Text(
            'Asante kwa biashara yako. Karibu tena.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic),
          ),
        ),
      ],
    ),
  );

  return document.save();
}

Future<void> downloadOrPrintReceipt(SaleReceipt receipt) async {
  final bytes = await buildReceiptPdf(receipt);
  await Printing.layoutPdf(
    name: receiptFileName(receipt),
    format: PdfPageFormat(58 * PdfPageFormat.mm, 210 * PdfPageFormat.mm),
    onLayout: (_) async => bytes,
  );
}

Future<void> shareReceipt(SaleReceipt receipt) async {
  final bytes = await buildReceiptPdf(receipt);
  final directory = await getTemporaryDirectory();
  final file = File(p.join(directory.path, receiptFileName(receipt)));
  await file.writeAsBytes(bytes, flush: true);
  try {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Receipt ${receipt.saleNumber}',
        text: 'Receipt ${receipt.saleNumber} · ${_money(receipt.total)}',
        files: [
          XFile(
            file.path,
            mimeType: 'application/pdf',
            name: receiptFileName(receipt),
          ),
        ],
      ),
    );
  } finally {
    if (await file.exists()) {
      await file.delete();
    }
  }
}

pw.Widget _pdfRule() => pw.Container(height: 0.5, color: PdfColors.grey500);

pw.Widget _pdfPair(
  String label,
  String value, {
  bool bold = false,
  double fontSize = 8,
}) {
  final style = pw.TextStyle(
    fontSize: fontSize,
    fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
  );
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 1),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.SizedBox(width: 4),
        pw.Text(value, style: style, textAlign: pw.TextAlign.right),
      ],
    ),
  );
}

String _quantity(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}
