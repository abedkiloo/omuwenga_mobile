import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../data/pos_api.dart';
import 'receipt_document.dart';
import 'receipt_layout.dart';

Future<void> downloadOrPrintReceipt(
  SaleReceipt receipt, {
  ReceiptStoreInfo store = const ReceiptStoreInfo(),
}) async {
  final bytes = await buildReceiptPdf(receipt, store: store);
  await Printing.layoutPdf(
    name: receiptFileName(receipt),
    format: receiptPdfPageFormat(),
    onLayout: (_) async => bytes,
  );
}

Future<void> shareReceipt(
  SaleReceipt receipt, {
  ReceiptStoreInfo store = const ReceiptStoreInfo(),
}) async {
  final bytes = await buildReceiptPdf(receipt, store: store);
  final directory = await getTemporaryDirectory();
  final file = File(p.join(directory.path, receiptFileName(receipt)));
  await file.writeAsBytes(bytes, flush: true);
  try {
    await SharePlus.instance.share(
      ShareParams(
        subject: 'Receipt ${receipt.saleNumber}',
        text: buildThermalReceiptText(receipt, store: store),
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
