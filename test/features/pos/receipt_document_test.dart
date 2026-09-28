import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:completebyte_pos_mobile/features/pos/data/pos_api.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/cart.dart';
import 'package:completebyte_pos_mobile/features/pos/domain/payment.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_document.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_layout.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_page.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/receipt_share.dart';
import 'package:completebyte_pos_mobile/features/pos/presentation/thermal_receipt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';

SaleReceipt _receipt({
  String saleNumber = 'SALE-7',
  String paymentMethod = 'mpesa',
  double total = 116,
  double amountPaid = 116,
  double change = 0,
  double taxAmount = 6,
  double taxRate = 16,
  double discountAmount = 10,
  double deliveryCost = 0,
  String? paymentReference = 'MPESA-REF',
  String? servedByName = 'Amina',
  String? customerName = 'Test Customer',
  List<CartLine>? items,
}) {
  return SaleReceipt(
    id: 7,
    saleNumber: saleNumber,
    total: total,
    subtotal: 120,
    taxAmount: taxAmount,
    taxRate: taxRate,
    discountAmount: discountAmount,
    deliveryCost: deliveryCost,
    paymentMethod: paymentMethod,
    paymentReference: paymentReference,
    amountPaid: amountPaid,
    change: change,
    createdAt: DateTime.utc(2026, 9, 16, 12, 30),
    customerName: customerName,
    servedByName: servedByName,
    items:
        items ??
        const [
          CartLine(
            productId: 1,
            name: 'Test Item',
            sku: 'SKU-1',
            unitPrice: 60,
            quantity: 2,
            variantLabel: 'Large',
          ),
        ],
  );
}

void main() {
  test('builds receipt PDF locally on request', () async {
    final receipt = _receipt();
    const store = ReceiptStoreInfo(
      storeName: 'Test Duka',
      header: 'Licensed retailer',
      branchName: 'Westlands',
      address: 'Nairobi',
      phone: '0700000000',
      taxId: 'P051234',
      footer: 'Asante kwa biashara yako.',
      showSku: true,
    );

    final bytes = await buildReceiptPdf(receipt, store: store);

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(receiptFileName(receipt), 'receipt-SALE-7.pdf');
    expect(receiptPngFileName(receipt), 'receipt-SALE-7.png');
    expect(looksLikePng(bytes), isFalse);
    expect(kReceiptReachUsPhone, '0718515142');
    expect(kReceiptReachUsLabel, 'You can reach us via 0718515142');
    final format = receiptPdfPageFormat();
    expect(format.width, closeTo(80 * PdfPageFormat.mm, 0.01));
    expect(format.height, double.infinity);
  });

  test('thermal share text matches the web receipt layout', () {
    final text = buildThermalReceiptText(
      _receipt(deliveryCost: 50, change: 4, amountPaid: 120),
      store: const ReceiptStoreInfo(
        storeName: 'Test Duka',
        header: 'Welcome',
        branchName: 'Westlands',
        address: 'Nairobi',
        phone: '0700',
        taxId: 'P051',
        showSku: true,
      ),
    );

    expect(text, contains('TEST DUKA'));
    expect(text, contains('Welcome'));
    expect(text, contains('Westlands'));
    expect(text, contains('PIN: P051'));
    expect(text, contains('Receipt'));
    expect(text, contains('SALE-7'));
    expect(text, contains('16/09/2026'));
    expect(text, contains('Served by'));
    expect(text, contains('Test Item (Large)'));
    expect(text, contains('SKU-1'));
    expect(text, contains('2 ×'));
    expect(text, contains('Subtotal'));
    expect(text, contains('Discount'));
    expect(text, contains('VAT (16%)'));
    expect(text, contains('Delivery'));
    expect(text, contains('TOTAL'));
    expect(text, contains('M-Pesa'));
    expect(text, contains('Ref'));
    expect(text, contains('Change'));
    expect(text, contains('Thank you for your business!'));
    expect(text, contains(kReceiptReachUsLabel));
    expect(text, isNot(contains('TOTAL NET')));
    expect(text, isNot(contains('SALE RECEIPT')));
  });

  test('thermal share text covers empty items, wallet, and balance', () {
    final empty = buildThermalReceiptText(
      _receipt(
        saleNumber: '',
        paymentMethod: 'wallet',
        paymentReference: '',
        servedByName: '',
        items: const [],
        taxAmount: 0,
        discountAmount: 0,
      ),
    );
    expect(empty, contains('No items.'));
    expect(empty, contains('Paid from customer wallet.'));
    expect(empty, contains('Wallet'));
    expect(empty, contains('OMUWENGA SUPPLIERS'));

    final owed = buildThermalReceiptText(
      _receipt(
        paymentMethod: 'card',
        amountPaid: 40,
        total: 116,
        change: 0,
        taxRate: 0,
      ),
    );
    expect(owed, contains('Card'));
    expect(owed, contains('Balance (owed)'));
    expect(owed, contains('VAT'));
    expect(owed, isNot(contains('VAT (')));
  });

  test('receipt money, date, quantity and payment labels', () {
    expect(formatReceiptMoney(1234.5), 'Ksh 1,234.50');
    expect(formatReceiptMoney(-10), '-Ksh 10.00');
    expect(formatReceiptDate(null), '');
    expect(
      formatReceiptDate(DateTime.utc(2026, 9, 16, 12, 30)),
      contains('16/09/2026'),
    );
    expect(formatReceiptQuantity(2), '2');
    expect(formatReceiptQuantity(2.5), '2.50');
    expect(receiptPaymentLabel('cash'), 'Cash');
    expect(receiptPaymentLabel('mpesa'), 'M-Pesa');
    expect(receiptPaymentLabel('wallet'), 'Wallet');
    expect(receiptPaymentLabel('card'), 'Card');
    expect(receiptPaymentLabel('bank_transfer'), 'Bank Transfer');
    expect(receiptPaymentLabel(''), 'Paid');
    expect(receiptPaymentLabel('voucher'), 'voucher');
    expect(receiptAppliedPaid(_receipt(total: 5850, amountPaid: 6000)), 5850);
    expect(receiptChangeDue(_receipt(total: 5850, amountPaid: 6000, change: 0)), 150);
    expect(
      receiptBalanceOwed(_receipt(total: 5850, amountPaid: 6000, change: 0)),
      0,
    );
  });

  test('receipt does not print tendered cash as the sale total', () {
    final text = buildThermalReceiptText(
      _receipt(
        total: 5850,
        amountPaid: 6000,
        change: 0,
        taxAmount: 0,
        discountAmount: 0,
        deliveryCost: 0,
        paymentMethod: 'cash',
        paymentReference: '',
      ),
    );
    expect(text, contains('TOTAL'));
    expect(text, contains('Ksh 5,850.00'));
    expect(text, contains('Change'));
    expect(text, contains('Ksh 150.00'));
    expect(text, isNot(contains('Ksh 6,000.00')));
  });

  test('store info falls back to web defaults', () {
    const emptyName = PosSettings(storeName: '  ', receiptFooter: '');
    final info = ReceiptStoreInfo.fromPosSettings(emptyName);
    expect(info.storeName, kDefaultReceiptStoreName);
    expect(info.footer, kDefaultReceiptFooter);

    final branded = ReceiptStoreInfo.fromPosSettings(
      const PosSettings(
        storeName: 'Duka',
        receiptFooter: 'Karibu tena',
        showSku: true,
      ),
    );
    expect(branded.storeName, 'Duka');
    expect(branded.footer, 'Karibu tena');
    expect(branded.showSku, isTrue);
  });

  test('reads served by from API payload', () {
    final fromServed = SaleReceipt.fromJson({
      'id': 1,
      'sale_number': 'S-1',
      'total': 10,
      'payment_method': 'cash',
      'amount_paid': 10,
      'change': 0,
      'served_by_name': 'Amina',
      'cashier_name': 'Kai',
      'tax_rate': 16,
      'delivery_cost': 20,
      'items': [
        {
          'product_name': 'Soap',
          'quantity': 1,
          'unit_price': 10,
          'size_name': 'Large',
          'color_name': 'White',
          'product_sku': 'SOAP-1',
        },
      ],
    });
    expect(fromServed.servedByName, 'Amina');
    expect(fromServed.taxRate, 16);
    expect(fromServed.deliveryCost, 20);
    expect(fromServed.items.single.variantLabel, 'Large · White');
    expect(fromServed.items.single.sku, 'SOAP-1');

    final fromCashier = SaleReceipt.fromJson({
      'id': 2,
      'sale_number': 'S-2',
      'total': 10,
      'payment_method': 'cash',
      'amount_paid': 10,
      'change': 0,
      'cashier_name': 'Kai',
      'items': [],
    });
    expect(fromCashier.servedByName, 'Kai');
  });

  testWidgets('on-screen thermal receipt matches web share layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ThermalReceiptView(
              receipt: _receipt(
                paymentMethod: 'cash',
                amountPaid: 200,
                change: 84,
                deliveryCost: 15,
              ),
              store: const ReceiptStoreInfo(
                storeName: 'Test Duka',
                header: 'Welcome',
                branchName: 'Westlands',
                address: 'Nairobi CBD',
                phone: '0700111222',
                taxId: 'P051111',
                footer: 'Asante kwa biashara yako.',
                showSku: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('TEST DUKA'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Westlands'), findsOneWidget);
    expect(find.text('PIN: P051111'), findsOneWidget);
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Served by'), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('TOTAL'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('Change'), findsOneWidget);
    expect(find.text('SKU-1'), findsOneWidget);
    expect(find.text('VAT (16%)'), findsOneWidget);
    expect(find.text('Delivery'), findsOneWidget);
    expect(find.text('Asante kwa biashara yako.'), findsOneWidget);
    expect(find.byKey(const Key('receipt_total')), findsOneWidget);
    final reachUs = tester.widget<OutlinedButton>(
      find.byKey(const Key('receipt_reach_us')),
    );
    reachUs.onPressed?.call();
    await tester.pump();
    expect(find.textContaining('Copied 0718515142'), findsOneWidget);
  });

  testWidgets('thermal receipt and receipt actions fit a 320px till', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptPage(
          receipt: _receipt(
            saleNumber: 'VERY-LONG-SALE-NUMBER-123456789',
            items: const [
              CartLine(
                productId: 1,
                name: 'Extra long cement bag name for overflow',
                sku: 'SKU-OVERFLOW-123456',
                unitPrice: 12345.67,
                quantity: 12,
                variantLabel: 'Jumbo pack',
              ),
            ],
          ),
          store: const ReceiptStoreInfo(
            storeName: 'Very Long Store Name For Overflow',
            showSku: true,
          ),
          onPrint:
              (receipt, {store = const ReceiptStoreInfo(), pngBytes}) async {},
          onShare:
              (receipt, {store = const ReceiptStoreInfo(), pngBytes}) async {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('receipt_download')), findsOneWidget);
    expect(find.byKey(const Key('receipt_share')), findsOneWidget);
    expect(find.textContaining('Extra long cement'), findsOneWidget);
  });

  testWidgets('thermal receipt empty items and wallet note', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ThermalReceiptView(
          receipt: _receipt(
            paymentMethod: 'wallet',
            paymentReference: '',
            items: const [],
            taxAmount: 0,
            discountAmount: 0,
            servedByName: null,
          ),
        ),
      ),
    );
    expect(find.text('No items.'), findsOneWidget);
    expect(find.text('Paid from customer wallet.'), findsOneWidget);
    expect(find.text('OMUWENGA SUPPLIERS'), findsOneWidget);
  });

  testWidgets('thermal receipt shows balance owed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ThermalReceiptView(
          receipt: _receipt(
            paymentMethod: 'card',
            amountPaid: 20,
            total: 116,
            change: 0,
            taxRate: 0,
            taxAmount: 4,
          ),
        ),
      ),
    );
    expect(find.text('Balance (owed)'), findsOneWidget);
    expect(find.text('VAT'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
  });

  testWidgets('receipt page share error and branded header', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptPage(
          receipt: _receipt(customerName: 'Ada'),
          store: const ReceiptStoreInfo(
            storeName: 'Test Duka',
            header: 'Welcome guests',
            branchName: 'Test Duka',
          ),
        ),
      ),
    );
    expect(find.text('TEST DUKA'), findsOneWidget);
    expect(find.text('Welcome guests'), findsOneWidget);
    expect(find.text('Ada'), findsOneWidget);
  });

  testWidgets('receipt page print and share exporters', (tester) async {
    var printed = false;
    final release = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptPage(
          receipt: _receipt(),
          onPrint:
              (receipt, {store = const ReceiptStoreInfo(), pngBytes}) async {
                printed = true;
                await release.future;
              },
          onShare:
              (receipt, {store = const ReceiptStoreInfo(), pngBytes}) async {
                throw Exception('share boom');
              },
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('receipt_download')));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    release.complete();
    await tester.pumpAndSettle();
    expect(printed, isTrue);

    await tester.tap(find.byKey(const Key('receipt_share')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not create receipt'), findsOneWidget);
  });

  test('png magic, filename and image share params', () {
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    expect(looksLikePng(png), isTrue);
    expect(looksLikePng(Uint8List(0)), isFalse);
    expect(looksLikePng(Uint8List.fromList([0x25, 0x50, 0x44, 0x46])), isFalse);
    expect(
      receiptPngFileName(_receipt(saleNumber: 'SALE/8')),
      'receipt-SALE-8.png',
    );

    final params = receiptImageShareParams(
      filePath: '/tmp/receipt-SALE-7.png',
      receipt: _receipt(),
      store: const ReceiptStoreInfo(storeName: 'Test Duka'),
    );
    expect(params.files, isNotNull);
    expect(params.files!.single.mimeType, 'image/png');
    expect(params.files!.single.name, 'receipt-SALE-7.png');
    expect(params.text, contains('TEST DUKA'));
    expect(params.text, contains('SALE-7'));
    expect(params.subject, 'Receipt SALE-7');
  });

  test(
    'shareReceipt requires a png snapshot and deletes the temp file',
    () async {
      await expectLater(shareReceipt(_receipt()), throwsA(isA<StateError>()));

      final dir = await Directory.systemTemp.createTemp('receipt-share');
      addTearDown(() async {
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      });
      ShareParams? captured;
      final png = Uint8List.fromList([
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
      ]);
      await shareReceipt(
        _receipt(),
        pngBytes: png,
        temporaryDirectory: () async => dir,
        share: (params) async {
          captured = params;
          expect(File(params.files!.single.path).existsSync(), isTrue);
          expect(params.files!.single.mimeType, 'image/png');
        },
      );
      expect(captured, isNotNull);
      expect(
        File('${dir.path}/${receiptPngFileName(_receipt())}').existsSync(),
        isFalse,
      );
    },
  );

  test('shareReceipt deletes the temp png even when share fails', () async {
    final dir = await Directory.systemTemp.createTemp('receipt-share-fail');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    await expectLater(
      shareReceipt(
        _receipt(),
        pngBytes: png,
        temporaryDirectory: () async => dir,
        share: (_) async {
          throw Exception('share failed');
        },
      ),
      throwsA(isA<Exception>()),
    );
    expect(
      File('${dir.path}/${receiptPngFileName(_receipt())}').existsSync(),
      isFalse,
    );
  });

  testWidgets('snapshotWidgetPng captures the on-screen receipt as png', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    late Uint8List bytes;
    await tester.runAsync(() async {
      bytes = await snapshotWidgetPng(key, pixelRatio: 1);
    });
    expect(looksLikePng(bytes), isTrue);
  });

  testWidgets('receipt page share passes png bytes and print stays separate', (
    tester,
  ) async {
    var printed = false;
    Uint8List? sharedPng;
    await tester.pumpWidget(
      MaterialApp(
        home: ReceiptPage(
          receipt: _receipt(),
          onPrint:
              (receipt, {store = const ReceiptStoreInfo(), pngBytes}) async {
                printed = true;
              },
          onShare:
              (receipt, {store = const ReceiptStoreInfo(), pngBytes}) async {
                sharedPng = pngBytes;
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('receipt_download')));
    await tester.pumpAndSettle();
    expect(printed, isTrue);
    expect(sharedPng, isNull);

    await tester.tap(find.byKey(const Key('receipt_share')));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(sharedPng, isNotNull);
    expect(looksLikePng(sharedPng!), isTrue);
  });

  testWidgets('snapshotWidgetPng fails when the receipt is not mounted', (
    tester,
  ) async {
    final key = GlobalKey();
    expect(snapshotWidgetPng(key), throwsA(isA<StateError>()));
  });

  testWidgets('snapshotWidgetPng fails without a repaint boundary', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(home: SizedBox(key: key)));
    expect(snapshotWidgetPng(key), throwsA(isA<StateError>()));
  });

  test('plain item lines have no variant parens', () {
    final text = buildThermalReceiptText(
      _receipt(
        items: const [
          CartLine(
            productId: 1,
            name: 'Plain soap',
            sku: '  ',
            unitPrice: 10,
            quantity: 1,
          ),
        ],
      ),
      store: const ReceiptStoreInfo(showSku: true),
    );
    expect(text, contains('Plain soap'));
    expect(text, isNot(contains('Plain soap (')));
  });

  test('long thermal pair wraps instead of overlapping', () {
    final text = buildThermalReceiptText(
      _receipt(saleNumber: 'VERY-LONG-SALE-NUMBER-123456789'),
    );
    expect(text, contains('VERY-LONG-SALE-NUMBER-123456789'));
  });

  test('pdf also builds wallet, empty, and balance variants', () async {
    final wallet = await buildReceiptPdf(
      _receipt(
        paymentMethod: 'wallet',
        items: const [],
        taxAmount: 0,
        discountAmount: 0,
        paymentReference: '',
        servedByName: '',
      ),
      store: const ReceiptStoreInfo(
        storeName: 'Duka',
        header: 'Hi',
        branchName: 'Duka',
        address: 'Town',
        phone: '07',
        taxId: 'P1',
        showSku: true,
      ),
    );
    expect(String.fromCharCodes(wallet.take(4)), '%PDF');

    final owed = await buildReceiptPdf(
      _receipt(
        paymentMethod: 'cash',
        amountPaid: 10,
        total: 116,
        change: 0,
        deliveryCost: 5,
      ),
    );
    expect(String.fromCharCodes(owed.take(4)), '%PDF');

    final change = await buildReceiptPdf(
      _receipt(
        paymentMethod: 'cash',
        amountPaid: 200,
        total: 116,
        change: 84,
        items: const [
          CartLine(productId: 3, name: 'Plain', unitPrice: 116, quantity: 1),
        ],
      ),
    );
    expect(String.fromCharCodes(change.take(4)), '%PDF');
  });
}
