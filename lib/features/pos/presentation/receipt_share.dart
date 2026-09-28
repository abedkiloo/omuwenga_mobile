import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../data/pos_api.dart';
import 'receipt_document.dart';
import 'receipt_layout.dart';

const _pngMagic = [0x89, 0x50, 0x4E, 0x47];

bool looksLikePng(Uint8List bytes) {
  if (bytes.length < 8) return false;
  for (var i = 0; i < _pngMagic.length; i++) {
    if (bytes[i] != _pngMagic[i]) return false;
  }
  return true;
}

ShareParams receiptImageShareParams({
  required String filePath,
  required SaleReceipt receipt,
  ReceiptStoreInfo store = const ReceiptStoreInfo(),
}) {
  return ShareParams(
    subject: 'Receipt ${receipt.saleNumber}',
    text: buildThermalReceiptText(receipt, store: store),
    files: [
      XFile(filePath, mimeType: 'image/png', name: receiptPngFileName(receipt)),
    ],
  );
}

Future<Uint8List> snapshotWidgetPng(
  GlobalKey key, {
  double pixelRatio = 3,
}) async {
  final context = key.currentContext;
  if (context == null) {
    throw StateError('Receipt is not on screen yet.');
  }
  final boundary = context.findRenderObject();
  if (boundary is! RenderRepaintBoundary) {
    throw StateError('Receipt snapshot is not ready.');
  }
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    throw StateError('Could not create receipt photo.');
  }
  return bytes.buffer.asUint8List();
}

Future<void> downloadOrPrintReceipt(
  SaleReceipt receipt, {
  ReceiptStoreInfo store = const ReceiptStoreInfo(),
  Uint8List? pngBytes,
}) async {
  assert(pngBytes == null || pngBytes.isEmpty || looksLikePng(pngBytes));
  final pdf = await buildReceiptPdf(receipt, store: store);
  await Printing.layoutPdf(
    name: receiptFileName(receipt),
    format: receiptPdfPageFormat(),
    onLayout: (_) async => pdf,
  );
}

Future<void> shareReceipt(
  SaleReceipt receipt, {
  ReceiptStoreInfo store = const ReceiptStoreInfo(),
  Uint8List? pngBytes,
  Future<Directory> Function()? temporaryDirectory,
  Future<void> Function(ShareParams params)? share,
}) async {
  if (pngBytes == null || !looksLikePng(pngBytes)) {
    throw StateError('Receipt photo is required to share.');
  }
  final directory = await (temporaryDirectory ?? getTemporaryDirectory)();
  final file = File(p.join(directory.path, receiptPngFileName(receipt)));
  await file.writeAsBytes(pngBytes, flush: true);
  try {
    final shareFn =
        share ??
        (params) async {
          await SharePlus.instance.share(params);
        };
    await shareFn(
      receiptImageShareParams(
        filePath: file.path,
        receipt: receipt,
        store: store,
      ),
    );
  } finally {
    if (await file.exists()) {
      await file.delete();
    }
  }
}
